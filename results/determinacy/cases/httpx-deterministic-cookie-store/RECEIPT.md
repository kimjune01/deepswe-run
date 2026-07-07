# Receipt -- httpx-deterministic-cookie-store

- repo: `encode/httpx` @ `b5addb64f016`
- **verdict: AIRTIGHT (claimable -- mechanical spine)**

## Tier 1 -- coverage (grep-verified)
42/43 graded behaviors covered by a prose clause; **1 GAP** (test grades it, gold implements it, prose silent). Full table: [`attribution/httpx-deterministic-cookie-store.md`](../../attribution/httpx-deterministic-cookie-store.md).

## Tier 2 -- airtight (mechanical)
The hidden test grades the discriminating constant `"a=1; secure; httponly"`, which is **absent from the prose and from the codebase** at `b5addb64f016`, present only in gold+test. Re-verify it yourself:

```bash
git clone https://github.com/encode/httpx.git /tmp/httpx-deterministic-cookie-store && cd /tmp/httpx-deterministic-cookie-store && git checkout b5addb64f0161ff6bfe94c124ef76f6a1fba5254
rg --fixed-strings -g '!*test*' -e '"a=1; secure; httponly"'   # expect: no matches (absent)
```
[witness](AMBIGUITY_WITNESS.md)

## Materials
[spec.md](spec.md) · [gold.diff](gold.diff) · [hidden_test.diff](hidden_test.diff)
