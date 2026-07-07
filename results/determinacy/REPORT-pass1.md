# Determinacy report -- deepswe-v1.1

Cases with >=1 graded behavior: **111**.  Graded behaviors total: **3513**.

| tier | what it measures | rate | trust |
|---|---|---|---|
| 0 screen (coverage, case-level) | >=1 prose-silent behavior | 38/111 = 34.2% | loose upper bound |
| 1 coverage (behavior-level) | prose-silent graded behaviors (grep-verified) | 100/3513 = 2.8% | upper bound (over-flags) |
| 2a airtight | constant absent from prose+codebase (clone+grep) | 3/111 = 2.7% | claimable |
| 2b codebase-plural | >=2 conflicting live precedents, comparability-survived | 2/111 = 1.8% | claimable |
| **claimable spine (2a + 2b)** | pointer-checkable, refutation-hardened | **5/111 = 4.5%** (Wilson95 1.9-10.1) | **the claim** |
| hypotheses | prose-affirmative + cherry-picks + unwitnessed | 33 | not claimed |

Tiers 0-1 over-flag (parametrized behaviors, convention-resolved silence) and are disclosed as upper bounds. Only the spine survives a hostile reader; it is a lower bound (a single pass under-counts). See `CLAIMS.md`.

