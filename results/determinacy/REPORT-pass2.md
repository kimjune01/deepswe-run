# Determinacy report -- deepswe-v1.1

Cases with >=1 graded behavior: **111**.  Graded behaviors total: **3441**.

| tier | what it measures | rate | trust |
|---|---|---|---|
| 0 screen (coverage, case-level) | >=1 prose-silent behavior | 29/111 = 26.1% | loose upper bound |
| 1 coverage (behavior-level) | prose-silent graded behaviors (grep-verified) | 75/3441 = 2.2% | upper bound (over-flags) |
| 2a airtight | constant absent from prose+codebase (clone+grep) | 0/111 = 0.0% | claimable |
| 2b codebase-plural | >=2 conflicting live precedents, comparability-survived | 0/111 = 0.0% | claimable |
| **claimable spine (2a + 2b)** | pointer-checkable, refutation-hardened | **0/111 = 0.0%** (Wilson95 0.0-3.3) | **the claim** |
| hypotheses | prose-affirmative + cherry-picks + unwitnessed | 29 | not claimed |

Tiers 0-1 over-flag (parametrized behaviors, convention-resolved silence) and are disclosed as upper bounds. Only the spine survives a hostile reader; it is a lower bound (a single pass under-counts). See `CLAIMS.md`.

