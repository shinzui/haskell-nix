[User guide](README.md)

# Updating first-party packages

First-party state is split between hand-authored family/update-group policy in
`config/first-party-families.json`, generated immutable snapshots and package-set selections
in `packages/first-party-lock.json`, and the current tracking inputs in `flake.lock`.
`haskell-nix-update` is the only production writer for the generated lock.

Nix reads only checked-in metadata. Hackage archives need no discovery request during
evaluation. A selected GitHub snapshot uses a locked, content-addressed `fetchTree` and may
be downloaded when its store path is absent; unselected historical snapshots remain lazy.
Mori checkout discovery, remote-head observation, and Hackage release discovery happen only
in updater commands.

## Prerequisites

Run the updater from the repository root. Every `moriProject` must be registered and point
to a usable local Git checkout:

```bash
mori registry show OWNER/PROJECT --full
```

Online refresh/check paths also need GitHub, Hackage, and configured Nix substituters. A
mutating command requires committed `flake.lock` and `packages/first-party-lock.json`;
unrelated working-tree changes are allowed.

## Catalog and generated snapshots

The schema-version-2 catalog declares sorted families and any cross-family atomic groups:

```json
{
  "schemaVersion": 2,
  "families": [
    {
      "name": "example",
      "moriProject": "owner/example",
      "github": "owner/example",
      "githubInput": "example-src",
      "packageOverrides": {},
      "excludedPackages": []
    }
  ],
  "updateGroups": [
    {
      "name": "shikumi-baikai",
      "families": ["baikai", "shikumi"]
    }
  ]
}
```

Families omitted from `updateGroups` become implicit singleton groups. Selecting either
Baikai or Shikumi resolves to `shikumi-baikai` and refreshes both. All packages discovered
in one family repository share its source revision.

`packageOverrides` maps package names to `cabal2nixOptions`. `excludedPackages` removes
discovered examples or fixtures; exclusions must still match discovery, cannot overlap an
override, and never appear in either channel. These discovery rules are copied into each
family snapshot, so future policy changes do not reinterpret retained generations.

The generated lock contains:

- immutable `familySnapshots` with locked GitHub descriptors, discovery policy, package
  paths/versions, and Hackage pins;
- immutable `groupSnapshots` that atomically select family generations plus one immutable
  compatibility-profile name;
- complete named `packageSets` with `curated` or `historical` support; and
- `defaultPackageSet`, the curated selection behind the legacy aliases.

Snapshots are append-only. Do not edit generations or mappings by hand. Schema version 2
fixes the family inventory and update-group topology; adding/removing a family or regrouping
families requires a separately designed migration.

## Inspect current selections

```bash
jq '{
  defaultPackageSet,
  sets: [.packageSets[] | {name, supportLevel, groups}],
  familySnapshotCount: (.familySnapshots | length),
  groupSnapshotCount: (.groupSnapshots | length)
}' packages/first-party-lock.json

nix eval --json .#lib.firstPartyPackageSets
nix eval --json .#lib.firstPartyGroupSnapshots
```

The Nix discovery outputs contain metadata only and do not fetch selected trees.

## Refresh one curated set

Preview all groups selected by the default set, apply the refresh, then check drift:

```bash
nix run .#haskell-nix-update -- refresh --dry-run
nix run .#haskell-nix-update -- refresh
nix run .#haskell-nix-update -- check --online
```

Use `--package-set SET` to target another curated set. A successful refresh appends new
family/group generations for observed changes and moves only that set's selections. Other
named sets keep their existing generations.

Limit work by group or by a family that resolves to its group:

```bash
nix run .#haskell-nix-update -- refresh \
  --package-set default --group okf --dry-run
nix run .#haskell-nix-update -- refresh \
  --package-set default --family baikai
```

The second command refreshes the complete `shikumi-baikai` group. Repeat `--group` or
`--family` for distinct groups. Unknown and duplicate targets are rejected. A historical
set cannot be refreshed; clone or relabel a deliberately validated selection instead.

Use `--compatibility-profile PROFILE` only for a refresh that targets one resolved group.
Without it, the new group snapshot inherits that group's selected profile. Define changed
profile contents under a new immutable name in `overlays/compatibility-profiles.nix` first.

`refresh --dry-run` observes remote heads and Hackage state without writing. A normal
refresh updates only changed tracking inputs, atomically writes the generated lock, validates
the selected set under both channels, and runs flake validation. Any failure restores both
managed lock files byte-for-byte. The command never commits or pushes.

`check` is network-free: it validates the graph, locates each selected source through Mori,
requires the Git object locally, and verifies package discovery against the selected
snapshot's own policy. `check --online` additionally compares remote heads and Hackage state.

## Compose and promote named sets

Package-set commands mutate only the generated lock. Preview any command with `--dry-run`.
Commit each successful mutation before starting the next one so the dirty-file guard keeps
every transaction recoverable.

Clone a complete selection as historical by default:

```bash
nix run .#haskell-nix-update -- package-set clone \
  --from SOURCE --to CANDIDATE
```

Move exactly one group either to a retained generation or to another set's selection:

```bash
nix run .#haskell-nix-update -- package-set select \
  --package-set CANDIDATE --group okf --from-package-set default

nix run .#haskell-nix-update -- package-set select \
  --package-set CANDIDATE --group okf --generation 1
```

Assign a retained compatibility profile by creating a new group snapshot for that set:

```bash
nix run .#haskell-nix-update -- package-set profile \
  --package-set CANDIDATE --group keiro --profile PROFILE
```

After the complete supported system/channel/GHC build matrix passes, promote the candidate:

```bash
nix run .#haskell-nix-update -- package-set support \
  --package-set CANDIDATE --support-level curated
```

Never mark a set curated before its matrix passes. Historical means retained and selectable,
not continuously supported on future Nixpkgs or compiler versions.

## Migration and historical import

`migrate-lock` is the one-time schema-1-to-schema-2 workflow. Build the migration-capable
updater before creating any temporary catalog/lock schema mismatch, then run:

```bash
haskell-nix-update migrate-lock \
  --package-set default \
  --import-set NAME=GIT_COMMIT
```

The current flat lock becomes curated `default`; every `--import-set` reads that repository
commit's flat package lock and matching `flake.lock`, imports immutable snapshots, and adds a
historical named set. Import is verified and deduplicated; do not reconstruct old NAR hashes
or snapshot records manually.

## Verification and build matrix

Run the fast contracts before expensive builds:

```bash
nix run .#haskell-nix-update -- check --package-set default
just nix-test
just fmt-check
nix flake check --no-build
```

The flake generates full inventory builds only for sets labelled `curated`. For each curated
set it realizes every available selected package and the consumer fixture under GitHub and
Hackage with every `lib.supportedGhcs` compiler. Hackage deliberately omits null pins.

Run the complete check on each supported system, using its native or configured remote
builder; one host's check does not prove another system:

```bash
nix flake check --print-build-logs --keep-going
```

The focused production identity result is inspectable separately:

```bash
nix eval --json \
  .#checks.aarch64-darwin.production-package-set-cache-identity.results
```

Use the applicable system key. It must show every Keiro comparison equal and each OKF
comparison different for both channels and supported compilers.

## Review checklist

Before committing a refresh or package-set mutation:

1. Confirm `flake.lock` changed only intended tracking inputs; package-set composition
   commands normally leave it unchanged.
2. Review appended family sources, discovery policies, package versions/paths, Hackage
   hashes/nulls, group profiles, and the one intended set-selection move.
3. Confirm existing generations and non-target package sets are byte-for-byte equivalent in
   meaning; the updater keeps generated lists sorted and references complete.
4. Run the same command with `--dry-run` again; a refresh should report no new drift.
5. Run offline/online checks as appropriate, format/unit checks, and the curated matrix on
   every supported system.
6. Update [Channel reference](channels.md) if the default set's package membership or
   publication status changed.

## Validate from a downstream consumer

Test an unpushed checkout without changing the consumer lock:

```bash
nix build --override-input haskell-nix path:/path/to/local/haskell-nix
nix develop --override-input haskell-nix path:/path/to/local/haskell-nix
```

Exercise the consumer's chosen package set under each channel it supports. The override
changes only where this flake is loaded; package-set and channel choices remain explicit in
the consumer's `flake.nix`.

See [Troubleshooting](troubleshooting.md) for dirty managed files, missing generations,
incomplete mappings, support expectations, profile conflicts, and cache diagnostics.
