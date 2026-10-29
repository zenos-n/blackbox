/* AboutDialog.vala
 *
 * Copyright 2021-2022 Paulo Queiroz <pvaqueiroz@gmail.com>
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

namespace Terminal {
  public Adw.AboutDialog create_about_dialog () {
    var window = new Adw.AboutDialog () {
      developer_name = "Paulo Queiroz",
      copyright = "© 2022-2026 Paulo Queiroz",
      license_type = Gtk.License.GPL_3_0,
      application_icon = APP_ID,
      application_name = APP_NAME,
      version = VERSION,
      website = "https://gitlab.gnome.org/raggesilver/blackbox",
      issue_url = "https://gitlab.gnome.org/raggesilver/blackbox/-/issues",
      debug_info = get_debug_information (),
      release_notes = """
        <ul>
          <li>Open folders in Black Box directly from the Files app right-click menu.</li>
          <li>Fixed missing "command completed" notifications when the context-aware sidebar was disabled.</li>
          <li>Updated translations, including 9 new languages.</li>
        </ul>
      """
    };

    if (DEVEL) {
      window.add_css_class ("devel");
    }

    window.add_link (_("Donate"), "https://www.patreon.com/raggesilver");
    window.add_link (_("Full Changelog"), "https://gitlab.gnome.org/raggesilver/blackbox/-/blob/main/CHANGELOG.md");

    return window;
  }

  private string get_debug_information () {
    var app = "Black Box: %s\n".printf (VERSION);
    var backend = "Backend: %s\n".printf (get_gtk_backend ());
    var renderer = "Renderer: %s\n".printf (get_renderer ());
    var os_info = get_os_info ();
    var libs = get_libraries_info ();

    return app + backend + renderer + os_info + libs;
  }

  private string get_gtk_backend () {
    var display = Gdk.Display.get_default ();
    switch (display.get_class ().get_name ()) {
      case "GdkX11Display": return "X11";
      case "GdkWaylandDisplay": return "Wayland";
      case "GdkBroadwayDisplay": return "Broadway";
      case "GdkWin32Display": return "Windows";
      case "GdkMacosDisplay": return "macOS";
      default: return display.get_class ().get_name ();
    }
  }

  private string get_renderer () {
    var display = Gdk.Display.get_default ();
    var surface = new Gdk.Surface.toplevel (display);
    var renderer = Gsk.Renderer.for_surface (surface);

    var name = renderer.get_class ().get_name ();
    renderer.unrealize ();

    switch (name) {
      case "GskVulkanRenderer": return "Vulkan";
      case "GskGLRenderer": return "GL";
      case "GskCairoRenderer": return "Cairo";
      default: return name;
    }
  }

  private string get_libraries_info () {
    string res = "Libraries:\n";

    res += " - Gtk: %d.%d.%d\n".printf (Gtk.MAJOR_VERSION, Gtk.MINOR_VERSION, Gtk.MICRO_VERSION);
    res += " - VTE: %d.%d.%d\n".printf (Vte.MAJOR_VERSION, Vte.MINOR_VERSION, Vte.MICRO_VERSION);
    res += " - Libadwaita: %s\n".printf (Adw.VERSION_S);
    res += " - JSON-glib: %s\n".printf (Json.VERSION_S);

    return res;
  }

  private string get_os_info () {
    string res = "OS:\n";

    res += " - Name: %s\n".printf (Environment.get_os_info (OsInfoKey.NAME));
    res += " - Version: %s\n".printf (Environment.get_os_info (OsInfoKey.VERSION));

    return res;
  }
}
