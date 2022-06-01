{pkgs}: let
  inherit (pkgs) buildFHSUserEnvBubblewrap;

  attrsToList = pkgs.lib.mapAttrsToList (name: value: {inherit name value;});
  attrsToSubmodulesList = attrs:
    map
    ({
      name,
      value,
    }:
      value // {inherit name;})
    (attrsToList attrs);

  /*
    *
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
  in
    {
      bubblewrap ? false,
      commands ? {},
      env ? {},
      packages ? _pkgs: [],
      startup ? {},
      ...
    } @ args: let
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
        ];

      bashEnv = pkgs.writeText "bash-env" ''
        export PS1='\033[0;31m[\u:\W]\033[0m '

        ${builtins.concatStringsSep "\n" (builtins.attrValues (builtins.mapAttrs (n: v: "export ${n}=${v}") env))}
        ${builtins.concatStringsSep "\n" (builtins.attrValues startup)}

        menu
      '';

      bubbleWrappedShell =
        (pkgs.buildFHSUserEnvBubblewrap (cleanArgs
          // {
            targetPkgs = pkgs: (packages pkgs) ++ map commandToBin commandsList;
            multiPkgs = pkgs: with pkgs; [gcc];
            runScript = "bash --init-file ${bashEnv}";
            extraOutputsToInstall = ["dev"];
          }))
        .env;

      commonShell = pkgs.mkShell (cleanArgs
        // {
          packages = (packages pkgs) ++ map commandToBin commandsList;
          shellHook = "source ${bashEnv}";
        });
    in
      if bubblewrap
      then bubbleWrappedShell
      else commonShell;
in {
  inherit mkTmShell;
}
