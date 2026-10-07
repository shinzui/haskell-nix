# Preserved in-progress MP-3 pins

These patches preserve the three agent-owned dependency pin edits removed at the requested clean stopping checkpoint. Each passed `git apply --check` against its owning repository. They are unfinished candidates: legacy helper bounds still block full ephemeral-pg 0.3 adoption.

Owners: `mori://shinzui/keiei`, `mori://shinzui/kizashi`, `mori://shinzui/meibo`. Apply the corresponding patch in that repository when resuming plan 17; resolve the recorded helper compatibility blockers before claiming acceptance. No candidate work was omitted from these three one-line diffs.
