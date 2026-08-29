{
  description = "Nix flake for AdventureLog frontend (SvelteKit) and backend (Django)";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { self, nixpkgs, ... }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
      mkPkgs = system: import nixpkgs {
        inherit system;
        overlays = [ self.overlays.default ];
      };
    in
    {
      overlays.default = import ./overlays.nix;

      packages = forAllSystems (system: import ./packages.nix { pkgs = mkPkgs system; });

      checks = nixpkgs.lib.recursiveUpdate
        (forAllSystems (system: {
          backend = self.packages.${system}.adventurelog-backend;
          frontend = self.packages.${system}.adventurelog-frontend;
        }))
        {
          x86_64-linux.default =
            let
              pkgs = mkPkgs "x86_64-linux";
              test = pkgs.testers.runNixOSTest (import ./test.nix { inherit self; });
            in
            test.overrideTestDerivation (old: {
              requiredSystemFeatures = builtins.filter (feature: feature != "kvm") old.requiredSystemFeatures;
            });
        };

      nixosModules.default =
        { pkgs, lib, ... }:
        {
          imports = [ ./module.nix ];
          services.adventurelog = {
            frontend = lib.mkDefault self.packages.${pkgs.stdenv.hostPlatform.system}.adventurelog-frontend;
            backend = lib.mkDefault self.packages.${pkgs.stdenv.hostPlatform.system}.adventurelog-backend;
          };
        };

      devShells = forAllSystems (system: {
        default =
          let
            pkgs = mkPkgs system;
          in
          pkgs.mkShell {
            packages = with pkgs; [
              uv
              nodejs_22
              pnpm_10
              memcached
              postgresql_16
              nix-update
              jq
              adventurelog-python-env
            ];
          };
      });
    };
}
