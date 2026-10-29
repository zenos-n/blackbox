subdir('icons')

install_subdir('schemes', install_dir: join_paths(get_option('datadir'), 'blackbox-next'))

desktop_file = i18n.merge_file(
  input: 'com.neg-zero.BlackBoxNext.desktop.in',
  output: 'com.neg-zero.BlackBoxNext.desktop',
  type: 'desktop',
  po_dir: '../po',
  install: true,
  install_dir: join_paths(get_option('datadir'), 'applications'),
)

desktop_utils = find_program('desktop-file-validate', required: false)
if desktop_utils.found()
  test('Validate desktop file', desktop_utils, args: [desktop_file])
endif

appstream_file = i18n.merge_file(
  input: 'com.neg-zero.BlackBoxNext.metainfo.xml.in',
  output: 'com.neg-zero.BlackBoxNext.metainfo.xml',
  po_dir: '../po',
  install: true,
  install_dir: join_paths(get_option('datadir'), 'metainfo'),
)

appstreamcli = find_program('appstreamcli', required: false)
if appstreamcli.found()
  validate_args = ['validate', appstream_file, '--pedantic', '--explain']
  if not get_option('network_tests')
    validate_args += '--no-net'
  endif
  test('Validate appstream file', appstreamcli, args: validate_args)
endif

# No need to install the Nautilus extension on platforms other than Linux. We
# may also want to skip installation if Nautilus isn't already installed, but
# that could generate confusion if a user installs Nautilus *after* Black Box
# and realizes they have no access to the extension.
if host_machine.system() == 'linux'
  install_data(
    'nautilus/open-blackbox-next.py',
    install_dir: join_paths(get_option('datadir'), 'nautilus-python/extensions'),
  )
endif

install_data(
  'com.neg-zero.BlackBoxNext.gschema.xml',
  install_dir: join_paths(get_option('datadir'), 'glib-2.0/schemas'),
)

compile_schemas = find_program('glib-compile-schemas', required: false)
if compile_schemas.found()
  test(
    'Validate schema file',
    compile_schemas,
    args: ['--strict', '--dry-run', meson.current_source_dir()],
  )
endif
