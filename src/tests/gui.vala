// SPDX-License-Identifier: GPL-3.0-or-later

void test_search_keeps_url_matches() throws Error {
  var app = new Terminal.Application();
  app.register(null);
  var window = new Terminal.Window(app, null, "/", true);
  var terminal = new Terminal.Terminal(window, "true", "/");
  var toolbar = new Terminal.SearchToolbar();
  toolbar.terminal = terminal;

  var regex = new Vte.Regex.for_match("https://example\\.com", -1, PCRE2.Flags.MULTILINE);
  int before = terminal.match_add_regex(regex, 0);
  toolbar.close();
  int after = terminal.match_add_regex(regex, 0);
  assert(after > before);
  terminal.on_before_close();
  window.destroy();
}

void test_command_cache_lifetime() {
  var process = new Terminal.Process();
  var command = process.get_command(Posix.getpid());
  assert(command != null && command != "");
  assert(process.get_command(Posix.getpid()) == command);
}

void test_closed_session_is_released() {
  var settings = Terminal.Settings.get_default();
  settings.context_aware_header_bar = false;
  settings.show_headerbar = false;
  Terminal.Process? process = new Terminal.Process() {
    pid = Posix.getpid(), terminal_fd = -1, ended = true,
  };
  bool released = false;
  process.weak_ref(() => { released = true; });
  Terminal.ProcessWatcher.get_instance().watch(process);
  process = null;
  int64 deadline = get_monotonic_time() + 3 * TimeSpan.SECOND;
  while (!released && get_monotonic_time() < deadline) {
    MainContext.default().iteration(false);
    Thread.usleep(1000);
  }
  assert(released);
}

int main(string[] args) {
  Test.init(ref args);
  bool process_only = Environment.get_variable("BLACKBOX_TEST_PROCESS_ONLY") != null;
  if (!process_only && !Gtk.init_check()) {
    Test.message("GTK regressions require a display; use xvfb-run -a meson test -C _build");
    return 77;
  }
  if (!process_only) {
    Adw.init();
    Test.add_func("/search/keeps-url-matches", () => {
    try { test_search_keeps_url_matches(); }
    catch (Error e) { error("%s", e.message); }
    });
  }
  Test.add_func("/process/command-cache", test_command_cache_lifetime);
  Test.add_func("/process/closed-session-release", test_closed_session_is_released);
  return Test.run();
}
