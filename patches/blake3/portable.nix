# blake3 0.3.1 vendors SIMD C/asm. nixpkgs restricts its meta.platforms to x86
# (the SIMD fast path) and excludes aarch64-darwin, where the non-x86 fallback
# still compiles x86 intrinsics (mmintrin.h) under clang and fails to build.
#
# Disable the SIMD cabal flags so only the portable pure-C path is built, force
# the portable path on ARM (the package never compiles blake3_neon.c yet
# blake3_dispatch.c references blake3_hash_many_neon), and widen meta.platforms
# so the portable build is allowed on aarch64-darwin. The portable hash is
# byte-identical to the SIMD path, so shikumi-cache's content-addressed keys are
# unaffected. Mirrors shikumi's cabal.project blake3 workaround for the nix build.
{ pkg, lib, haskellLib, ... }:
let
  noSimd =
    haskellLib.disableCabalFlag "sse2" (
      haskellLib.disableCabalFlag "sse41" (
        haskellLib.disableCabalFlag "avx2" (
          haskellLib.disableCabalFlag "avx512" pkg)));
in
haskellLib.overrideCabal
  (drv: {
    configureFlags = (drv.configureFlags or [ ]) ++ [
      "--ghc-options=-optc-DBLAKE3_USE_NEON=0"
    ];
    platforms = lib.platforms.all;
  })
  (haskellLib.dontCheck noSimd)
