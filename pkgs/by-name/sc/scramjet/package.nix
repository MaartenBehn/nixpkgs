{
  lib,
  stdenv,
  fetchFromGitHub,
  fetchPnpmDeps,
  nodejs,
  pnpm,
  pnpmConfigHook,
  rustPlatform,
  fetchCrate,
  cargo,
  rustc,
  binaryen,
  which,
  llvmPackages,
  makeWrapper
}: let
  wasm-snip = rustPlatform.buildRustPackage {
    pname = "wasm-snip";
    version = "0.4.0";

    src = fetchFromGitHub {
      owner = "r58playz";
      repo = "wasm-snip";
      rev = "master";
      hash = "sha256-oU2R7rHgf+uMymSwLXEaHXW9Agkemi3WcUuMrTy32uk=";
    };

    cargoLock = {
      lockFile = ./wasm-snip-cargo.lock;
    };

    postPatch = ''
      cp ${./wasm-snip-cargo.lock} Cargo.lock
      '';

    cargoHash = "sha256-zcJ57hw1ZiAdIa4rhpbJq1vtlKgEtViTiiG2a57t/3w=";
    doCheck = false;
  };

  wasm-bindgen-cli = rustPlatform.buildRustPackage rec {
    pname = "wasm-bindgen-cli";
    version = "0.2.105";

    src = fetchCrate {
      inherit pname version;
      hash = "sha256-zLPFFgnqAWq5R2KkaTGAYqVQswfBEYm9x3OPjx8DJRY=";
    };

    cargoHash = "sha256-a2X9bzwnMWNt0fTf30qAiJ4noal/ET1jEtf5fBFj5OU=";
  };

in stdenv.mkDerivation (finalAttrs: {
  pname = "scramjet";
  version = "2.0.67-alpha.2";

  src = fetchFromGitHub {
    owner = "MercuryWorkshop";
    repo = "scramjet";
    rev = "v2.0.67-alpha.2";
    fetchSubmodules = true;
    hash = "sha256-oZeFxhoTfv5fj2IcWO/AG4UdrVroJXjWacflhF0ytdo=";
  };

  cargoDeps = rustPlatform.fetchCargoVendor {
    src = finalAttrs.src;
    sourceRoot = "source/packages/core/rewriter";
    hash = "sha256-dmd+eGf/y4kJsaLDBukF3jzhS7XDdx33JdSS0IAPjU0=";
  };

  cargoRoot = "packages/core/rewriter";

  postPatch = ''

    # Fixing pnpm
    cp ${./pnpm-lock.yaml} pnpm-lock.yaml
    cp ${./pnpm-workspace.yaml} pnpm-workspace.yaml
    cp ${./prodserver.ts} prodserver.ts

    # Removing nightly from build script
    substituteInPlace packages/core/rewriter/wasm/build.sh \
      --replace-fail 'cargo +nightly' 'cargo' \
      --replace-fail '-Z build-std=panic_abort,std' "" \
      --replace-fail '-Z build-std-features=''${STD_FEATURES}' "" \
      --replace-fail '-Zlocation-detail=none -Zfmt-debug=none' ""
  '';

  pnpmDeps = fetchPnpmDeps {
    pname = finalAttrs.pname;
    version = finalAttrs.version;
    src = finalAttrs.src;
    fetcherVersion = 4;

    postPatch = ''
      cp ${./pnpm-lock.yaml} pnpm-lock.yaml
      cp ${./pnpm-workspace.yaml} pnpm-workspace.yaml
    '';
    hash = "sha256-DxbCIhHyhRnDxfYQurCZtBZjHdQ4JI++VCttBOSN58g=";
  };

  nativeBuildInputs = [
    nodejs
    pnpm
    pnpmConfigHook
    rustPlatform.cargoSetupHook
    cargo
    rustc
    wasm-bindgen-cli
    binaryen         # Provides wasm-opt
    wasm-snip
    which
    llvmPackages.lld
    makeWrapper
  ];

  buildPhase = ''
    runHook preBuild

    export VITE_WISP_URL="ws://localhost:4142/"

    pnpm --filter ./packages/core rewriter:build
    pnpm --filter ./packages/core build
    pnpm --filter ./packages/demo build

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/lib/scramjet
    cp -r . $out/lib/scramjet

    makeWrapper ${nodejs}/bin/node $out/bin/scramjet \
      --add-flags "$out/lib/scramjet/prodserver.ts" \
      --run "cd $out/lib/scramjet"

    runHook postInstall
  '';

  meta = {
    description = "Scramjet is an experimental interception-based web proxy, designed to evade internet censorship and bypass arbitrary browser restrictions.";
    mainProgram = "scramjet";
    homepage = "https://github.com/MercuryWorkshop/scramjet/";
    changelog = "https://github.com/MercuryWorkshop/scramjet/releases/tag/v${finalAttrs.version}";
    maintainers = with lib.maintainers; [
      maartenbehn
    ];
  };
})
