// SPDX-License-Identifier: GPL-3.0-or-later

Terminal.Application test_application;

void test_search_keeps_url_matches() throws Error {
  var app = test_application;
  var window = new Terminal.Window(app, null, "/", true);
  assert(window.get_help_overlay() != null);
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

void test_application_styles() throws Error {
  var app = test_application;
  var css = resources_lookup_data(app.resource_base_path + "/style.css", ResourceLookupFlags.NONE);
  assert(css.get_size() > 0);

  var switcher = new Terminal.StyleSwitcher();
  int minimum, natural;
  switcher.measure(Gtk.Orientation.VERTICAL, -1, out minimum, out natural, null, null);
  assert(minimum >= 44);

  var settings = Terminal.Settings.get_default();
  settings.pretty = true;
  Terminal.ThemeProvider.get_default().apply_theming();
  Gdk.RGBA color;
  assert(switcher.get_style_context().lookup_color("accent_bg_color", out color));
  var expected = Adw.StyleManager.get_default().get_accent_color_rgba();
  assert(expected != null);
  assert(color.equal(expected));

  var filename = Environment.get_variable("BLACKBOX_TEST_SCREENSHOT");
  if (filename != null) {
    switcher.valign = Gtk.Align.START;
    var window = new Gtk.Window() {
      child = switcher, default_width = 280, default_height = 72, resizable = false,
    };
    window.present();
    int64 deadline = get_monotonic_time() + TimeSpan.SECOND / 4;
    while (get_monotonic_time() < deadline) {
      MainContext.default().iteration(false);
      Thread.usleep(1000);
    }
    var paintable = new Gtk.WidgetPaintable(switcher);
    var snapshot = new Gtk.Snapshot();
    paintable.snapshot(snapshot, switcher.get_width(), switcher.get_height());
    var node = snapshot.to_node();
    assert(node != null);
    var renderer = window.get_renderer();
    Test.message("Renderer: %s; desktop accent: %s", renderer.get_type().name(), expected.to_string());
    assert(renderer.render_texture(node, null).save_to_png(filename));
    window.destroy();
  }
}

void test_command_cache_lifetime() {
  var process = new Terminal.Process();
  var command = process.get_command(Posix.getpid());
  assert(command != null && command != "");
  assert(process.get_command(Posix.getpid()) == command);
}

void test_cursor_trail_lifecycle() {
  var trail = new Terminal.CursorTrail();
  int64 start = TimeSpan.SECOND;
  assert(!trail.move(Graphene.Rect().init(0, 0, 10, 20), start));
  assert(!trail.move(Graphene.Rect().init(10, 0, 10, 20), start));
  assert(!trail.active(start));
  assert(trail.move(Graphene.Rect().init(110, 0, 10, 20), start));
  assert(trail.active(start));
  int64 halfway = start + Terminal.CursorTrail.DURATION / 2;
  var before = trail.tail(halfway);
  assert(before.x > 15 && before.x < 115);
  assert(trail.move(Graphene.Rect().init(210, 0, 10, 20), halfway));
  var after = trail.tail(halfway);
  assert((before.x - after.x).abs() < 0.001f);
  assert(!trail.active(halfway + Terminal.CursorTrail.DURATION));
  trail.reset();
  assert(!trail.active(halfway));
  assert(!trail.move(Graphene.Rect().init(0, 100, 10, 20), halfway));
}

void wait_frames(uint milliseconds) {
  int64 deadline = get_monotonic_time() + milliseconds * TimeSpan.MILLISECOND;
  while (get_monotonic_time() < deadline) {
    MainContext.default().iteration(false);
    Thread.usleep(1000);
  }
}

void test_cursor_geometry_and_animation() {
  var settings = Terminal.Settings.get_default();
  settings.cursor_trail = true;
  var window = new Terminal.Window(test_application, null, "/", true);
  var terminal = new Terminal.Terminal(window, "true", "/");
  window.content = terminal;
  window.set_default_size(600, 300);
  window.resizable = false;
  window.present();
  terminal.grab_focus();
  terminal.feed("first\r\nsecond\r\n日本語".data);
  wait_frames(250);
  Graphene.Rect bounds;
  assert(terminal.get_cursor_bounds(out bounds));
  assert(bounds.origin.y >= terminal.get_char_height() * 2);
  assert(bounds.origin.x >= terminal.get_char_width() * 6);

  terminal.set_scrollback_lines(2);
  for (int i = 0; i < 100; i++) terminal.feed("scrollback\r\n".data);
  wait_frames(250);
  assert(terminal.get_cursor_bounds(out bounds));
  assert(bounds.origin.y < terminal.get_height());

  terminal.feed("\x1b[H".data);
  wait_frames(250);
  terminal.feed("\x1b[8;35H".data);
  wait_frames(40);
  if (terminal.has_focus && Gtk.Settings.get_default().gtk_enable_animations) {
    assert(terminal.cursor_trail_animating);
    if (Environment.get_variable("BLACKBOX_TEST_SCREENSHOT") != null) {
      var paintable = new Gtk.WidgetPaintable(terminal);
      var snapshot = new Gtk.Snapshot();
      paintable.snapshot(snapshot, terminal.get_width(), terminal.get_height());
      var node = snapshot.to_node();
      assert(node != null);
      assert(window.get_renderer().render_texture(node, null)
        .save_to_png("/tmp/blackbox-cursor-trail.png"));
    }
  } else {
    Test.message("Cursor animation requires focus and enabled desktop animations");
  }
  wait_frames(250);
  assert(!terminal.cursor_trail_animating);
  settings.cursor_trail = false;
  terminal.feed("\x1b[H".data);
  wait_frames(40);
  assert(!terminal.cursor_trail_animating);
  terminal.on_before_close();
  window.destroy();
}

void test_cursor_color_preference() {
  var settings = Terminal.Settings.get_default();
  assert(!settings.schema.get_default_value("cursor-use-accent").get_boolean());
  settings.schema.reset("cursor-use-accent");
  var window = new Terminal.Window(test_application, null, "/", true);
  var terminal = new Terminal.Terminal(window, "true", "/");
  var preferences = new Terminal.PreferencesWindow(window, test_application);
  var row = preferences.get_template_child(typeof(Terminal.PreferencesWindow),
    "cursor_accent_switch_row") as Adw.SwitchRow;
  assert(row != null && !row.active);
  var white = Gdk.RGBA() { red = 1, green = 1, blue = 1, alpha = 1 };
  assert(terminal.get_cursor_color().equal(white));
  row.active = true;
  assert(settings.cursor_use_accent);
  assert(terminal.get_cursor_color().equal(Adw.StyleManager.get_default().get_accent_color_rgba()));
  settings.schema.set_boolean("cursor-use-accent", false);
  assert(!row.active);
  assert(terminal.get_cursor_color().equal(white));
  terminal.on_before_close();
  window.destroy();
}

void collect_tab_buttons(Gtk.Widget root, Gee.ArrayList<Adw.TabButton> buttons) {
  if (root is Adw.TabButton) buttons.add((Adw.TabButton) root);
  for (var child = root.get_first_child(); child != null; child = child.get_next_sibling()) {
    collect_tab_buttons(child, buttons);
  }
}

void test_tab_overview() {
  var settings = Terminal.Settings.get_default();
  settings.fill_tabs = true;
  settings.show_headerbar = true;
  var window = new Terminal.Window(test_application, "sleep 5", "/");
  window.set_default_size(720, 440);
  window.resizable = false;
  window.present();
  wait_frames(200);
  var buttons = new Gee.ArrayList<Adw.TabButton>();
  collect_tab_buttons(window.tab_overview.child, buttons);
  assert(buttons.size == 2);
  foreach (var button in buttons) {
    assert(button.view == window.tab_view);
    assert(((Gtk.Box) button.parent).spacing >= 6);
  }
  assert(buttons[0].activate_action("overview.open", null));
  assert(window.tab_overview.open);
  window.tab_overview.open = false;
  wait_frames(200);
  window.new_tab("sleep 5", "/");
  window.new_tab("sleep 5", "/");
  wait_frames(200);
  assert(buttons[1].activate_action("overview.open", null));
  assert(window.tab_overview.open);
  int count = window.tab_view.n_pages;
  var created = window.tab_overview.create_tab();
  assert(window.tab_view.n_pages == count + 1);
  assert(created == window.tab_view.selected_page);
  wait_frames(650);
  var paintable = new Gtk.WidgetPaintable(window.tab_overview);
  var snapshot = new Gtk.Snapshot();
  paintable.snapshot(snapshot, window.tab_overview.get_width(), window.tab_overview.get_height());
  var node = snapshot.to_node();
  assert(node != null);
  var texture = window.get_renderer().render_texture(node, null);
  int width = texture.get_width();
  var pixels = new uint8[width * texture.get_height() * 4];
  texture.download(pixels, width * 4);
  int header = (24 * width + width / 2 - 80) * 4;
  int body = (texture.get_height() / 2 * width + 8) * 4;
  for (int channel = 0; channel < 3; channel++) {
    assert(((int) pixels[header + channel] - pixels[body + channel]).abs() <= 1);
  }
  if (Environment.get_variable("BLACKBOX_TEST_SCREENSHOT") != null) {
    assert(texture.save_to_png("/tmp/blackbox-tab-overview.png"));
  }
  for (int i = 0; i < window.tab_view.n_pages; i++) {
    ((Terminal.TerminalTab) window.tab_view.get_nth_page(i).child).on_before_close();
  }
  window.destroy();
}

void test_floating_tab_overview() {
  var settings = Terminal.Settings.get_default();
  settings.fill_tabs = true;
  settings.floating_controls = true;
  settings.floating_controls_hover_area = 10;
  settings.delay_before_showing_floating_controls = 400;
  settings.show_headerbar = true;
  var window = new Terminal.Window(test_application, "sleep 10", "/");
  window.set_default_size(720, 440);
  window.resizable = false;
  window.present();
  wait_frames(350);
  settings.schema.set_boolean("show-headerbar", false);
  wait_frames(350);
  Gtk.EventControllerMotion? motion = null;
  var controllers = window.observe_controllers();
  for (uint i = 0; i < controllers.get_n_items(); i++) {
    var controller = controllers.get_item(i) as Gtk.EventControllerMotion;
    if (controller != null && controller.name == "floating-controls") {
      motion = controller;
    }
  }
  assert(motion != null);
  motion.propagation_phase = Gtk.PropagationPhase.NONE;
  motion.motion(10, 300);
  motion.motion(10, 1);
  wait_frames(700);
  var buttons = new Gee.ArrayList<Adw.TabButton>();
  collect_tab_buttons(window.tab_overview.child, buttons);
  assert(buttons.size == 2);
  assert(buttons[0].get_mapped());
  Graphene.Rect bounds;
  assert(buttons[0].compute_bounds(window, out bounds));
  var center = bounds.get_center();
  motion.motion(center.x, center.y);
  wait_frames(50);
  var picked = window.pick(center.x, center.y, Gtk.PickFlags.DEFAULT);
  assert(picked != null && (picked == buttons[0] || picked.is_ancestor(buttons[0])));
  assert(((Gtk.Widget) buttons[0]).activate());
  wait_frames(300);
  assert(window.tab_overview.open);
  window.tab_overview.open = false;
  wait_frames(300);
  motion.motion(10, 300);
  wait_frames(300);
  assert(!buttons[0].get_mapped());
  motion.motion(10, 1);
  wait_frames(700);
  assert(buttons[0].get_mapped());
  assert(((Gtk.Widget) buttons[0]).activate());
  wait_frames(300);
  assert(window.tab_overview.open);
  ((Terminal.TerminalTab) window.tab_view.selected_page.child).on_before_close();
  window.destroy();
  settings.show_headerbar = true;
}

void test_recent_tab_order() {
  var settings = Terminal.Settings.get_default();
  assert(settings.schema.get_default_value("tab-switching-order").get_uint32() == 0);
  settings.tab_switching_order = 0;
  var window = new Terminal.Window(test_application, null, "/", true);
  window.focus_next_tab();
  window.focus_previous_tab();
  var a = window.tab_view.append(new Gtk.Label("A"));
  var b = window.tab_view.append(new Gtk.Label("B"));
  var c = window.tab_view.append(new Gtk.Label("C"));
  var d = window.tab_view.append(new Gtk.Label("D"));
  window.tab_view.selected_page = d;
  window.focus_next_tab();
  assert(window.tab_view.selected_page == a);
  window.focus_previous_tab();
  assert(window.tab_view.selected_page == d);

  var preferences = new Terminal.PreferencesWindow(window, test_application);
  var row = preferences.get_template_child(typeof(Terminal.PreferencesWindow),
    "tab_switching_order_combo_row") as Adw.ComboRow;
  assert(row != null && row.selected == 0);
  row.selected = 1;
  assert(settings.tab_switching_order == 1);

  Gtk.EventControllerKey? keys = null;
  var controllers = window.observe_controllers();
  for (uint i = 0; i < controllers.get_n_items(); i++) {
    var controller = controllers.get_item(i) as Gtk.EventControllerKey;
    if (controller != null && controller.name == "tab-switching") keys = controller;
  }
  assert(keys != null && keys.propagation_phase == Gtk.PropagationPhase.CAPTURE);

  // Visit C, A, B, D: this history differs from horizontal order.
  window.tab_view.selected_page = c;
  window.tab_view.selected_page = a;
  window.tab_view.selected_page = b;
  window.tab_view.selected_page = d;
  keys.key_pressed(Gdk.Key.Tab, 0, Gdk.ModifierType.CONTROL_MASK);
  window.focus_next_tab();
  assert(window.tab_view.selected_page == b);
  window.focus_next_tab();
  assert(window.tab_view.selected_page == a);
  window.focus_next_tab();
  assert(window.tab_view.selected_page == c);
  window.focus_next_tab();
  assert(window.tab_view.selected_page == d);
  window.focus_previous_tab();
  assert(window.tab_view.selected_page == c);
  keys.key_released(Gdk.Key.Control_L, 0, Gdk.ModifierType.CONTROL_MASK);
  // Intermediate visits did not overwrite history. Releasing Control commits C.
  keys.key_pressed(Gdk.Key.Tab, 0, Gdk.ModifierType.CONTROL_MASK);
  window.focus_next_tab();
  assert(window.tab_view.selected_page == d);
  keys.key_released(Gdk.Key.Control_L, 0, Gdk.ModifierType.CONTROL_MASK);
  keys.key_pressed(Gdk.Key.Tab, 0, Gdk.ModifierType.CONTROL_MASK);
  window.focus_next_tab();
  assert(window.tab_view.selected_page == c);
  keys.key_released(Gdk.Key.Control_L, 0, Gdk.ModifierType.CONTROL_MASK);

  // Reordering tabs leaves recency intact; closing during a cycle cancels it.
  assert(window.tab_view.reorder_page(d, 0));
  keys.key_pressed(Gdk.Key.ISO_Left_Tab, 0,
    Gdk.ModifierType.CONTROL_MASK | Gdk.ModifierType.SHIFT_MASK);
  window.focus_previous_tab();
  assert(window.tab_view.selected_page == a);
  window.tab_view.close_page(b);
  assert(window.tab_view.n_pages == 3);
  window.focus_next_tab();
  assert(window.tab_view.selected_page == c);
  keys.key_released(Gdk.Key.Control_R, 0, Gdk.ModifierType.CONTROL_MASK);

  // Moving a tab between windows removes it from the old window's history.
  var other = new Terminal.Window(test_application, null, "/", true);
  var e = other.tab_view.append(new Gtk.Label("E"));
  window.tab_view.transfer_page(d, other.tab_view, 1);
  window.focus_next_tab();
  assert(window.tab_view.selected_page == a);
  window.focus_next_tab();
  assert(window.tab_view.selected_page == c);
  other.tab_view.selected_page = d;
  other.focus_next_tab();
  assert(other.tab_view.selected_page == e);

  keys.key_pressed(Gdk.Key.Tab, 0, Gdk.ModifierType.CONTROL_MASK);
  window.focus_next_tab();
  window.tab_view.selected_page = c;
  window.focus_next_tab();
  assert(window.tab_view.selected_page == a);
  settings.schema.set_uint("tab-switching-order", 0);
  assert(row.selected == 0);
  window.focus_next_tab();
  assert(window.tab_view.selected_page == c);
  keys.key_released(Gdk.Key.Control_L, 0, Gdk.ModifierType.CONTROL_MASK);
  window.tab_view.close_page(a);
  window.focus_next_tab();
  window.focus_previous_tab();
  assert(window.tab_view.selected_page == c);
  other.destroy();
  window.destroy();
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
    test_application = new Terminal.Application();
    test_application.set_flags(test_application.flags | ApplicationFlags.NON_UNIQUE);
    try { test_application.register(null); }
    catch (Error e) { error("%s", e.message); }
    Test.add_func("/appearance/resources-and-accent", () => {
      try { test_application_styles(); }
      catch (Error e) { error("%s", e.message); }
    });
    Test.add_func("/cursor/geometry-and-animation", test_cursor_geometry_and_animation);
    Test.add_func("/cursor/color-preference", test_cursor_color_preference);
    Test.add_func("/tabs/overview", test_tab_overview);
    Test.add_func("/tabs/floating-overview", test_floating_tab_overview);
    Test.add_func("/tabs/recent-order", test_recent_tab_order);
    Test.add_func("/search/keeps-url-matches", () => {
    try { test_search_keeps_url_matches(); }
    catch (Error e) { error("%s", e.message); }
    });
  }
  Test.add_func("/process/command-cache", test_command_cache_lifetime);
  Test.add_func("/process/closed-session-release", test_closed_session_is_released);
  Test.add_func("/cursor/trail-lifecycle", test_cursor_trail_lifecycle);
  return Test.run();
}
