#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Run GTK tests without reading or changing the user's settings and themes."""
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

with tempfile.TemporaryDirectory(prefix="blackbox-tests-") as directory:
    env = os.environ.copy()
    env.update(HOME=directory, XDG_DATA_HOME=f"{directory}/data",
               XDG_CONFIG_HOME=f"{directory}/config",
               XDG_CACHE_HOME=f"{directory}/cache")
    shutil.copytree(Path(env["BLACKBOX_TEST_SOURCE"]) / "data/schemes",
                    Path(env["XDG_DATA_HOME"]) / "blackbox-next/schemes")
    command = sys.argv[1:]
    listing = subprocess.run(command + ["-l"], env=env, capture_output=True, text=True)
    if listing.returncode:
        print(listing.stdout, end="")
        print(listing.stderr, end="", file=sys.stderr)
        sys.exit(listing.returncode)
    cases = [line.removeprefix("# ") for line in listing.stdout.splitlines()
             if line.removeprefix("# ").startswith("/")]
    if not cases:
        raise RuntimeError(f"No GTK regression tests were discovered: {listing.stdout!r}")
    # Each test owns its application, settings singleton and frame callbacks.
    for case in cases:
        result = subprocess.run(command + ["-p", case], env=env)
        if result.returncode:
            sys.exit(result.returncode)
