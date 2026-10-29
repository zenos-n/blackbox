#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Measure terminal parsing throughput, including a final cursor-report fence."""
import argparse
import json
import os
from pathlib import Path
import re
import select
import statistics
import termios
import time
import tty


def payload(kind):
    rows = {
        "ascii": b"The quick brown fox jumps over the lazy dog. 0123456789\r\n",
        "ansi": b"\x1b[38;2;60;180;120mcolored text\x1b[0m regular text\r\n",
        "unicode": "Zażółć gęślą jaźń 日本語 🐈\r\n".encode(),
    }
    return rows[kind] * 1024


def write_all(fd, data):
    remaining = memoryview(data)
    while remaining:
        count = os.write(fd, remaining)
        if count == 0:
            raise RuntimeError("Terminal closed during output")
        remaining = remaining[count:]


def read_cursor_report(fd, timeout=10):
    deadline = time.monotonic() + timeout
    response = b""
    while time.monotonic() < deadline:
        if not select.select([fd], [], [], max(0, deadline - time.monotonic()))[0]:
            break
        data = os.read(fd, 1024)
        if not data:
            break
        response = (response + data)[-4096:]
        if re.search(rb"\x1b\[\d+;\d+R", response):
            return
    raise TimeoutError("Terminal did not answer the cursor-position query")


def self_test():
    for kind in ("ascii", "ansi", "unicode"):
        block = payload(kind)
        assert block.endswith(b"\r\n")
        block.decode("utf-8")
    read_fd, write_fd = os.pipe()
    try:
        write_all(write_fd, b"noise\x1b[24;80R")
        read_cursor_report(read_fd)
        try:
            read_cursor_report(read_fd, timeout=0.01)
            raise AssertionError("Missing cursor reply was accepted")
        except TimeoutError:
            pass
    finally:
        os.close(read_fd)
        os.close(write_fd)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--kind", choices=("ascii", "ansi", "unicode"), default="ascii")
    parser.add_argument("--mib", type=int, default=16)
    parser.add_argument("--trials", type=int, default=5)
    parser.add_argument("--output", type=Path)
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()
    if args.self_test:
        self_test()
        return
    if args.mib <= 0 or args.trials <= 0 or args.output is None:
        parser.error("positive --mib and --trials, and --output are required")
    if not os.isatty(0) or not os.isatty(1):
        parser.error("run inside the terminal being measured")

    block = payload(args.kind)
    count = (args.mib * 1024 * 1024 + len(block) - 1) // len(block)
    fd = 0
    previous = termios.tcgetattr(fd)
    elapsed = []
    try:
        tty.setraw(fd)
        for _ in range(args.trials):
            write_all(1, b"\x1b[6n")
            read_cursor_report(fd)
            start = time.monotonic()
            for _ in range(count):
                write_all(1, block)
            write_all(1, b"\x1b[6n")
            read_cursor_report(fd)
            elapsed.append(time.monotonic() - start)
    finally:
        termios.tcsetattr(fd, termios.TCSANOW, previous)

    total_bytes = count * len(block)
    report = {
        "metric": "PTY output plus terminal parser acknowledgement; excludes frame presentation",
        "kind": args.kind, "bytes_per_trial": total_bytes,
        "seconds": elapsed,
        "median_mib_per_second": total_bytes / (1024 * 1024) / statistics.median(elapsed),
        "environment": {key: os.environ.get(key) for key in
                        ("TERM", "TERM_PROGRAM", "VTE_VERSION", "GSK_RENDERER", "XDG_SESSION_TYPE")},
    }
    args.output.write_text(json.dumps(report, indent=2) + "\n")
    print(f"\r\nResults: {args.output}")


if __name__ == "__main__":
    main()
