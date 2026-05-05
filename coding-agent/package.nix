{
  lib,
  stdenv,
  buildNpmPackage,
  makeWrapper,
  nodejs,
  typescript,
  typescript-go,
  pkg-config,
  pixman,
  cairo,
  pango,
  libpng,
  libjpeg,
  giflib,
  librsvg,
  fd,
  src,
  version,
  npmDepsHash,
}:
buildNpmPackage {
  pname = "pi-coding-agent";
  inherit src version npmDepsHash;

  nativeBuildInputs = [
    makeWrapper
    pkg-config
    typescript
    typescript-go
  ];

  buildInputs = [
    pixman
    cairo
    pango
    libpng
    libjpeg
    giflib
    librsvg
    fd
  ];

  preBuild = ''
    find packages -name "package.json" -exec sed -i \
      -e 's/--watch --preserveWatchOutput//g' \
      {} \;

    for f in packages/ai/src/models.ts packages/agent/src/agent.ts packages/tui/src/utils.ts; do
      [ -f "$f" ] && echo '// @ts-nocheck' | cat - "$f" > tmp && mv tmp "$f"
    done

    substituteInPlace packages/coding-agent/src/modes/interactive/interactive-mode.ts \
      --replace-fail '		const action = theme.fg("accent", `''${APP_NAME} update`);
    const updateInstruction = theme.fg("muted", `New version ''${newVersion} is available. Run `) + action;' \
                     '		const action = theme.fg("accent", `https://github.com/lukasl-dev/pi-mono.nix/releases/tag/v''${newVersion}`);
    const updateInstruction = theme.fg("muted", `New version ''${newVersion} is available. Run `) + action;' \
      --replace-fail '"https://github.com/badlogic/pi-mono/blob/main/packages/coding-agent/CHANGELOG.md"' \
                     '`https://github.com/badlogic/pi-mono/blob/v''${newVersion}/packages/coding-agent/CHANGELOG.md`'

    cp ${../models.generated.ts} packages/ai/src/models.generated.ts

    substituteInPlace packages/ai/package.json \
      --replace-fail 'npm run generate-models && ' '''
  '';

  buildPhase = ''
    runHook preBuild
    npm run build --workspace=packages/tui --workspace=packages/ai --workspace=packages/agent --workspace=packages/coding-agent
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p $out/bin $out/lib/node_modules/@mariozechner

    for pkg in tui ai agent coding-agent mom pods; do
      [ -d "packages/$pkg/dist" ] || continue
      mkdir -p "$out/lib/node_modules/@mariozechner/pi-$pkg"
      cp -r packages/$pkg/dist/* "$out/lib/node_modules/@mariozechner/pi-$pkg/"
      cp packages/$pkg/package.json "$out/lib/node_modules/@mariozechner/pi-$pkg/"
    done

    cp -rL node_modules/. "$out/lib/node_modules/"

    makeWrapper ${nodejs}/bin/node $out/bin/pi \
      --add-flags "$out/lib/node_modules/@mariozechner/pi-coding-agent/dist/cli.js" \
      --set PI_PACKAGE_DIR "$out/lib/node_modules/@mariozechner/pi-coding-agent" \
      --prefix NODE_PATH : "$out/lib/node_modules" \
      --prefix PATH : "${fd}/bin"
    runHook postInstall
  '';

  meta = {
    description = "Pi - a minimal terminal coding harness";
    homepage = "https://github.com/badlogic/pi-mono";
    license = lib.licenses.mit;
    mainProgram = "pi";
    maintainers = [];
  };
}
