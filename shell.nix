{
  lib ? null,
  startup ? {},
}: let
  inherit (lib) mkTmShell;
in
  mkTmShell {
    bubblewrap = true;
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
