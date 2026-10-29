/* ProcessWatcher.vala
 *
 * Copyright 2023-2026 Paulo Queiroz <pvaqueiroz@gmail.com>
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

public enum Terminal.ProcessContext {
  DEFAULT,
  ROOT,
  SSH
}

public class Terminal.Process : Object {
  /**
   * This signal is emitted when the foreground task of a shell finishes.
   */
  public signal void foreground_task_finished();

  /**
   * This is the file descriptor used by the terminal we're tracking. This must
   * be set during instanciation of this class and may not be modified later.
   */
  public int terminal_fd { get; construct set; }

  /**
   * This is the controlling PID for a terminal session. It will point to the
   * user's shell, in most cases. If the terminal was created with a different
   * command (i.e., `blackbox --command "sleep 300"`), this will point to the
   * spawned process instead.
   */
  public Pid pid { get; set; default = -1; }

  /**
   * This is the PID of the process currently running at the top of the user's
   * shell (e.g., if the user opened a terminal with bash, then opened Neovim
   * with `nvim`, the foreground task for this session, and, consequently, this
   * PID, will point to Neovim).
   */
  public Pid foreground_pid { get; set; default = -1; }

  public string? last_foreground_task_command { get; set; default = null; }

  // TODO: we might want to keep track of background PIDs as well (if that's
  // even possible). That will allow us to alert the user of potential
  // background tasks that would be lost upon closing the tab.

  /***/
  public bool ended { get; set; default = false; }

  public ProcessContext context { get; set; default = ProcessContext.DEFAULT; }
}

namespace Terminal {
  const uint PROCESS_WATCHER_INTERVAL_FAST_MS = 500;
  const uint PROCESS_WATCHER_INTERVAL_SLOW_MS = 2000;
}

public class Terminal.ProcessWatcher : Object {
  private static ProcessWatcher?   instance = null;
  private Gee.ArrayList<Process>   process_list;
  private Gee.ArrayList<Process>   pending_process_list;
  private Gee.HashMap<int, string> cmdline_cache;
  private bool watching = false;
  private bool fast_mode = false;

  private ProcessWatcher () {
    this.process_list = new Gee.ArrayList<Process> ();
    this.pending_process_list = new Gee.ArrayList<Process> ();
    this.cmdline_cache = new Gee.HashMap<int, string> ();
  }

  public static ProcessWatcher get_instance() {
    if (instance == null) {
      instance = new ProcessWatcher();
    }
    return instance;
  }

  public bool watch(Process process) {
    this.pending_process_list.add(process);

    if (!this.watching) {
      this.start_watching();
    }

    return true;
  }

  private void start_watching() {
    this.watching = true;
    this.fast_mode = this.requires_process_watching();
    Timeout.add(
      this.fast_mode ? PROCESS_WATCHER_INTERVAL_FAST_MS :
      PROCESS_WATCHER_INTERVAL_SLOW_MS,
      this.watch_loop
    );
  }

  private bool watch_loop() {
    foreach (var process in this.pending_process_list) {
      if (!this.process_list.contains(process)) {
        this.process_list.add(process);
      }
    }
    this.pending_process_list.clear();

    if (this.requires_process_watching()) {
      foreach (var process in this.process_list) {
        this.check_process(process);
      }
    } else {
      foreach (var process in this.process_list) {
        this.check_process_minimal(process);
        process.context = ProcessContext.DEFAULT;
      }
    }

    for (int i = 0; i < this.process_list.size;) {
      if (this.process_list.get(i).ended) {
        this.process_list.remove_at(i);
      } else {
        i++;
      }
    }

    bool has_processes = this.process_list.size > 0;
    this.watching = has_processes;

    if (!has_processes) {
      return Source.REMOVE;
    }

    bool needs_fast = this.requires_process_watching();
    if (needs_fast != this.fast_mode) {
      this.fast_mode = needs_fast;
      Timeout.add(
        this.fast_mode ? PROCESS_WATCHER_INTERVAL_FAST_MS :
        PROCESS_WATCHER_INTERVAL_SLOW_MS,
        this.watch_loop
      );
      return Source.REMOVE;
    }

    return Source.CONTINUE;
  }

  private bool requires_process_watching() {
    return Settings.get_default().context_aware_header_bar &&
           Settings.get_default().show_headerbar;
  }

  private bool is_process_still_running(Pid pid) {
    return check_pid_running(pid);
  }

  private string? get_cached_cmdline(int pid) {
    if (this.cmdline_cache.has_key(pid)) {
      return this.cmdline_cache[pid];
    }
    var cmdline = get_process_cmdline(pid);
    if (cmdline != null && cmdline != "") {
      this.cmdline_cache[pid] = cmdline;
    }
    return cmdline;
  }

  // Like check_process, but skips cmdline/context tracking — only watches
  // foreground PID lifecycle for notifications.
  private void check_process_minimal(Process process) {
    if (
      process.foreground_pid >= 0 &&
      !is_process_still_running(process.foreground_pid)
    ) {
      this.cmdline_cache.unset(process.foreground_pid);
      process.foreground_task_finished();
      process.foreground_pid = -1;
    }

    get_foreground_process.begin(process.terminal_fd, null, (_, res) => {
      int foreground_pid = get_foreground_process.end(res);

      if (
        foreground_pid >= 0 &&
        foreground_pid != process.pid &&
        foreground_pid != process.foreground_pid
      ) {
        process.foreground_pid = foreground_pid;
      }
    });

    process.ended = !check_pid_running(process.pid);
    if (process.ended) {
      this.cmdline_cache.unset(process.pid);
    }
  }

  private void check_process(Process process) {
    if (
      process.foreground_pid >= 0 &&
      !is_process_still_running(process.foreground_pid)
    ) {
      this.cmdline_cache.unset(process.foreground_pid);
      process.foreground_task_finished();
      process.foreground_pid = -1;
    }

    get_foreground_process.begin(process.terminal_fd, null, (_, res) => {
      int foreground_pid = get_foreground_process.end(res);

      if (
        foreground_pid >= 0 &&
        foreground_pid != process.pid &&
        foreground_pid != process.foreground_pid
      ) {
        var cmdline = this.get_cached_cmdline(foreground_pid);

        if (cmdline == null || cmdline == "") {
          return;
        }

        process.foreground_pid = foreground_pid;
        process.last_foreground_task_command = cmdline;
      }
    });

    process.ended = !check_pid_running(process.pid);
    if (process.ended) {
      this.cmdline_cache.unset(process.pid);
      return;
    }

    try {
      var source_pid = process.foreground_pid > -1
            ? process.foreground_pid
            : process.pid;

      var euid = get_euid_from_pid(source_pid, null);

      if (euid == 0) {
        process.context = ProcessContext.ROOT;
      } else {
        var command = this.get_cached_cmdline(source_pid);

        if (command != null && command.has_prefix("ssh")) {
          process.context = ProcessContext.SSH;
        } else {
          process.context = ProcessContext.DEFAULT;
        }
      }
    } catch (GLib.Error e) {
      warning(e.message);
    }
  }
}
