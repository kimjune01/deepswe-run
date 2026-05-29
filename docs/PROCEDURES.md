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
npm install -g @google/gemini-cli                        # v0.38.0 verified

# Cursor agent CLI
curl -fsS https://cursor.com/install | bash              # installs ~/.local/bin/{agent,cursor-agent}
```

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

## Invocation pattern in the scaffold

| stage | CLI | model flag |
|---|---|---|
| recon / craft / audit (generator) | `gemini -m gemini-3.5-flash -p '…'` | latest Flash |
| codex challenger | `cursor-agent -p -f --model composer-2.5 '…'` | Composer standard |
| baseline arm A | `gemini -m gemini-3.5-flash -p '…'` single-agent | — |
| baseline arm B | `cursor-agent -p -f --model composer-2.5 '…'` single-agent | — |

The scaffold-arm driver writes the trajectory + cost log per task into the per-trial
artifact directory referenced by PREREGISTRATION §7.

## Teardown checklist

- [ ] Revoke `CURSOR_API_KEY` (name `swebench-pro`) at cursor.com/dashboard
- [ ] Remove both export lines + the comment from `~/.zshrc`
- [ ] Confirm no scored-run artifact still references the raw key in plaintext
- [ ] Rotate `GEMINI_API_KEY` if it was shared with any other party during the run
