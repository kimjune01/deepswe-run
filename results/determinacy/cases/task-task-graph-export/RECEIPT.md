# Receipt -- task-task-graph-export

- repo: `go-task/task` @ `54bdcba36935`
- **verdict: AIRTIGHT (claimable -- mechanical spine)**

## Tier 1 -- coverage (grep-verified)
44/45 graded behaviors covered by a prose clause; **1 GAP** (test grades it, gold implements it, prose silent). Full table: [`attribution/task-task-graph-export.md`](../../attribution/task-task-graph-export.md).

## Tier 2 -- airtight (mechanical)
The hidden test grades the discriminating constant `"root" -> "mid"`, which is **absent from the prose and from the codebase** at `54bdcba36935`, present only in gold+test. Re-verify it yourself:

```bash
git clone https://github.com/go-task/task.git /tmp/task-task-graph-export && cd /tmp/task-task-graph-export && git checkout 54bdcba369357b47e19066b57badfb216a4c8d95
rg --fixed-strings -g '!*test*' -e '"root" -> "mid"'   # expect: no matches (absent)
```
[witness](AMBIGUITY_WITNESS.md)

## Materials
[spec.md](spec.md) · [gold.diff](gold.diff) · [hidden_test.diff](hidden_test.diff)
