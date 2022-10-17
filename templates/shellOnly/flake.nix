{
  # Change this description to something appropriate
  description = "My flake description";

  inputs = {
    tm-nixpkgs.url = "github:terramagna/nixpkgs";
  };

  outputs = {tm-nixpkgs, ...}:
    tm-nixpkgs.lib.forEachSystem (system: let
      tm-lib = tm-nixpkgs.lib.${system};
    in {
      devShells.default = tm-lib.mkTmShell {
        name = "my-project";

        # Custom commands
        commands = {};

        # Custom environment variables.
        env = {};

        # Add your project dependencies here.
        packages = pkgs:
          with pkgs; [
          ];

        # Custom startup code.
        startup = {};
      };
    });
}
