{
  lib,
  stdenv,
  meson,
  ninja,
  pkg-config,
  vala,
  gettext,
  python3,
  desktop-file-utils,
  wrapGAppsHook4,
  gtk4,
  libadwaita,
  vte-gtk4,
  json-glib,
  pcre2,
  libxml2,
  librsvg,
  libgee,
  graphene,
  dbus,
  xvfb-run,
}:

stdenv.mkDerivation {
  pname = "blackbox-next";
  version = "0.15.2.2";
  src = lib.cleanSourceWith {
    src = ./.;
    filter = path: type:
      lib.cleanSourceFilter path type
      && !(builtins.elem (baseNameOf path) [ "_build" "builddir" "result" ]);
  };

  nativeBuildInputs = [
    meson ninja pkg-config vala gettext python3 desktop-file-utils wrapGAppsHook4
  ];
  buildInputs = [
    gtk4 libadwaita vte-gtk4 json-glib pcre2 libxml2 librsvg libgee graphene
  ];
  nativeCheckInputs = [ dbus xvfb-run ];

  postPatch = ''
    substituteInPlace build-aux/meson/postinstall.py \
      --replace-fail 'gtk-update-icon-cache' 'gtk4-update-icon-cache'
    patchShebangs build-aux/meson/postinstall.py
  '';

  doCheck = true;
  checkPhase = ''
    runHook preCheck
    dbus-run-session -- xvfb-run -a meson test --print-errorlogs
    runHook postCheck
  '';

  meta = {
    description = "Black Box fork for GNOME 50, with VTE GPU rendering and stability fixes";
    license = lib.licenses.gpl3Plus;
    platforms = lib.platforms.linux;
    mainProgram = "blackbox-next";
  };
}
