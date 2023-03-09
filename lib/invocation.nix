_: {
  isInvocationImpure = let
    # Build phase is always present inside a nix shell.
    testEnv = builtins.getEnv "buildPhase";
  in
    testEnv != "";
}
