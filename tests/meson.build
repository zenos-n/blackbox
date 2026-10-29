test('Core regressions', core_tests)
test('Benchmark self-check', find_program('python3'),
  args: [files('../tools/benchmark.py'), '--self-test'])

custom_target('test-schemas',
  input: '../data/com.neg-zero.BlackBoxNext.gschema.xml',
  output: 'gschemas.compiled',
  command: [compile_schemas, '--targetdir', meson.current_build_dir(),
            meson.project_source_root() / 'data'],
  build_by_default: true,
)

test_env = {
  'GSETTINGS_BACKEND': 'memory',
  'GSETTINGS_SCHEMA_DIR': meson.current_build_dir(),
  'GTK_A11Y': 'none',
  'BLACKBOX_TEST_SOURCE': meson.project_source_root(),
}
test('GTK regressions', find_program('python3'),
  args: [files('run-gui.py'), gui_tests], env: test_env)
test('Process regressions', find_program('python3'),
  args: [files('run-gui.py'), gui_tests],
  env: test_env + {'BLACKBOX_TEST_PROCESS_ONLY': '1'})
