{
  pkgs ? builtins.throw "Did you use `nix-shell`? This configuration uses flakes and only supports `nix develop`",
  lib ? null,
  startup ? {},
}: let
  inherit (lib) mkTmShell;
in
  mkTmShell {
    inherit startup;

    name = "tm-nixpkgs";

    commands = {
      c = {
        help = "Check the flake outputs";
        command = "nix flake check path:.";
        category = "helpers";
      };

      pc = {
        help = "Run the pre-commit checks";
        command = "pre-commit run -a";
        category = "helpers";
      };
    };
  }
