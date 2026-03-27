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

  postPatch = ''
    find packages -name "package.json" -exec sed -i \
      -e 's/--watch --preserveWatchOutput//g' \
      {} \;

    sed -i tsconfig.base.json \
      -e 's/"target": "ES2022"/"target": "ES2024"/' \
      -e 's/"lib": \["ES2022"\]/"lib": ["ES2024"]/' \
      -e 's/"strict": true/"strict": false/' \
      -e 's/"useDefineForClassFields": false,/"useDefineForClassFields": false,\n\t\t"noEmitOnError": false,/';

    for f in packages/ai/src/models.ts packages/ai/src/providers/amazon-bedrock.ts packages/agent/src/agent.ts; do
      [ -f "$f" ] && echo '// @ts-nocheck' | cat - "$f" > tmp && mv tmp "$f"
    done
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
      --prefix NODE_PATH : "$out/lib/node_modules" \
      --prefix PATH : "${fd}/bin"
    runHook postInstall
  '';

  meta = {
    description = "Pi - a minimal terminal coding harness";
    homepage = "https://github.com/badlogic/pi-mono";
    license = lib.licenses.mit;
    mainProgram = "pi";
    maintainers = [ ];
  };
}
