# Performance and reliability baseline

No throughput or latency improvement is claimed yet. The available environment
can compile against the GNOME 50 libraries, but cannot connect to the desktop,
start Xvfb, or access the Nix daemon. Hardware rendering and full package builds
need verification outside that sandbox.

## Confirmed regressions

The same Vala regression tests were compiled against the unmodified upstream
snapshot and the fork, with GLib 2.88.3 and GCC 16.2:

| Case | Upstream | Fork |
|---|---|---|
| Invalid PIDs (`-1`, `0`) | Assertion failure: reported as running | Pass |
| Ownership of a nonexistent process | Assertion failure: reported root | Pass: returns an error |
| Reading a missing file | SIGSEGV | Pass: returns an error |
| UTF-8 file roundtrip, replacement and empty file | Pass | Pass |

The global PID-to-command cache also had a lifetime bug: foreground-command
entries could survive when the owning shell exited while its foreground
process was still alive. The fork stores one cached command in the tracked process
object, so releasing a session releases its cache. This is a structural bound;
an RSS improvement has not been measured. Polling still misses commands shorter
than its interval, and the cache does not detect every `exec` with an unchanged PID.

## Repeatable throughput measurement

Build upstream and fork with `--buildtype=release`, the same VTE/GTK libraries,
font, window dimensions, scrollback size and renderer. Run this command inside
each terminal, changing the output file for each run:

```sh
python3 tools/benchmark.py --kind ascii --mib 16 --trials 5 --output /tmp/fork-ascii.json
```

Repeat with `--kind ansi` and `--kind unicode`; include Kitty as a comparison.
The benchmark waits for a terminal cursor-position reply after the output.
It measures PTY transfer plus parsing, **not** GPU frame presentation or input
latency. A missing reply fails the run instead of reporting write speed as
terminal throughput. The harness restores termios on normal exit and errors.

Record per-trial values, median, spread, exact library versions, GPU/driver,
Wayland session, display scale and refresh rate. The environment field reports
requested renderer overrides, not proof of the selected hardware renderer.
Alternate baseline/fork runs and repeat changes in isolation. Do not retain an
optimization whose gain is within run-to-run variance.

Use Sysprof and GTK Inspector on real GNOME 50 for frame times, input latency,
renderer selection, large-scrollback search and idle CPU with 1/10/50 tabs.
Also test resizing, fractional scaling, transparency, IME, accessibility,
clipboard and drag/drop, command completion, and Sixel images. Capture idle RSS
after repeatedly opening and closing tabs. Do not set `TERM=xterm-kitty` until
the required protocols actually exist.
