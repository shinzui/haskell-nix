# EP-22 acceptance evidence

2026-10-27. The catalog migration activates Hinagata, Shoko, Heni, and typesafe-hs at
commit `334390b6913e740ebeeec25b6638aa97ae0a48b1`. All three named sets select seventeen
groups. Their original snapshots, selections, and support labels are preserved.
The four generation-1 snapshots provide eleven GitHub packages and eight Hackage packages;
Shoko's three packages remain absent from the Hackage registry. Exact revisions, paths,
versions, release hashes, dependency versions, and compiler/channel outputs are recorded in
[acceptance.json](acceptance.json).

The final new-family support check passes all eight system/compiler/channel cells:
`aarch64-darwin` and `x86_64-linux`, GHC 9.12.4 and 9.14.1, GitHub and Hackage.
Every available new package builds through the final named-set factory. Every new-family
and full curated version-mismatch array is empty. The full curated inventories contain
89 GitHub and 76 Hackage packages in each compiler cell.

Hinagata help and pure invalid-identifier rejection pass. A representative TypeSafe request
codec round-trips without credentials or service calls. Heni rejects duplicate and
escaped-equivalent JSON keys, and the consumer executes both public Hspec and Tasty adapter
entrypoints. Packaged CLI mutations yield `caught`/exit 0 and `survived`/exit 1 with the
expected result JSON, preserve original source bytes, and resolve installed fixture data
through package metadata. Validation executes upstream `heni-unit`, `heni-runner`, and
`heni-adapter`, the complete CLI suite, and both framework-adapter suites. Other root Heni
suites and live integrations are not claimed. A threaded Shoko executable linked to its
adapters and Kafka binding executes help and calls `librdkafkaVersion`, returning 2.15.0,
without a broker.

Heni uses the existing first-party bounds-relaxed policy with frozen Aeson 2.2.5.1 and
Crypton 1.1.5. This is build/behavior evidence rather than an upstream bounds-valid Cabal
solve. Production package tests remain disabled. No Heni source adaptation or cohort change
is applied. The separately owned hspec-api recipe uses upstream 2.11.18 release commit
`96242bf996b3eccc10cfe3406c16ffcb519b422d` to match frozen hspec-core 2.11.18; it follows
the registry's non-Hackage source policy. The separately owned rdkafka-hs 1.0.0.1 recipe uses
release commit `45d9e21ad3c72b56c482173e17ca3fa2bd8b1bc7`, independently verified hash
`sha256-lno5sy1FDVLTzHeunuUmnbqNAMGGrFymWyJg/5KgwuM=`, native librdkafka, and c2hs.
These are dependencies rather than additional first-party families or Hackage releases.

All 234 updater tests and 368 pure Nix contracts pass on both systems. Four-family offline and online checks
pass (the online check was retried after one transient Hackage `InvalidChunkHeaders` error).
Scoped refresh previews succeed for all four families. The real catalog preview preserves
all three managed files byte-for-byte; the accepted transaction validates every named set
and both channels. Replaying the accepted request reports `No catalog changes.`
Formatting, documentation, and strict friction validation pass.

Identity comparisons cover every old first-party package under both supported compilers
and channels (292 comparisons per system), and all 273 non-boot runtime-owned packages
under generations 1–5 and both channels (2,730 comparisons per system). Every derivation
matches the pre-implementation revision `3b726f9757bde6768b29c51fcf8295a2c178653f` exactly.
Deterministic compressed JSON maps are retained in
[preserved-identities-aarch64-darwin.json.gz](preserved-identities-aarch64-darwin.json.gz)
and [preserved-identities-x86_64-linux.json.gz](preserved-identities-x86_64-linux.json.gz);
the receipt records matching initial/final SHA-256 digests.

The user approved a narrow regression exception: unchanged `kioku-core` 0.11.0.0 panics
under GHC 9.14.1 in both channels with `coercionKind / ConsSymbolDef`, blocking its CLI,
migration executables, and the full curated aggregate. The failing derivations match the
pre-implementation recipes. They are preserved without source, flag, compiler, or cohort
changes. See [the diagnostic](kioku-ghc9141-panic.txt). This exception does not waive any
new-family build or behavior check.

Both final full flake checks pass 62 checks and fail only `package-set-default` through
that exception. The Linux result uses an immutable `git archive` of implementation commit
`5fa6635f98da0cecc0671d51b82084fde2b9e201`. It supersedes two changing-source evaluation
errors in an earlier mutable-workspace run. No source/configuration failures remain beyond
the explicitly accepted Kioku recipes and their dependents.

Darwin executes natively on Apple Silicon. Linux executes actual x86_64 binaries in the
existing translated Apple-container guest `mp3-linux-builder`, with the guest-only
`filter-syscalls = false` setting (FRIC-1). These are translated correctness results, not
physical x86 performance evidence. FRIC-2 documents the validation-only Cabal wrapper that
unsets the Nix test wrapper's `GHC_PACKAGE_PATH`. Both friction entries are triaged accepted.

To reproduce support, run the following in the repository root on each supported system:

```bash
nix build .#checks.aarch64-darwin.new-first-party-support --no-link --print-build-logs
nix build .#checks.aarch64-darwin.package-set-default --no-link --print-build-logs --keep-going
nix flake check --print-build-logs --keep-going
```

On Linux substitute `x86_64-linux`. The full curated/full flake commands retain the explicit
Kioku exception and return nonzero. The support command must succeed. Read-only
fact and identity queries are implemented in
[the facts helper](../../../checks/fixtures/new-first-party/facts.nix) and
[the identity helper](../../../checks/fixtures/new-first-party/identities.nix), each taking
an absolute flake `root` and `system`; identities additionally takes the original fourteen
family names as `oldFamilies`. Compare parsed JSON rather than relying on object order.
