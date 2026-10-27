# Exercise the shipped inspection executables without opening database connections.
{ pkgs, scope, channel }:
pkgs.runCommand "runtime-inspection-${channel}"
{
  nativeBuildInputs = [ scope.keiro-ops-http scope.pgmq-inspect ];
  # Compile mori://shinzui/kioku consumers for the scoped bounds exceptions,
  # plus inspection packages from mori://shinzui/shibuya and mori://shinzui/settei.
  buildInputs = [ scope.kioku-core scope.kioku-migrations scope.shibuya-metrics scope.settei-preflight ];
} ''
  mkdir "$out"
  keiro-ops-http --help > "$out/keiro-ops-http-help.txt"
  grep -F -- '--enable-mutations' "$out/keiro-ops-http-help.txt"
  grep -F -- '--allow-origin' "$out/keiro-ops-http-help.txt"
  pgmq-inspect --help > "$out/pgmq-inspect-help.txt"
  grep -F -- '--no-listener' "$out/pgmq-inspect-help.txt"
  grep -F -- '--cors-origin' "$out/pgmq-inspect-help.txt"
  test "$(pgmq-inspect --version)" = '${scope.pgmq-inspect.version}'
''
