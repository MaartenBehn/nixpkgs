{
  lib,
  stdenv,
  fetchFromGitHub,
  nodejs,
  pnpm,
  pnpmConfigHook,
  fetchPnpmDeps,
  jq
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "scramjet";
  version = "2.0.67-alpha.2";

  src = fetchFromGitHub {
    owner = "MercuryWorkshop";
    repo = "scramjet";
    rev = "v${finalAttrs.version}";
    fetchSubmodules = true;
    hash = "sha256-oZeFxhoTfv5fj2IcWO/AG4UdrVroJXjWacflhF0ytdo=";

    postFetch = ''
      cd $out
      ${jq}/bin/jq 'del(.pnpm)' package.json > package.json.tmp && mv package.json.tmp package.json
    '';
  };

  nativeBuildInputs = [
    nodejs
    pnpm
    pnpmConfigHook
  ];

  pnpmDeps = fetchPnpmDeps {
    pname = finalAttrs.pname;
    version = finalAttrs.version;
    src = finalAttrs.src;
    fetcherVersion = 4;
    hash = "sha256-Psbbx0IgaLv42bhxJcwbSXkCzbL3SM/kFd686XkbdqM=";
  };

  postPatch = ''
    substituteInPlace packages/core/rewriter/wasm/build.sh \
      --replace-fail 'WBG="wasm-bindgen 0.2.105"' 'WBG="$(wasm-bindgen -V)"'
  '';

  buildPhase = ''
    runHook preBuild

    pnpm --filter ./packages/core rewriter:build
    pnpm --filter ./packages/core build

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/lib/scramjet
    cp -r . $out/lib/scramjet

    runHook postInstall
  '';

  meta = {
    description = "Tool to query HTML files with CSS selectors";
    mainProgram = "scramjet";
    homepage = "https://github.com/MercuryWorkshop/scramjet/";
    changelog = "https://github.com/MercuryWorkshop/scramjet/releases/tag/v${finalAttrs.version}";
    maintainers = with lib.maintainers; [
      maartenbehn
    ];
  };
})
