# Recipes for the haskell-nix-update CLI and first-party channel maintenance.
# Run `just` with no arguments to list every recipe.

# Invocation of the flake's updater app.
cli := "nix run .#haskell-nix-update --"

# List available recipes.
default:
    @just --list

# List the configured first-party family names.
families:
    jq -r '.families[].name' config/first-party-families.json

# Preview a refresh for one FAMILY without writing managed files.
preview family:
    {{cli}} refresh --family {{family}} --dry-run

# Preview a refresh for every configured family without writing files.
preview-all:
    {{cli}} refresh --dry-run

# Refresh one FAMILY: bump GitHub HEAD + Hackage releases (needs clean flake.lock/package lock).
refresh family:
    {{cli}} refresh --family {{family}}

# Refresh every configured family.
refresh-all:
    {{cli}} refresh

# Offline drift check for one FAMILY (validates lock vs. flake.lock and Mori checkout).
check family:
    {{cli}} check --family {{family}}

# Online drift check for one FAMILY (also compares remote GitHub HEAD and Hackage state).
check-online family:
    {{cli}} check --family {{family}} --online

# Offline drift check for every configured family.
check-all:
    {{cli}} check

# Online drift check for every configured family.
check-online-all:
    {{cli}} check --online

# Validate both JSON contracts and evaluate the channel registries.
validate:
    jq empty config/first-party-families.json packages/first-party-lock.json
    nix eval --json .#lib.registries.hackage --apply builtins.attrNames
    nix eval --json .#lib.registries.github --apply builtins.attrNames

# Run the full flake check (schemas, versions, updater tests, overlay evaluation).
flake-check:
    nix flake check --print-build-logs
