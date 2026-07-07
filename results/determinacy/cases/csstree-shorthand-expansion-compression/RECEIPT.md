# Receipt -- csstree-shorthand-expansion-compression

- repo: `csstree/csstree` @ `88e3d965c0b1`
- **verdict: AIRTIGHT (claimable -- mechanical spine)**

## Tier 1 -- coverage (grep-verified)
47/51 graded behaviors covered by a prose clause; **4 GAP** (test grades it, gold implements it, prose silent). Full table: [`attribution/csstree-shorthand-expansion-compression.md`](../../attribution/csstree-shorthand-expansion-compression.md).

## Tier 2 -- airtight (mechanical)
The hidden test grades the discriminating constant `currentcolor`, which is **absent from the prose and from the codebase** at `88e3d965c0b1`, present only in gold+test. Re-verify it yourself:

```bash
git clone https://github.com/csstree/csstree.git /tmp/csstree-shorthand-expansion-compression && cd /tmp/csstree-shorthand-expansion-compression && git checkout 88e3d965c0b1628642a30a841745b410d6835052
rg --fixed-strings -g '!*test*' -e 'currentcolor'   # expect: no matches (absent)
```
[witness](AMBIGUITY_WITNESS.md)

## Materials
[spec.md](spec.md) · [gold.diff](gold.diff) · [hidden_test.diff](hidden_test.diff)
