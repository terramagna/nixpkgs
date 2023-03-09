args: let
  invocation = import ./invocation.nix args;
  shell = import ./shell.nix (args // {inherit lib;});
  lib = {
    inherit (shell) mkTmShell;
    inherit shell invocation;
  };
in
  lib
