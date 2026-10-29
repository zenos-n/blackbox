// SPDX-License-Identifier: GPL-3.0-or-later

void test_invalid_pids() {
  assert(!Terminal.check_pid_running(-1));
  assert(!Terminal.check_pid_running(0));
  assert(Terminal.check_pid_running(Posix.getpid()));
}

void test_missing_process_owner() {
  try {
    Terminal.get_euid_from_pid(int.MAX, null);
    assert_not_reached();
  } catch (IOError e) {
    assert(e is IOError.NOT_FOUND);
  } catch (Error e) {
    assert_not_reached();
  }
}

void test_missing_file() {
  try {
    var file = new Terminal.File("/this-path-does-not-exist/blackbox.json");
    file.read_all(null);
    assert_not_reached();
  } catch (Error e) {
    assert(e is IOError.NOT_FOUND);
  }
}

void test_file_roundtrip() {
  try {
    var directory = DirUtils.make_tmp("blackbox-test-XXXXXX");
    var path = Path.build_filename(directory, "keymap.json");
    var file = new Terminal.File(path);
    string text = "{\"test\": \"Zażółć 🐈\"}";
    file.write_plus(text);
    size_t length;
    assert(file.read_all(out length) == text);
    assert(length == text.length);
    file.write_plus("{}");
    assert(file.read_all(out length) == "{}");
    assert(length == 2);
    file.write_plus("");
    assert(file.read_all(out length) == null);
    assert(length == 0);
    FileUtils.unlink(path);
    DirUtils.remove(directory);
  } catch (Error e) {
    error("%s", e.message);
  }
}

void test_command_arguments() {
  string[] command = { "printf", "<%s>\\n", "two words", "", "a'b",
                       "$(printf injected)", ";exit 7" };
  try {
    string output;
    int status;
    Process.spawn_sync(null, { "/bin/sh", "-c", Terminal.shell_command_from_argv(command) },
                       null, 0, null, out output, null, out status);
    assert(status == 0);
    assert(output == "<two words>\n<>\n<a'b>\n<$(printf injected)>\n<;exit 7>\n");
  } catch (Error e) {
    error("%s", e.message);
  }
}

int main(string[] args) {
  Test.init(ref args);
  Test.add_func("/process/invalid-pids", test_invalid_pids);
  Test.add_func("/process/missing-owner", test_missing_process_owner);
  Test.add_func("/files/missing", test_missing_file);
  Test.add_func("/files/roundtrip", test_file_roundtrip);
  Test.add_func("/command/argument-boundaries", test_command_arguments);
  return Test.run();
}
