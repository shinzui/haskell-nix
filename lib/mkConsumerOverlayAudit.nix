{ lib, registries, haskellExtensions, defaultGhc }:
let
  report = import ./consumerOverlayReport.nix { inherit lib; };
  consumerOverlayReport =
    { pkgs
    , overlay
    , ownPackages
    , siblingPackages ? [ ]
    , exceptions ? { }
    , registry ? registries.github
    , ghc ? defaultGhc
    , generatedPackages ? [ ]
    , frozenPackages ? [ ]
    , sourcePackages ? [ ]
    , runtimePackages ? [ ]
    }:
    let
      scope = pkgs.haskell.packages.${ghc}.override {
        overrides = haskellExtensions.github pkgs.haskell.lib.compose pkgs;
      };
    in
    report {
      channelPackages = builtins.attrNames registry;
      overlayPackages = builtins.attrNames (overlay scope scope);
      inherit ownPackages siblingPackages exceptions generatedPackages frozenPackages sourcePackages runtimePackages;
    };
  auditConsumerOverlay = args:
    let
      result = consumerOverlayReport args;
      line = names: label: lib.optionalString (names != [ ])
        "\n  ${label}: ${lib.concatStringsSep ", " names}";
      message = "consumer overlay audit failed:"
        + line result.shadowing "shadows channel packages (delete them; the channel owns them)"
        + line result.undeclared "defines undeclared packages (declare as own/sibling/exception or move to the channel)"
        + line result.unusedDeclarations "declares packages the overlay does not define"
        + line result.invalidDeclarations "has duplicate declarations or exceptions without a non-empty reason";
    in
    if result.ok then
      args.pkgs.runCommand "consumer-overlay-audit"
        { passthru.results = result; } "touch $out"
    else throw message;
in
{ inherit consumerOverlayReport auditConsumerOverlay; }
