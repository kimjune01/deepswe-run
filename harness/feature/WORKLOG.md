
## 2026-05-28 [partial-v1 fire #1] · H₆ FIRST GRADE-GREEN DATUM · kysely-window-grouping-helpers

**Bench plumbing top-to-bottom works.** Applied the gold patch
(`deep-swe/tasks/kysely-window-grouping-helpers/solution/solution.patch`) into the live container
(`dsr-kysely-window-grouping-helpers`), ran `dsr grade`:

- captured model.patch: **15 files, +827/-3** (matches the gold-patch shape)
- `test.sh base` (existing-suite regression check): **22 passing, 0 failing → pass**
- `test.sh new` (hidden feature gate, post-`test.patch`): **254 passing → pass**
- **REWARD 1**

This is the first grade-green measurement in the project. H₆ ("economy of search: gold substitutes
for implement-spec") was previously CONFIRMED only at the SOUND/LIVE proxy level — never actually
spent against the oracle. The hidden test.patch + test.sh path works as advertised.

**Cost:** $0 model spend (no LLM in the loop — pure plumbing test).

**What this confirms before we spend Composer/Flash tokens:**
1. `dsr grade` correctly reconstructs the model.patch from `git diff` in the container.
2. The hidden `test.patch` applies cleanly on top of the gold patch.
3. `test.sh base` + `test.sh new` is the exact gate the bench scores against (deep-swe convention).
4. The kysely container substrate is healthy after 21h uptime.

**Carry-forward for fire #2 (Composer impl):**
- Reset the container (`git restore .` to wipe gold) before dispatching cursor-agent.
- The captured-diff path works → Composer's diff will be graded identically.
- HG H₆ status updates from `operational, narrow validation 92%` to `operational + measured
  end-to-end, 95%`. First non-projection number in the graph.
