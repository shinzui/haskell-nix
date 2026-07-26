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

# Report which FAMILIES (default: all) need updates, tagged git-commit vs. hackage-release.
status *families:
    #!/usr/bin/env bash
    set -o pipefail
    names=({{families}})
    if [ ${#names[@]} -eq 0 ]; then
        while IFS= read -r name; do
            names+=("$name")
        done < <(jq -r '.families[].name' config/first-party-families.json)
    fi
    colour=0
    if [ -t 1 ]; then colour=1; fi
    stream=$(mktemp)
    errors=$(mktemp)
    trap 'rm -f "$stream" "$errors"' EXIT
    # One dry run per family: a transient GitHub or Hackage failure then costs a single
    # row instead of aborting the whole survey, as an all-family dry run would. Those
    # failures are common enough to retry once before reporting the family as failed.
    for name in "${names[@]}"; do
        printf 'surveying %s...\n' "$name" >&2
        printf '@family %s\n' "$name" >>"$stream"
        for attempt in 1 2; do
            if output=$({{cli}} refresh --family "$name" --dry-run 2>"$errors"); then
                printf '%s\n' "$output" >>"$stream"
                break
            fi
            if [ "$attempt" = 2 ]; then
                # Skip Nix's own chatter so the reported line is the updater's error.
                reason=$(grep -v -e '^warning:' -e '^evaluating' "$errors" | head -n 1 | cut -c 1-140)
                printf '@error %s %s\n' "$name" "${reason:-dry run failed; rerun just preview $name}" >>"$stream"
            fi
        done
    done
    awk -v color="$colour" -f scripts/family-status.awk "$stream"

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
