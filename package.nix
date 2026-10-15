{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  wrapGAppsHook4,
  addDriverRunpath,
  alsa-lib,
  at-spi2-core,
  cairo,
  cups,
  dbus,
  expat,
  glib,
  gtk4,
  gsettings-desktop-schemas,
  libGL,
  libgbm,
  libpulseaudio,
  libva,
  libx11,
  libxcb,
  libxcomposite,
  libxdamage,
  libxext,
  libxfixes,
  libxkbcommon,
  libxrandr,
  nspr,
  nss,
  pango,
  pciutils,
  pipewire,
  systemdLibs,
  vulkan-loader,
  wayland,
  xdg-utils,
}:

let
  # Chromium loads these libraries with dlopen rather than linking them directly.
  runtimeLibraries = [
    gtk4
    libGL
    libpulseaudio
    libva
    pciutils
    pipewire
    vulkan-loader
    wayland
  ];
in
stdenv.mkDerivation (finalAttrs: {
  pname = "helium-bin";
  version = "0.19.3.1";

  src = fetchurl {
    url = "https://github.com/imputnet/helium-linux/releases/download/${finalAttrs.version}/helium-${finalAttrs.version}-x86_64_linux.tar.xz";
    hash = "sha256-j04BK12SH6WSaar5xUFgq/cpTGM7Gmql7bdyWUUxRXA=";
  };

  nativeBuildInputs = [
    autoPatchelfHook
    wrapGAppsHook4
  ];

  buildInputs = [
    alsa-lib
    at-spi2-core
    cairo
    cups
    dbus
    expat
    glib
    gsettings-desktop-schemas
    libgbm
    # The upstream binary links these even when running on Wayland.
    libx11
    libxcb
    libxcomposite
    libxdamage
    libxext
    libxfixes
    libxkbcommon
    libxrandr
    nspr
    nss
    pango
    stdenv.cc.cc.lib
    systemdLibs
  ]
  ++ runtimeLibraries;

  dontConfigure = true;
  dontBuild = true;
  dontStrip = true;
  dontWrapGApps = true;

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/lib/helium" "$out/bin"
    cp -a . "$out/lib/helium/"

    # GNOME uses GTK; the optional Qt integrations are unnecessary here.
    rm "$out/lib/helium/libqt5_shim.so" "$out/lib/helium/libqt6_shim.so"

    # The Nixpkgs loader also discovers drivers in /run/opengl-driver.
    rm "$out/lib/helium/libvulkan.so.1"
    ln -s "${lib.getLib vulkan-loader}/lib/libvulkan.so.1" \
      "$out/lib/helium/libvulkan.so.1"

    install -Dm644 helium.desktop "$out/share/applications/helium.desktop"
    substituteInPlace "$out/share/applications/helium.desktop" \
      --replace-fail 'Exec=helium' "Exec=$out/bin/helium"
    install -Dm644 product_logo_256.png \
      "$out/share/icons/hicolor/256x256/apps/helium.png"

    ln -s "$out/lib/helium/helium-wrapper" "$out/bin/helium"

    runHook postInstall
  '';

  preFixup = ''
    makeWrapper "$out/lib/helium/helium" "$out/lib/helium/helium-wrapper" \
      "''${gappsWrapperArgs[@]}" \
      --set CHROME_WRAPPER "$out/lib/helium/helium-wrapper" \
      --set CHROME_VERSION_EXTRA nix \
      --prefix PATH : "${lib.makeBinPath [ xdg-utils ]}" \
      --prefix LD_LIBRARY_PATH : "$out/lib/helium:${lib.makeLibraryPath runtimeLibraries}" \
      --prefix XDG_DATA_DIRS : "${addDriverRunpath.driverLink}/share"
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    "$out/bin/helium" --version | grep -F "Helium ${finalAttrs.version} "
    runHook postInstallCheck
  '';

  meta = {
    description = "Private, fast, and honest web browser based on Chromium";
    homepage = "https://helium.com";
    changelog = "https://github.com/imputnet/helium-linux/releases/tag/${finalAttrs.version}";
    license = lib.licenses.gpl3Only;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    mainProgram = "helium";
    platforms = [ "x86_64-linux" ];
  };
})
