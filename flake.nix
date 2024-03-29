{
  description = "Nix packages and utilities used at TerraMagna";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-22.05";

    flake-utils.url = "github:numtide/flake-utils";

    pre-commit-hooks.url = "github:cachix/pre-commit-hooks.nix";
    pre-commit-hooks.inputs.flake-utils.follows = "flake-utils";
    pre-commit-hooks.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = {
    nixpkgs,
    flake-utils,
    pre-commit-hooks,
    ...
  }: let
    forEachSystem = flake-utils.lib.eachSystem (with flake-utils.lib.system; [
      x86_64-linux
      aarch64-linux
      x86_64-darwin
      aarch64-darwin
    ]);

    overlay = import ./overlays;
    nixpkgsFor = let
      allPkgs = forEachSystem (system: {
        pkgs = import nixpkgs {
          inherit system;
          overlays = [overlay];
        };
      });
    in
      sys: allPkgs.pkgs.${sys};

    pre-commit-check-for = sys:
      pre-commit-hooks.lib.${sys}.run {
        src = ./.;
        hooks = {
          alejandra.enable = true;
          statix.enable = true;

          deadnix.enable = true;
        };
      };

    buildFlakeForSystem = system: let
      pkgs = nixpkgsFor system;
      pre-commit-check = pre-commit-check-for system;

      overlayPkgs =
        builtins.listToAttrs
        (builtins.map (p: {
            name = p;
            value = pkgs.${p};
          })
          (builtins.attrNames (overlay pkgs pkgs)));
    in rec {
      checks = {
        inherit pre-commit-check;

        # Ensures that all our overlays build correctly.
        overlay-check = pkgs.symlinkJoin {
          name = "all-overlays";
          paths = builtins.attrValues overlayPkgs;
        };
      };

      lib = import ./lib {inherit pkgs;};

      devShells.default = import ./shell.nix {
        inherit lib;
        startup.pre-commit = pre-commit-check.shellHook;
      };

      packages = overlayPkgs;
    };

    baseFlake = {
      overlays.default = overlay;
      lib = {inherit forEachSystem;};
      templates = {
        shellOnly = {
          path = ./templates/shellOnly;
          description = "A template for shell only projects";
        };
      };
    };

    systemFlakes = forEachSystem buildFlakeForSystem;
  in
    systemFlakes
    // {
      lib = systemFlakes.lib // baseFlake.lib;
    }
    // (builtins.removeAttrs baseFlake ["lib"]);
}
