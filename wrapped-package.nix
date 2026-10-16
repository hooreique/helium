{
  lib,
  symlinkJoin,
  writeShellScriptBin,
  callPackage,
  helium,
  spoofdpiumSource,
  spoofdpi,
  commandLineArgs ? [ ],
  proxyEnabled ? true,
  proxyPort ? 48202,
}:
let
  browser = writeShellScriptBin "helium" ''
    exec ${lib.getExe helium} ${lib.escapeShellArgs commandLineArgs} "$@"
  '';
  proxy = callPackage (spoofdpiumSource + "/package.nix") {
    chromium = browser;
    inherit spoofdpi proxyPort;
  };
  launcher = writeShellScriptBin "helium" ''
    exec ${if proxyEnabled then lib.getExe proxy else lib.getExe browser} "$@"
  '';
in
symlinkJoin {
  name = "helium-configured";
  paths = [
    launcher
    helium
  ];
  postBuild = ''
    # Replace symlinks before editing so the original package stays immutable.
    rm -rf "$out/share/applications"
    mkdir -p "$out/share/applications"
    cp -L ${helium}/share/applications/*.desktop "$out/share/applications/"
    chmod u+w "$out/share/applications/"*.desktop
    sed -i -E "s|^Exec=[^ ]+|Exec=$out/bin/helium|" "$out/share/applications/"*.desktop
    sed -i '/^\[Desktop Action new-window\]/ ,/^$/ { /^Exec=/ { /--new-window/! s/$/ --new-window/; }; }' "$out/share/applications/"*.desktop
  '';
  meta = helium.meta // {
    mainProgram = "helium";
  };
}
