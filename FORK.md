# Black Box Next

This is a development fork of [Black Box](https://gitlab.gnome.org/raggesilver/blackbox),
starting with performance, reliability, and GNOME 50. Kitty compatibility is
the longer-term target, not a feature claim for this first version.

Version: **0.15.2.4**. Executable: `blackbox-next`. Desktop application and
GSettings ID: `com.neg-zero.BlackBoxNext`. Themes and keybindings live in
`$XDG_DATA_HOME/blackbox-next/` (normally `~/.local/share/blackbox-next/`).
The fork can coexist with upstream and does not migrate its settings.

## Provenance

The initial commit imports the unmodified upstream 0.15.2 source snapshot at
[`69189eba669c2051a1f1d076b9a365a111ba79d8`](https://gitlab.gnome.org/raggesilver/blackbox/-/commit/69189eba669c2051a1f1d076b9a365a111ba79d8).
It was downloaded from the commit-specific GitLab archive and compared with
the main-branch archive. The local repository has an `upstream` remote and a
`gnome-50` branch, but does **not** contain upstream's earlier Git history.
The original GPL-3.0-or-later license and attribution are preserved.

## First milestone

- Require GTK 4.22, libadwaita 1.9, and VTE 0.84, matching the GNOME 50 stack.
- Use VTE's GTK 4 GSK text rendering path. GTK chooses the available renderer;
  drivers or headless sessions may still use software rendering. No renderer
  environment variable is forced and no new custom renderer is claimed.
- Reject invalid PIDs and distinguish permission-denied processes from dead ones.
- Handle processes disappearing during ownership checks without treating them
  as root or issuing a warning on an expected race.
- Bound command caching to one entry per tracked session, with session cleanup.
- Keep command-completion notification text when the context header is disabled.
- Preserve URL matching when clearing or closing search, and clear stale search
  expressions after invalid regex input.
- Handle missing theme/keymap files through normal GIO errors and finish atomic
  keymap writes before returning.
- Fall back to the user's login shell when `SHELL` is unset, report malformed
  custom commands in the error banner, and ignore empty primary clipboard reads.
- Add regression tests, a parser-throughput benchmark, and Fedora 44 CI.
- Restore automatic stylesheet, icon and help-overlay discovery after the fork's
  application ID change. Use CSS media queries for dark mode on libadwaita 1.9.
- Follow the desktop accent instead of replacing it with terminal-palette blue.
- Animate large cursor movements with a tapered GSK trail. The cursor and trail
  default to white; enable Preferences → Terminal → Cursor → Use Desktop Accent
  to use the system accent instead. Changes apply immediately to open terminals.
  Disable the trail under Preferences → Terminal → Cursor → Cursor Trail. It respects disabled
  desktop animations, stops in scrollback and hidden tabs, and runs no animation
  callback at idle. It uses VTE's accessibility caret geometry; disabling VTE
  accessibility also disables the trail. This is not Kitty's shader/plugin API.
- Add a native tab overview button beside New Tab in both header layouts, with
  6px gaps between the controls. The overview supports thumbnails, tab search,
  switching, closing, and creating tabs through the existing tab lifecycle.
- Scope terminal header recoloring to the custom header. Native overview and
  dialog header bars retain their own styling; the overview header and body
  backgrounds are checked against the rendered pixels.

## Compatibility work still required

| Area | Status |
|---|---|
| GPU text rendering | VTE 0.84 GSK path; Vulkan observed in desktop tests |
| Cursor trail | Implemented; Vulkan rendering and animation cleanup tested on the desktop |
| Inline images | Inherited Sixel; graphical smoke test still required |
| Kitty graphics protocol | Not implemented: transmission, placement, deletion, animation, limits and cleanup need a backend implementation |
| Kitty keyboard protocol | Not implemented in this fork; requires backend capability work |
| Split panes and layouts | Not implemented |
| Ligatures and font feature parity | Not implemented |
| Shell integration, remote control, kittens | Not implemented |
| Complete escape-sequence compatibility | No parity claim; needs a conformance suite |

Retain VTE for the stability milestone. Before implementing Kitty graphics,
evaluate whether to extend a separately maintained VTE backend or integrate
another embeddable core. A GTK window wrapped around a Kitty subprocess would
not provide a reliable native terminal widget.

## Build and checks

The flake supports x86_64 and AArch64 Linux and locks the GNOME build dependencies:

```sh
nix build
nix run
nix flake check
nix develop
```

`nix build .#blackbox-next` selects the named package. The default package runs
the Meson tests during its build. `nix develop` supplies the same build inputs
for working on the source with Meson:

```sh
meson setup _build --buildtype=release
meson compile -C _build
dbus-run-session -- xvfb-run -a meson test -C _build --print-errorlogs
# Optional system installation:
sudo meson install -C _build
```

The Nix recipe is `package.nix`. It builds against the package set supplied by
the caller; Meson rejects an older GNOME stack. Tests use temporary user data
and memory-backed GSettings. Without a display, graphical tests report a skip.
The local sandbox build used GTK 4.22.4, libadwaita 1.9.3, VTE 0.84.1, Vala
0.56.19, and GCC 16.2. Core, process-lifetime and benchmark checks pass. The nine
graphical/process checks also passed through a temporary user service in the
real Wayland session, using `GskVulkanRenderer` and the desktop's purple accent.
Those checks cover styles, accent, search, Unicode/scrollback cursor geometry,
trail rendering and cleanup, the cursor color preference, tab overview actions
in both header layouts (including floating-control reveal/hide), and process lifetime.
GUI cases run in separate processes so application singletons and pending frame
callbacks cannot leak between cases. Command execution also preserves argument
boundaries after `--`/`-e`, including spaces, empty strings and shell metacharacters. GPU throughput and input
latency have not been measured; other desktop features still need validation.

See [PERFORMANCE.md](PERFORMANCE.md) for measurements and remaining validation.
