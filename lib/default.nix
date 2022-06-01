args: let
  shell = import ./shell.nix args;
in {
  inherit (shell) mkTmShell;
  inherit shell;
}
