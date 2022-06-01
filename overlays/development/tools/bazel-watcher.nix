final: prev: let
  # On Darwin, we can not currently simply use `pkgs.bazel-watcher`. For more information on this
  # issue, see:
  # - https://github.com/NixOS/nixpkgs/issues/105573
  # - https://github.com/NixOS/nixpkgs/issues/150655
  bazel-watcher-darwin = stdenv.mkDerivation rec {
    # https://github.com/bazelbuild/bazel-watcher/releases
    pname = "bazel-watcher";
    version = "0.16.2";

    bin-name = "ibazel";

    src = let
      target =
        if stdenv.isAarch64
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
        pkgs.fetchurl {
          url = "https://github.com/bazelbuild/${pname}/releases/download/v${version}/ibazel_darwin_${arch}";
          inherit sha256;
        };

    phases = ["installPhase"];

    installPhase = ''
      mkdir -p $out/bin
      cp $src $out/bin/${bin-name}
      chmod +x $out/bin/${bin-name}
    '';
  };
in
  if final.stdenv.isDarwin
  then bazel-watcher-darwin
  else prev.bazel-watcher
