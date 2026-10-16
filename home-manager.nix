{ heliumFlake, spoofdpium }:
{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib) mkOption mkEnableOption types;
  cfg = config.programs.helium;
  extension = types.submodule {
    options = {
      id = mkOption { type = types.strMatching "[a-p]{32}"; };
      crxPath = mkOption { type = types.str; };
      version = mkOption { type = types.str; };
    };
  };
in
{
  options.programs.helium = {
    enable = mkEnableOption "Helium browser";
    package = mkOption {
      type = types.package;
      default = heliumFlake.packages.${pkgs.stdenv.hostPlatform.system}.helium;
    };
    commandLineArgs = mkOption {
      type = types.listOf types.str;
      default = [ ];
    };
    proxy = {
      enable = mkEnableOption "spoofdpi proxy";
      package = mkOption {
        type = types.package;
        default = spoofdpium.inputs.spoofdpi.packages.${pkgs.stdenv.hostPlatform.system}.default;
      };
      port = mkOption {
        type = types.ints.between 1 65535;
        default = 48202;
      };
    };
    extensions = mkOption {
      type = types.listOf extension;
      default = [ ];
    };
    finalPackage = mkOption {
      type = types.package;
      readOnly = true;
      default = pkgs.callPackage ./wrapped-package.nix {
        helium = cfg.package;
        spoofdpiumSource = spoofdpium.outPath;
        spoofdpi = cfg.proxy.package;
        proxyEnabled = cfg.proxy.enable;
        proxyPort = cfg.proxy.port;
        commandLineArgs = [
          "--user-data-dir=${config.xdg.configHome}/net.imput.helium"
        ]
        ++ cfg.commandLineArgs;
      };
    };
  };
  config = lib.mkIf cfg.enable {
    home.packages = [ cfg.finalPackage ];
    xdg.configFile = builtins.listToAttrs (
      map (ext: {
        name = "net.imput.helium/External Extensions/${ext.id}.json";
        value.text = builtins.toJSON {
          external_crx = ext.crxPath;
          external_version = ext.version;
        };
      }) cfg.extensions
    );
  };
}
