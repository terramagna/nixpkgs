# pre-commit checkPhase depends on many toolchain that we
# would not need otherwise, one being dotnet-sdk, which is
# broken for Darwin on nixos-unstable.
_final: prev:
(prev.pre-commit.override {
  dotnet-sdk = null;
  cargo = null;
  git = null;
  go = null;
  nodejs = null;
})
.overrideAttrs (_old: {
  checkInputs = [];
  doCheck = false;
  doInstallCheck = false;
  pythonImportCheck = [];
})
