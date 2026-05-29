# Procedures — model CLIs for the scored run

Operational setup for the primary model pair (Gemini 3.5 Flash + Composer 2.5) and its
short-lived credentials. Companion to [`../PREREGISTRATION.md`](../PREREGISTRATION.md) §3a.

## Why these two

Cost-driven swap from the earlier Sonnet 4.5 + GPT-5.5 pair. Composer 2.5 ($0.50/M in,
$2.50/M out standard) matches Opus-tier coding benchmarks at ~1/10 the price; Gemini 3.5
Flash ($0.50/M in, $3.00/M out) is the latest Flash available to our key. Full-suite
budget for the recon→craft→audit scaffold lands ~$80/arm on standard pricing
(~$78 Composer, ~$82 Flash) plus ~$20-50 EC2 — vs the ~$500/arm Composer Fast tier would
cost. See README cost note + the worklog estimate.

## Credentials (already in `~/.zshrc`)

```bash
export GEMINI_API_KEY=AIza…                              # personal Google AI Studio key
export CURSOR_API_KEY=crsr_…                             # short-lived, name: swebench-pro
export GOOGLE_CLOUD_PROJECT=swebench-pro
export GOOGLE_CLOUD_PROJECT_NUMBER=1063339214513
```

The Cursor key is created **just for this ablation** and must be revoked when the run
ends — the zshrc comment line above the exports flags this. Revoke at
<https://cursor.com/dashboard> → API Keys.

## CLI install

```bash
# Gemini (already on this box)
npm install -g @google/gemini-cli@0.38.0                 # pinned per PREREGISTRATION §9a

# Cursor agent CLI
curl -fsS https://cursor.com/install | bash              # installs ~/.local/bin/{agent,cursor-agent}
```

## Bootstrap (the one-shot entry point)

```bash
cd deepswe-run
bash harness/bootstrap.sh        # idempotent: checks all pins, runs both CLI smokes,
                                 # emits harness/.dsrenv with role-split env vars
source harness/.dsrenv           # exports DSR_CRAFT_MODEL, DSR_ADVERSARY_MODEL, etc.
```

`bootstrap.sh` ends with `READY — env validated` when green. If it fails, it tells you the
exact command to fix. Re-run any time the box environment may have drifted.

## Models — verified available

```bash
# Gemini — list models the key can see
curl -s "https://generativelanguage.googleapis.com/v1beta/models?key=$GEMINI_API_KEY" \
  | jq -r '.models[].name' | grep flash
# → models/gemini-3.5-flash ← the one we use

# Cursor — list models the key can see
curl -s -H "Authorization: Bearer $CURSOR_API_KEY" https://api.cursor.com/v0/models
# → ["composer-2.5","gpt-5.5-high",…,"claude-opus-4-8-thinking-high",…]
```

`gemini-3.5-flash` is the latest Flash tier — newer than `gemini-3-flash-preview` and the
3.1 family. `composer-2.5` is the standard tier ($0.50/$2.50); avoid the `-fast` variants
(6× markup) unless explicitly justified.

## Smoke tests (must pass before any scored run)

```bash
# Gemini
echo "" | gemini -m gemini-3.5-flash -p "say hi in one word"
# expected: Hello

# Cursor (note: -f to trust the cwd in non-interactive `-p` mode)
cursor-agent -p -f --model composer-2.5 "respond with the single word: ok"
# expected: ok
```

If Cursor returns `No models available for this account`, the env var didn't propagate —
`source ~/.zshrc` and retry. If you get `{"code":"internal","message":"Error"}` from the
REST endpoint with an empty `Authorization: Bearer` header in `curl -v`, same cause.

## Invocation pattern in the scaffold (role-split per PREREGISTRATION §0.2)

| stage | role | CLI | env var |
|---|---|---|---|
| design-doc | recon / abduction | `$DSR_GEMINI_CMD '…'` (Flash, cheap divergent) | `DSR_RECON_MODEL=gemini-3.5-flash` |
| build-tools | craft (proxy tests) | `$DSR_CURSOR_CMD '…'` (Composer, impl strength) | `DSR_CRAFT_MODEL=composer-2.5` |
| compose | craft (invariant tests) | `$DSR_CURSOR_CMD '…'` | `DSR_CRAFT_MODEL=composer-2.5` |
| implement-spec | craft (impl patch) | `$DSR_CURSOR_CMD '…'` | `DSR_CRAFT_MODEL=composer-2.5` |
| Phase 4/5 adversary review | adversary (cross-family critique) | `$DSR_GEMINI_CMD '…'` | `DSR_ADVERSARY_MODEL=gemini-3.5-flash` |
| verify-spec / audit | deterministic | (no model) | — |
| baseline arm A (deferred to scored) | single-agent | `gemini -m gemini-3.5-flash -p '…'` | — |
| baseline arm B (deferred to scored) | single-agent | `cursor-agent -p -f --model composer-2.5 '…'` | — |

The scaffold-arm driver writes the trajectory + cost log per task into the per-trial
artifact directory referenced by PREREGISTRATION §7.

## Pre-run gate checklist (clone from `swebench-pro/PREREGISTRATION-cheap-ablation` §5)

Before dispatching either the partial run or the scored run:

- [ ] `bash harness/bootstrap.sh` returns `READY — env validated`.
- [ ] `source harness/.dsrenv`; `echo $DSR_CRAFT_MODEL` prints `composer-2.5`.
- [ ] `$DSR_FORBID_FAST_TIER` is set to 1 (guard against `composer-2.5-fast` 6× markup).
- [ ] `grep -rinE 'codex|claude|sonnet|gpt-5' skills/` shows only typed-acceptance commentary
      — no `codex exec`, no hardcoded `claude`/`sonnet` model strings in code paths.
- [ ] **Capture-discipline pilot** — run one task end-to-end on a known-good fix; confirm
      the captured diff has no `node_modules/`, no build dirs, no test-file edits, no per-file
      blob > 256 KB. (`swebench-pro/PROCEDURE.md` §5 lists the gotchas that cost a pilot to find.)
- [ ] Cost ledger started; tripwire set (partial: $3; scored: $200).
- [ ] For the scored run only: `deepswe-partial-v1` tag exists and its results landed in HG.

## Teardown checklist

- [ ] Revoke `CURSOR_API_KEY` (name `swebench-pro`) at cursor.com/dashboard
- [ ] Remove both export lines + the comment from `~/.zshrc`
- [ ] Confirm no scored-run artifact still references the raw key in plaintext
- [ ] Rotate `GEMINI_API_KEY` if it was shared with any other party during the run
