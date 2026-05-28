# Feature pipeline runbook (manual drive)

The pipeline: **design-doc → build-tools → implement-spec → verify-spec → `dsr gate`**, with
`dsr grade` consulted only afterward as the retrospective oracle. The agent iterates off a **spec-only
proxy**; the hidden grader is never read until after a run (PREREGISTRATION §9).

## Adapter handles (what the skills reference)

| handle | value | who reads it |
|---|---|---|
| box helper | `box-sh '<cmd>'`  (or `dsr box <id> -- '<cmd>'`) — runs in container at `/app` | all skills |
| `$DSR_TASK` | the task id, e.g. `httpx-streaming-json-iteration` | `box-sh` |
| `$PROXY_GATE_DIR` | `/tmp/proxy` (container path; proxy gate + probes live here, persist across skills) | build-tools writes, implement/verify run |
| `$BASELINE_FAILS` | `run/<id>.baseline.json` → `.baseline_fails` (host) | build-tools folds into manifest; `dsr gate` |
| manifest | `run/<id>/manifest.json` (host) — the `dsr gate` / `dsr isolate` contract | build-tools writes |
| `$VERDICT_FILE` | `run/<id>/verdict.json` (host) — artifact-first decision | verify-spec writes, `dsr gate` reads |

Artifacts split by reader: **code** (proxy gate, probes) lives in the container under `$PROXY_GATE_DIR`;
**metadata** (manifest, verdict, baseline) lives on the host under `harness/feature/run/` where `dsr`
reads it directly. `dsr gate`/`isolate` run the proxy gate in the container but read manifest/verdict
from the host.

## Setup (per task)

```bash
export DSR_TASK=httpx-streaming-json-iteration
cd harness/feature
python3 dsr.py task  $DSR_TASK          # identity precondition — gradeable? PRD. REJECTED stops here.
python3 dsr.py base  $DSR_TASK          # capture $BASELINE_FAILS (clean-base existing-suite reds)
# container is left at clean base, /tmp/proxy created
```

## Drive the skills (this session)

1. `/design-doc <id>`  → acceptance criteria (exhaustive), context, approach, **FEATURE-SHAPE** line. **Spec only.**
2. **Route on FEATURE-SHAPE** (advisory — both skills self-classify in their Phase 0, so misrouting is recoverable):
   - `enum`      → `/build-tools <id>`
   - `invariant` → `/compose <id>`
   - `mixed`     → `/build-tools <id>` AND `/compose <id>` in either order (monoidal — order does not change the manifest; the second skill detects the first's slice and merges)
   Both skills emit the same manifest schema so `dsr gate` / `dsr isolate` work unchanged. Running the wrong skill on a shape it doesn't apply to is a clean no-op (`*.applied: false` in the manifest stub) — re-route and try again.
   Check it in isolation, no implement-spec needed:
   ```bash
   python3 dsr.py isolate $DSR_TASK run/$DSR_TASK/manifest.json   # want: SOUND + LIVE
   ```
3. `/implement-spec <id>` → builds the feature in the container, iterates against the proxy gate.
4. `/verify-spec <id>`   → runs proxy gate + existing suite (minus `$BASELINE_FAILS`), writes verdict.
5. Deterministic stop:
   ```bash
   python3 dsr.py gate $DSR_TASK run/$DSR_TASK/manifest.json      # PROXY-GREEN boolean (necessary, not sufficient)
   ```

## Retro oracle (only after done — measures the gap)

```bash
python3 dsr.py grade $DSR_TASK     # applies hidden test.patch, runs base+new, prints reward
```

The lesson = proxy-green (step 5) vs grade-green (here). Decompose grade-green into the encoded
necessary bar vs the LLM residue. Expect ~0% test-reproduction, mid-80s grade pass.
