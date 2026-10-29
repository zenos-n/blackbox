/* Terminal.vala
 *
 * Copyright 2023 Paulo Queiroz <pvaqueiroz@gmail.com>
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

  public async int get_foreground_process (
    int terminal_fd,
    Cancellable? cancellable = null
  ) {
    return Posix.tcgetpgrp (terminal_fd);
  }

  public string? get_process_cmdline (int pid) {
    try {
      string response;
      bool success = FileUtils.get_contents (@"/proc/$pid/cmdline", out response);
      if (success)
        return response.strip ();
    }
    catch (GLib.Error e) {
      warning ("%s", e.message);
    }
    return null;
  }

  public int get_euid_from_pid (int pid,
                                GLib.Cancellable? cancellable) throws GLib.Error
  {
    string proc_file = @"/proc/$pid";
    Posix.Stat? buf = null;
    Posix.stat (proc_file, out buf);

    return (int) buf.st_uid;
  }

  public bool check_pid_running (int pid) {
    int status = Posix.kill (pid, 0);
    return (status == 0);
  }
}
