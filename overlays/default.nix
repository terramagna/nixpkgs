final: prev: {
  bazel-watcher = import ./development/tools/bazel-watcher.nix final prev;
  pre-commit = import ./tools/misc/pre-commit.nix final prev;
}
