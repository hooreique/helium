{
  description = "Helium browser 0.19.3.1 for x86_64-linux";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { nixpkgs, ... }:
    let
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
      helium = pkgs.callPackage ./package.nix { };
      app = {
        type = "app";
        program = "${helium}/bin/helium";
      };
    in
    {
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
