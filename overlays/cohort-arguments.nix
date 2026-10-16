# Arguments needed to construct recipes whose third-party tests are disabled.
# Keep these lazy failures rather than null: an active component must never
# silently accept a missing dependency. Versions and sources stay generated.
{ pkgs }:
{
  # The pkg-config input is the native library, not the Haskell fixed point.
  zlib = { zlib = pkgs.zlib; };
  hasql-dynamic-statements = {
    # Hackage 0.5.1.2 declares these exclusively in test-suite test.
    pqi-native = throw "hasql-dynamic-statements: pqi-native is available only to disabled upstream tests";
    testcontainers-postgresql = throw "hasql-dynamic-statements: testcontainers-postgresql is available only to disabled upstream tests";
  };
  hasql-transaction = {
    # Hackage 1.2.3.1 declares these exclusively in test-suite test.
    pqi = throw "hasql-transaction: pqi is available only to disabled upstream tests";
    pqi-ffi = throw "hasql-transaction: pqi-ffi is available only to disabled upstream tests";
    pqi-native = throw "hasql-transaction: pqi-native is available only to disabled upstream tests";
    testcontainers-postgresql = throw "hasql-transaction: testcontainers-postgresql is available only to disabled upstream tests";
  };
}
