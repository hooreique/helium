{
  description = "Helium browser 0.19.3.1 for x86_64-linux";
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  inputs.spoofdpium.url = "github:hooreique/spoofdpium";

  outputs =
    {
      self,
      nixpkgs,
      spoofdpium,
      ...
    }:
    let
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
      helium = pkgs.callPackage ./package.nix { };
      wrap =
        pkgs: helium:
        pkgs.callPackage ./wrapped-package.nix {
          inherit helium;
          spoofdpiumSource = spoofdpium.outPath;
          spoofdpi = spoofdpium.inputs.spoofdpi.packages.${pkgs.stdenv.hostPlatform.system}.default;
        };
      helium-spoofdpium = wrap pkgs helium;
      helium-spoofdpi = spoofdpium.inputs.spoofdpi.packages.x86_64-linux.default;
      app = {
        type = "app";
        program = "${helium}/bin/helium";
      };
    in
    {
      homeManagerModules.default = import ./home-manager.nix {
        heliumFlake = self;
        inherit spoofdpium;
      };
      overlays = {
        default = final: _prev: {
          helium-spoofdpi = spoofdpium.inputs.spoofdpi.packages.${final.stdenv.hostPlatform.system}.default;
          helium = final.callPackage ./package.nix { };
          helium-spoofdpium = wrap final (final.callPackage ./package.nix { });
        };
        pinned = final: _prev: {
          inherit (self.packages.${final.stdenv.hostPlatform.system})
            helium
            helium-spoofdpium
            helium-spoofdpi
            ;
        };
      };
      packages.x86_64-linux = {
        default = helium;
        inherit helium helium-spoofdpium helium-spoofdpi;
      };
      apps.x86_64-linux = {
        default = app;
        helium = app;
        helium-spoofdpium = {
          type = "app";
          program = "${helium-spoofdpium}/bin/helium";
        };
      };
      checks.x86_64-linux = {
        inherit helium helium-spoofdpium;
      }
      // import ./tests.nix { inherit pkgs self spoofdpium; };
    };
}
