# Native offline consumers in the existing frozen scope. Before activation the
# proposed registries supply only new names, after activation use selected ones.
{ lib
, pkgs
, supportedGhcs
, mkFirstPartyPackageSet
, mkFirstPartyRegistries
, proposedRegistries ? null
}:
let
  proposed = if proposedRegistries != null then proposedRegistries else
  import ./fixtures/new-first-party/proposed.nix { inherit lib mkFirstPartyRegistries; };
  source = ./fixtures/new-first-party/consumer;
  cabalForNestedTests = pkgs.writeShellScriptBin "cabal" ''
    # The Nix test wrapper exports GHC_PACKAGE_PATH, which nested Cabal rejects.
    # These upstream fixture builds need only the selected compiler's base.
    unset GHC_PACKAGE_PATH
    exec ${pkgs.cabal-install}/bin/cabal "$@"
  '';
  cell = channel: ghc:
    let
      selected = mkFirstPartyPackageSet { packageSet = "default"; inherit channel; };
      active = builtins.hasAttr "heni" selected.registry;
      proposedOverlay = (import ../lib/mkHaskellOverlay.nix { inherit lib; }) {
        registry = proposed.${channel};
        compilers = [ ghc ];
      };
      p = (pkgs.extend selected.overlay).extend (if active then (_: _: { }) else proposedOverlay);
      scope = p.haskell.packages.${ghc};
      hl = pkgs.haskell.lib.compose;
      # Hackage has no Shoko release; disable only that executable in this cell.
      consumer = hl.overrideCabal
        (old: {
          postPatch = (old.postPatch or "") + lib.optionalString (channel == "hackage") ''
            sed -i.bak '/^executable shoko-native-consumer/,$d' new-first-party-consumer.cabal
          '';
        })
        (scope.callCabal2nix "new-first-party-consumer" source {
          shoko-core = if channel == "github" then scope.shoko-core else null;
          shoko-cli = if channel == "github" then scope.shoko-cli else null;
          shoko-adapters = if channel == "github" then scope.shoko-adapters else null;
          rdkafka-hs = if channel == "github" then scope.rdkafka-hs else null;
        });
      checkedHeni = hl.overrideCabal
        (old: {
          doCheck = true;
          testTargets = [ "heni-unit" "heni-runner" "heni-adapter" ];
          testToolDepends = (old.testToolDepends or [ ]) ++ [ cabalForNestedTests pkgs.git ];
          preCheck = (old.preCheck or "") + ''
              export PATH="${cabalForNestedTests}/bin:$PWD/dist/build/heni-fixture:$PWD/dist/build/heni-evidence-fixture:$PATH"
            export CABAL_DIR="$TMPDIR/heni-cabal"
            export CABAL_CONFIG="$TMPDIR/heni-cabal.config"
              printf 'active-repositories: :none\nremote-repo-cache: %s\n' "$TMPDIR/cabal-cache" > "$CABAL_CONFIG"
          '';
        })
        scope.heni;
      checkedAdapter = name: hl.overrideCabal
        (old: {
          doCheck = true;
          preCheck = (old.preCheck or "") + ''
            export PATH="$PWD/dist/build/${name}-fixture:${scope.heni-cli}/bin:$PATH"
          '';
        })
        scope.${name};
      checkedCli = hl.overrideCabal
        (old: {
          doCheck = true;
          preCheck = (old.preCheck or "") + ''
            export PATH="$PWD/dist/build/heni:${scope.heni}/bin:$PATH"
          '';
        })
        scope.heni-cli;
      result = pkgs.runCommand "new-first-party-support-${channel}-${ghc}"
        {
          LC_ALL = if pkgs.stdenv.hostPlatform.isDarwin then "en_US.UTF-8" else "C.UTF-8";
          nativeBuildInputs = [ consumer scope.heni-cli scope.hinagata-cli pkgs.jq (scope.ghcWithPackages (p: [ p.heni ])) ];
          buildInputs = [ checkedHeni checkedCli (checkedAdapter "heni-hspec") (checkedAdapter "heni-tasty") ];
          passthru = { inherit consumer checkedHeni checkedCli scope; };
        } ''
        set -eu
        echo '${channel} ${ghc}: aeson ${scope.aeson.version}, crypton ${scope.crypton.version}'
        new-first-party-consumer
        hinagata --help > hinagata-help.txt
        heni --help > heni-help.txt
        ${lib.optionalString (channel == "github") ''
          shoko-native-consumer --help > shoko-help.txt
          grep 'librdkafka' shoko-help.txt
        ''}
        mkdir source
        printf 'anchor\n' > source/input
        cat > caught.json <<'JSON'
        {"schemaVersion":1,"sourceRoot":"source","commands":{"build":{"executable":"sh","arguments":["-c","exit 0"]},"test":{"executable":"sh","arguments":["-c","if grep -q mutant input; then echo 'capacity rule violated'; exit 1; fi"]}},"cases":[{"id":"caught","description":"Detect the intended fault","edits":[{"kind":"replace","path":"input","old":"anchor","new":"mutant"}],"build":"build","test":"test","expect":{"kind":"diagnostic","stage":"test","exitCode":1,"outputContains":"capacity rule violated"}}]}
        JSON
        heni run caught.json --output caught-output --json > caught-result.json
        jq -e '.result.cases[0].verdict == "caught"' caught-result.json
        jq '.cases[0].id="survived" | .cases[0].edits[0].new="harmless"' caught.json > survived.json
        set +e
        heni run survived.json --output survived-output --json > survived-result.json
        status=$?
        set -e
        test "$status" -eq 1
        jq -e '.result.cases[0].verdict == "survived"' survived-result.json
        test "$(cat source/input)" = anchor
        # Installed root data is part of the runtime contract, not only the sdist.
        fixtureData=$(ghc-pkg field heni data-dir --simple-output)
        test -f "$fixtureData/examples/minimal/src/Capacity.hs"
        mkdir "$out"
        cp *-result.json *-help.txt "$out/"
      '';
    in
    { inherit result channel ghc; };
  cells = lib.concatMap (ghc: map (channel: cell channel ghc) [ "github" "hackage" ]) supportedGhcs;
in
(pkgs.linkFarm "new-first-party-support" (lib.imap0
  (index: candidate: {
    name = toString index;
    path = candidate.result;
  })
  cells)).overrideAttrs (_: { passthru = { inherit cells; }; })
