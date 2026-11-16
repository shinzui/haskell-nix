# Exercise the shipped inspection executables without opening database connections.
{ pkgs, scope, channel, includeKioku ? true }:
pkgs.runCommand "runtime-inspection-${channel}"
{
  nativeBuildInputs = [ scope.keiro-ops-http scope.pgmq-inspect ];
  # Retain the older generation's mori://shinzui/kioku consumer qualification.
  # Generations 8 and 9 exclude it: its released bounds require an older Keiro runtime.
  buildInputs = [ scope.shibuya-metrics scope.settei-preflight ]
    ++ pkgs.lib.optionals includeKioku [ scope.kioku-core scope.kioku-migrations ];
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
