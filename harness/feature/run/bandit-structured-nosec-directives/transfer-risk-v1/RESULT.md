# Transfer-risk measurement #1 — H₉ overlap on Flash + Composer

**Date:** 2026-05-29
**Substrate:** bandit-structured-nosec-directives (compositional, dense PRD)
**Artifact under review:** `flash-test_proxy.py` (34 tests, gemini-3.5-flash via `--approval-mode plan`)
**Reviewers:** codex `gpt-5.5` + Composer 2.5 (`-p -f --model composer-2.5`)
**Protocol:** Phase 4 three-ask (soundness / discrimination / missing coverage), identical prompt to both

## Headline

**Substantive overlap = 11 / 29 = 37.9%.** Below the 70% threshold. **H₉ stands.**

Codex catches 1 real PRD-soundness bug Composer misses (next-line directive leaking into following statement). Composer surfaces 14 unique missing-coverage gaps codex misses (mostly interaction/combination scenarios). On the 11 shared topics they agree on *which test is suspect* but often disagree on *what kind of suspect* (soundness vs discrimination). Lenses are complementary.

## Cost

- Flash author: ~3 min wall, free tier
- codex review: ~30 s wall, ~$0.02 (12.5k tokens)
- Composer review: ~90 s wall, ~$0.05
- Total: **~$0.07**, ~6 min wall

## Decision

Keep the Phase 4 cross-family review in the scaffold as currently specced. The new pair preserves the complementarity property the protocol was built on.

## Follow-ups (priority order)

1. **n=2 on a breadth-dominant additive task (kysely or happy-dom)** before freeze. One more artifact at a different feature class hardens the result. ~$0.10, ~10 min.
2. **Open question already flagged in HG:** Hₐ₈/Hₐ₉ argue the adversary fires *too late* (Phase 4 = post-impl). The bandit grade-red was traceable to proxy-author misses, not implementer misses. Should the adversary fire at *Phase 2-bis* (proxy-author time) too? This measurement doesn't settle it — both reviewers were reviewing a post-author artifact. A separate measurement would dispatch Composer-as-adversary at proxy-author time and check whether it caches the Hₐ₈-shape catches earlier.

## Files

- `flash-author-prompt.md` — prompt sent to Flash
- `flash-test_proxy.py` — Flash's output (the artifact under review)
- `review-prompt-filled.md` — identical prompt sent to both reviewers
- `codex-review-raw.txt` — 44 findings (F1–F44)
- `composer-review-raw.txt` — 61 findings (F1–F61)
- `PAIRING.md` — the topic-by-topic pairing and bracket analysis
- `RESULT.md` — this file
