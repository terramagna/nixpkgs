{
  pkgs,
  lib,
}: let
  inherit (lib.invocation) isInvocationImpure;
  inherit (pkgs.lib.asserts) assertMsg;
  inherit (pkgs.lib.strings) hasInfix;
  inherit (pkgs.stdenv) isLinux;

  attrsToList = pkgs.lib.mapAttrsToList (name: value: {inherit name value;});
  attrsToSubmodulesList = attrs:
    map
    ({
      name,
      value,
    }:
      value // {inherit name;})
    (attrsToList attrs);

  isNixOS = let
    issue =
      if builtins.pathExists "/etc/issue"
      then builtins.readFile "/etc/issue"
      else "";
  in
    isLinux && (hasInfix "NixOS" issue);

  /*
   * A custom `mkShell` implementation that has suppor for easily defining
   * custom commands and creating bubblewrapped FHS environments.
   *
   * ## Bubblewrapping
   *
   * If the argument `bubblewrap` is set to `true`, the shell will be created
   * inside a bubblewrapped FHS environment (i.e. using Nixpkgs'
   * buildFHSUserEnvBubblewrap). If value is `false` (or not present), the
   * shell is created using `mkShell`.
   *
   * Having a bubblewrapped shell is useful if a dependency of the project
   * needs some native dependency stored in a FHS location, e.g. libstdc++.
   * This is very common in Bazel workspaces, where downloaded binaries much
   * likely doesn't support NixOS systems.
   *
   * ## Commands
   *
   * The function accepts an argument named `commands`, that can be used to
   * define custom commands inside the shell, without having to mess with
   * Nixpkgs' builders.
   *
   * The shell will always provide the `menu` command, that shows a menu
   * with all the custom defined commands.
   *
   * ## Arguments
   *
   * The following arguments are accepted by this function:
   *
   * - `bubblewrap`: A boolean controlling if the shell will be bubblewrapped or not.
   * - `commands`: An attribute set of form `<name> -> { command, help, category }`,
   *   where each pair defines a custom command. The fields `help` and `category` are
   *   used to build `menu`'s output.
   * - `env`: An attribute set of form `<name> -> <value>` used to define custom environment
   *   variables inside the shell.
   * - `packages`: A _function_ that receives a Nixpkgs instance and returns the packages
   *   to install inside the shell. This will be passed to `targetPkgs` option ofr
   *   `buildFHSUserEnvBubblewrap`. Note that gcc is always present inside a bubblewrapped
   *   shell.
   * - `startup`: An attribute set which values will be executed at the start of the shell.
   *   This is an attribute set to improve the readability of the startup code.
   * - `bubblewrapOutsideNixOS`: A boolean controlling if we should enable bubblewrapping
   *   outside of NixOS systems. Defaults to false, as non-NixOS system already have proper
   *   FHS structure.
   *
   * Other than these, all of the remaining attributes are passed unchanged to the underlying
   * shell function (be it `mkShell` or `buildFHSUserEnvBubblewrap`). This behavior is present
   * to support situations where the interface provided here doesn't support certains use cases.
   */
  mkTmShell = let
    inherit (pkgs) writeShellScriptBin lib;
    inherit (lib) zipAttrsWithNames;

    commandToBin = cmd: writeShellScriptBin cmd.name cmd.command;
    commandsToMenu = commands: let
      pad = str: num:
        if num > 0
        then pad "${str} " (num - 1)
        else str;

      commandLengths =
        map ({name, ...}: builtins.stringLength name) commands;

      maxCommandLength =
        builtins.foldl'
        (max: v:
          if v > max
          then v
          else max)
        0
        commandLengths;

      commandCategories = lib.unique (zipAttrsWithNames ["category"] (_: vs: vs) commands).category;

      commandByCategoriesSorted = builtins.attrValues (
        lib.genAttrs
        commandCategories
        (category:
          lib.nameValuePair category (
            builtins.sort
            (a: b: a.name < b.name)
            (builtins.filter (x: x.category == category) commands)
          ))
      );

      opCat = kv: let
        category = kv.name;
        cmd = kv.value;
        opCmd = {
          name,
          help,
          ...
        }: let
          len = maxCommandLength - (builtins.stringLength name);
        in
          if help == null || help == ""
          then "  ${name}"
          else "  ${pad name len} - ${help}";
      in
        "\n[${category}]\n\n" + builtins.concatStringsSep "\n" (map opCmd cmd);
    in
      builtins.concatStringsSep "\n" (map opCat commandByCategoriesSorted) + "\n";

    shell =
      if isInvocationImpure
      then builtins.getEnv "SHELL"
      else "${pkgs.bashInteractive}/bin/bash";
  in
    {
      bubblewrap ? false,
      commands ? {},
      env ? {},
      packages ? _pkgs: [],
      startup ? {},
      bubblewrapOutsideNixOS ? false,
      ...
    } @ args: let
      startupScript = pkgs.writeScriptBin "startup" ''
        ${builtins.concatStringsSep "\n" (builtins.attrValues startup)}
      '';

      cleanArgs = builtins.removeAttrs args ["env" "commands" "packages" "startup" "bubblewrap"];
      commandsList =
        (attrsToSubmodulesList commands)
        ++ [
          {
            name = "menu";
            command = ''
              cat <<EOF
              ${commandsToMenu commandsList}
              EOF
            '';
            help = "prints this menu";
            category = "general commands";
          }
          {
            name = "startup";
            command = "${startupScript}/bin/startup";
            help = "re-run the shell startup process";
            category = "general commands";
          }
        ];

      bashEnv = pkgs.writeText "bash-env" ''
        # HACK: Apparently, `nix develop` is setting `SHELL` with a non-interactive Bash, which
        # causes issue such as those described here:
        # - https://github.com/NixOS/nixpkgs/issues/29960
        # - https://github.com/NixOS/nix/issues/2034
        export SHELL="${shell}"

        ${builtins.concatStringsSep "\n" (
          builtins.attrValues (
            builtins.mapAttrs (n: v: "export ${n}=${v}") env
          )
        )}
        . ${startupScript}/bin/startup

        menu

        exec ${shell}
      '';

      bubbleWrappedShell =
        (pkgs.buildFHSUserEnvBubblewrap (cleanArgs
          // {
            targetPkgs = pkgs: (packages pkgs) ++ map commandToBin commandsList;
            multiPkgs = _: [];
            runScript = "bash --init-file ${bashEnv}";
            extraOutputsToInstall = ["dev"];
          }))
        .env;

      commonShell = pkgs.mkShell (cleanArgs
        // {
          packages = (packages pkgs) ++ [pkgs.bashInteractive] ++ map commandToBin commandsList;
          shellHook = ". ${bashEnv}";
        });
    in
      assert assertMsg (bubblewrap && isLinux -> isInvocationImpure)
      "Bubblewrap configured, Linux users need to pass --impure.";
      # Bubblewrapping outside NixOS cause problems if the user don't configure
      # their system also using Nix, as the `/usr` directories will be recreated
      # using only what we provide in the environment.
        if (bubblewrap && (isNixOS || bubblewrapOutsideNixOS))
        then bubbleWrappedShell
        else commonShell;
in {
  inherit mkTmShell;
}
