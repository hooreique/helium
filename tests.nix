{
  pkgs,
  self,
  spoofdpium,
}:
let
  inherit (pkgs) lib;
  module = self.homeManagerModules.default;
  eval =
    settings:
    lib.evalModules {
      specialArgs = { inherit pkgs; };
      modules = [
        module
        {
          options = {
            home.packages = lib.mkOption {
              type = lib.types.listOf lib.types.package;
              default = [ ];
            };
            xdg.configHome = lib.mkOption {
              type = lib.types.str;
              default = "/test/config";
            };
            xdg.configFile = lib.mkOption {
              type = lib.types.attrsOf lib.types.anything;
              default = { };
            };
          };
        }
        { programs.helium = settings; }
      ];
    };
  disabled = eval { };
  enabled = eval { enable = true; };
  customized = eval {
    enable = true;
    package = fakeBrowser;
    proxy = {
      enable = true;
      package = fakeProxy;
      port = 49202;
    };
    extensions = [
      {
        id = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa";
        crxPath = "/test.crx";
        version = "1.2";
      }
    ];
  };
  rejects =
    port: !(builtins.tryEval (eval { proxy.port = port; }).config.programs.helium.proxy.port).success;
  fakeBrowser =
    (pkgs.writeScriptBin "helium" ''
      #!${pkgs.python3}/bin/python3
      import json, os, time
      from pathlib import Path
      Path(os.environ['BROWSER_LOG']).write_text(json.dumps(__import__('sys').argv[1:]))
      while os.environ.get('BROWSER_HOLD') and not Path(os.environ['BROWSER_HOLD']).exists():
          time.sleep(.02)
    '').overrideAttrs
      (old: {
        buildCommand = old.buildCommand + ''
            mkdir -p "$out/share/applications"
            cat > "$out/share/applications/helium.desktop" <<DESKTOP
          [Desktop Entry]
          Type=Application
          Name=Helium
          Exec=$out/bin/helium %U
          Actions=new-window;incognito;
          [Desktop Action new-window]
          Name=New Window
          Exec=$out/bin/helium %U
          [Desktop Action incognito]
          Name=Incognito
          Exec=$out/bin/helium --incognito %U
          DESKTOP
        '';
        meta.mainProgram = "helium";
      });
  fakeProxy = pkgs.writeScriptBin "spoofdpi" ''
    #!${pkgs.python3}/bin/python3
    import os, socket, sys, time
    from pathlib import Path
    if os.environ.get('PROXY_FAIL'): sys.exit(2)
    host, port = sys.argv[sys.argv.index('--listen-addr')+1].split(':')
    sock = socket.socket()
    sock.bind((host, int(port)))
    sock.listen()
    Path(os.environ['PROXY_LOG']).write_text(str(os.getpid()))
    while True: time.sleep(.02)
  '';
  wrap =
    port: proxyEnabled:
    pkgs.callPackage ./wrapped-package.nix {
      helium = fakeBrowser;
      spoofdpiumSource = spoofdpium.outPath;
      spoofdpi = fakeProxy;
      proxyPort = port;
      inherit proxyEnabled;
      commandLineArgs = [
        "argument with spaces"
        ""
        "literal'\"$()`"
      ];
    };
in
{
  desktop-integration = pkgs.runCommand "helium-desktop-integration" { } ''
    desktop=${self.packages.x86_64-linux.helium-spoofdpium}/share/applications/helium.desktop
    test "$(grep -c '^Exec=' "$desktop")" -eq 3
    test "$(grep -c '^Exec=${self.packages.x86_64-linux.helium-spoofdpium}/bin/helium' "$desktop")" -eq 3
    grep '^Exec=.* --new-window' "$desktop"
    grep '^Exec=.* --incognito' "$desktop"
    test -f ${self.packages.x86_64-linux.helium}/lib/helium/locales/ko.pak
    touch "$out"
  '';
  module-evaluation =
    assert disabled.config.home.packages == [ ];
    assert enabled.config.programs.helium.proxy.enable == false;
    assert enabled.config.programs.helium.proxy.port == 48202;
    assert enabled.config.home.packages == [ enabled.config.programs.helium.finalPackage ];
    assert customized.config.programs.helium.package == fakeBrowser;
    assert customized.config.programs.helium.proxy.package == fakeProxy;
    assert customized.config.programs.helium.proxy.port == 49202;
    assert
      builtins.fromJSON
        customized.config.xdg.configFile."net.imput.helium/External Extensions/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.json".text
      == {
        external_crx = "/test.crx";
        external_version = "1.2";
      };
    assert rejects 0 && rejects 65536 && rejects "48202";
    pkgs.runCommand "helium-module-evaluation" { } ''touch "$out"'';
  launcher-runtime =
    pkgs.runCommand "helium-launcher-runtime"
      {
        nativeBuildInputs = [ pkgs.python3 ];
        HELIUM = "${wrap 48202 true}/bin/helium";
        CHROMIUM = "${wrap 48201 true}/bin/helium";
        DIRECT = "${wrap 48202 false}/bin/helium";
        CUSTOM = "${customized.config.programs.helium.finalPackage}/bin/helium";
      }
      ''
        python ${./tests-runtime.py}
        touch "$out"
      '';
}
