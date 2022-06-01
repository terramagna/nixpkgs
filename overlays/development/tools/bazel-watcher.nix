final: prev: let
  inherit (final) stdenv fetchurl;
  inherit (stdenv) mkDerivation isAarch64 isDarwin;

  # On Darwin, we can not currently simply use `pkgs.bazel-watcher`. For more information on this
  # issue, see:
  # - https://github.com/NixOS/nixpkgs/issues/105573
  # - https://github.com/NixOS/nixpkgs/issues/150655
  bazel-watcher-darwin = mkDerivation rec {
    # https://github.com/bazelbuild/bazel-watcher/releases
    pname = "bazel-watcher";
    version = "0.16.2";

    bin-name = "ibazel";

    src = let
      target =
        if isAarch64
        then {
          arch = "arm64";
          sha256 = "sha256-Awl3c4VWAyhmo/hA27e7Tk/QCkKydh694Di3tWmJ7Ug=";
        }
        else {
          arch = "amd64";
          sha256 = "sha256-voHQoZgEv75XHVYu9a1T3Ci2qxySDRUOW41IBCz5Gag=";
        };
    in
      with target;
        fetchurl {
          url = "https://github.com/bazelbuild/${pname}/releases/download/v${version}/ibazel_darwin_${arch}";
          inherit sha256;
        };

    phases = ["installPhase" "checkPhase"];

    installPhase = ''
      mkdir -p $out/bin
      cp $src $out/bin/${bin-name}
      chmod +x $out/bin/${bin-name}
    '';

    checkPhase = ''
      version_line=$($out/bin/${bin-name} --help 2>&1 | head -n 1 -)
      test "$version_line" = "iBazel - Version ${version}"
      exit $?
    '';
  };
in
  if isDarwin
  then bazel-watcher-darwin
  else prev.bazel-watcher
