# Independent prototype only. Production helper activation remains gated by the
# native toolchain capability contract in mori://shinzui/haskell-nix-dev.
{ pkgs, scope }:
let
  hlib = pkgs.haskell.lib.compose;
  ownedExtension = final: _: {
    project-shell-dependency = final.callPackage
      ({ mkDerivation, base }: mkDerivation {
        pname = "project-shell-dependency";
        version = "1.0";
        src = ./fixtures/project-shell/dependency;
        libraryHaskellDepends = [ base ];
        doCheck = false;
        doHaddock = false;
        license = pkgs.lib.licenses.bsd3;
      })
      { };
    project-shell-app = final.callPackage
      ({ mkDerivation, base, project-shell-dependency }: mkDerivation {
        pname = "project-shell-app";
        version = "1.0";
        src = ./fixtures/project-shell/application;
        isLibrary = false;
        isExecutable = true;
        executableHaskellDepends = [ base project-shell-dependency ];
        executablePkgconfigDepends = [ pkgs.zlib ];
        doCheck = false;
        doHaddock = false;
        license = pkgs.lib.licenses.bsd3;
      })
      { };
  };
  selected = scope.override { overrides = ownedExtension; };
  # A visibly wrong instance makes a second package universe observable.
  wrong = scope.override {
    overrides = pkgs.lib.composeExtensions ownedExtension (final: previous: {
      project-shell-dependency = hlib.overrideCabal
        (_: {
          version = "2.0";
          postPatch = ''
            substituteInPlace project-shell-dependency.cabal --replace-fail 'version: 1.0' 'version: 2.0'
            substituteInPlace src/ProjectShell/Dependency.hs --replace-fail 'answer = 42' 'answer = 9000'
          '';
        })
        previous.project-shell-dependency;
    });
  };
  environment = selected.shellFor {
    packages = packages: [ packages.project-shell-app ];
    withHoogle = false;
    shellHook = ''printf 'scope\n' >> "$PWD/hooks"'';
  };
  inherited = pkgs.mkShell {
    nativeBuildInputs = [ pkgs.jq ];
    buildInputs = [ pkgs.zlib ];
    propagatedNativeBuildInputs = [ pkgs.which ];
    propagatedBuildInputs = [ pkgs.libffi ];
    shellHook = ''printf 'inherited\n' >> "$PWD/hooks"'';
  };
  shell = pkgs.mkShell {
    # inputsFrom merges dependency lists and hooks, not arbitrary environment
    # variables. Preserve the scoped compiler settings and Linux locale archive.
    env = pkgs.lib.filterAttrs
      (name: _: pkgs.lib.hasPrefix "NIX_GHC" name || name == "LOCALE_ARCHIVE")
      environment;
    inputsFrom = [ environment inherited ];
    nativeBuildInputs = [ pkgs.cabal-install pkgs.pkg-config ];
    buildInputs = [ pkgs.zlib ];
    shellHook = ''
      export LANG=en_US.UTF-8
      printf 'caller\n' >> "$PWD/hooks"
    '';
  };
  changedShell = pkgs.mkShell {
    inputsFrom = [ shell ];
    nativeBuildInputs = [ pkgs.hello ];
  };
  check = pkgs.runCommand "project-shell"
    {
      inherit (shell) nativeBuildInputs buildInputs propagatedNativeBuildInputs propagatedBuildInputs;
      env = pkgs.lib.filterAttrs
        (name: _: pkgs.lib.hasPrefix "NIX_GHC" name || name == "LOCALE_ARCHIVE")
        shell;
      nativeCheck = selected.project-shell-app;
      wrongCompiler = wrong.ghcWithPackages (packages: [ packages.project-shell-dependency ]);
    }
    ''
      export HOME="$TMPDIR/home"
      mkdir -p "$HOME" work
      cd work
      ${shell.shellHook}
      test "$(sort hooks | uniq -c | awk '{print $1}' | sort -u)" = 1
      test "$(wc -l < hooks | tr -d ' ')" = 3
      jq --version
      which ghc
      ghc --numeric-version | tee compiler-version
      test "$NIX_GHC" = '${environment.NIX_GHC}'
      ghc --print-libdir | tee compiler-libdir
      test "$(cat compiler-version)" = '${scope.ghc.version}'
      ghc-pkg field project-shell-dependency version | grep -F 'version: 1.0'
      pkg-config --exists zlib libffi
      cp ${./fixtures/project-shell/application/Main.hs} Main.hs
      ghc -package project-shell-dependency Main.hs $(pkg-config --libs zlib) -o direct
      ./direct | grep -E '^42:[0-9]'
      "$nativeCheck/bin/project-shell-app" | grep -E '^42:[0-9]'
      "$wrongCompiler/bin/ghc" -fforce-recomp -package project-shell-dependency Main.hs $(pkg-config --libs zlib) -o wrong
      if ./wrong | grep -E '^42:'; then
        echo 'wrong-scope fixture was incorrectly accepted' >&2
        exit 1
      fi
      ./wrong | grep -E '^9000:[0-9]'
      cp ${./fixtures/project-shell/application/project-shell-app.cabal} project-shell-app.cabal
      cat > cabal.project <<'CABAL'
      packages: .
      active-repositories: :none
      constraints: project-shell-dependency == 1.0
      write-ghc-environment-files: never
      CABAL
      cabal v2-build all --offline
      cabal v2-run project-shell-app --offline | grep -E '^42:[0-9]'
      mkdir "$out"
      cp compiler-version compiler-libdir hooks "$out/"
      cp dist-newstyle/cache/plan.json "$out/plan.json"
    '';
in
assert shell.drvPath != changedShell.drvPath;
assert builtins.any (input: input.drvPath == pkgs.jq.drvPath) shell.nativeBuildInputs;
assert builtins.any (input: input.drvPath == pkgs.zlib.drvPath) shell.buildInputs;
assert builtins.any (input: input.drvPath == pkgs.which.drvPath) shell.propagatedNativeBuildInputs;
assert builtins.any (input: input.drvPath == pkgs.libffi.drvPath) shell.propagatedBuildInputs;
assert builtins.all (input: input.drvPath != scope.ghc.drvPath) shell.nativeBuildInputs;
{
  inherit selected environment shell changedShell check;
  identity = {
    compiler = selected.ghc.drvPath;
    dependency = selected.project-shell-dependency.drvPath;
    production = selected.project-shell-app.drvPath;
    shell = shell.drvPath;
    changedShell = changedShell.drvPath;
  };
}
