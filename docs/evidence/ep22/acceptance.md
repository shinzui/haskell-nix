# EP-22 acceptance evidence

2026-10-27. Implementation is in progress; production catalog activation and final native
matrix acceptance remain pending.

The explicit migration and retained nested discovery policy pass 234 offline updater tests
and 368 pure Nix contracts, including the retained-constructor projection and preservation
of shared tracking-input nodes. Milestone 1 is committed as `b1c7657`.

The proposed support check passes on aarch64-darwin for GHC 9.12.4 and 9.14.1 through both
GitHub and Hackage sources. It builds all four Heni packages, Hinagata core/postgres/CLI,
typesafe-hs, and the GitHub-only Shoko core/adapters/CLI. A linked threaded Shoko consumer
executes help and calls the native librdkafka version function, returning 2.15.0.

Heni uses the existing first-party bounds-relaxed policy with Aeson 2.2.5.1 and Crypton
1.1.5. Validation runs upstream heni-unit, heni-runner, and heni-adapter suites, the complete
CLI suite, and both framework-adapter suites. Other root Heni suites and live integrations
are not claimed. Direct consumers reject duplicate and escaped-equivalent JSON keys and
link both adapters. Packaged CLI mutations yield caught/exit 0 and survived/exit 1, preserve
the original source, and resolve installed fixture data through package metadata. The
TypeSafe request codec round-trips without service calls; Hinagata CLI help and empty
identifier rejection pass. No Heni source adaptation is applied.

The native pilot exposed an unselected hspec-api 2.11.17 versus frozen hspec-core 2.11.18
mismatch. The owned hspec-api recipe selects the matching released 2.11.18, without changing
the frozen cohort. rdkafka-hs 1.0.0.1 is pinned at its dereferenced release tag
45d9e21ad3c72b56c482173e17ca3fa2bd8b1bc7 with independently verified NAR hash
sha256-lno5sy1FDVLTzHeunuUmnbqNAMGGrFymWyJg/5KgwuM=. These two dependencies are separate
from the four first-party families and eight Hackage first-party releases.

The x86_64-linux checks are running in the existing translated Apple-container guest
`mp3-linux-builder`. Guest commands set `filter-syscalls = false` because seccomp filter
installation is unsupported there (FRIC-1); this is translated correctness evidence and
will not establish physical x86 performance. FRIC-2 records the Nix test-wrapper environment
that required a validation-only nested Cabal wrapper.

The real catalog preview succeeds and reports four generation-1 additions in each of the
three named sets. SHA-256 comparisons prove all three managed files are byte-identical
after the preview. The committed pre-migration baseline passes Darwin flake evaluation
(`nix flake check --no-write-lock-file --no-build --no-eval-cache`), formatting, and strict
documentation/friction validation.
