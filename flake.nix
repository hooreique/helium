{
  description = "Helium browser 0.19.3.1 for x86_64-linux";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { self, nixpkgs, ... }:
    let
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
      helium = pkgs.callPackage ./package.nix { };
      app = {
        type = "app";
        program = "${helium}/bin/helium";
      };
    in
    {
      overlays = {
        default = final: _prev: {
          helium = final.callPackage ./package.nix { };
        };

        pinned = final: _prev: {
          helium = self.packages.${final.stdenv.hostPlatform.system}.helium;
        };
      };

      packages.x86_64-linux = {
        default = helium;
        inherit helium;
      };

      apps.x86_64-linux = {
        default = app;
        helium = app;
      };

      checks.x86_64-linux.helium = helium;
    };
}
