# Frozen run inputs (audit-v1 → freeze)

Generated 2026-05-29 from `deep-swe @ 2f0f41255912c9199a1dafa405ca068cd903624b`.

## eligible.txt
113 tasks at the pin (per `git ls-tree -d --name-only 2f0f4125 tasks/`), minus 4 defectives
confirmed by audit-v1 oracle pass:

- langchain-request-coalescing
- narwhals-rolling-window-suite
- prometheus-transactional-reload-status
- skrub-duration-encoding

Final eligible: **109 tasks**. Lexicographic order in both eligible.txt and run_order.txt.

## What goes here next (FREEZE-CHECKLIST §II + §III)

- `HASHES.txt` — SHA256 of every prompt + skill file at freeze
- `VERSIONS.txt` — pinned CLI versions, model IDs, temperature, auth mode
- `COMPARISONS.txt` — primary-vs-best-baseline vs Bonferroni declaration (pre-data)
