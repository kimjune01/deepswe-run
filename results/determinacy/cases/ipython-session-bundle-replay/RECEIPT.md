# Receipt -- ipython-session-bundle-replay

- repo: `ipython/ipython` @ `0bb317d10fdc`
- **verdict: CODEBASE-PLURAL (claimable -- multiplicity evidence)**

## Tier 1 -- coverage (grep-verified)
43/44 graded behaviors covered by a prose clause; **1 GAP** (test grades it, gold implements it, prose silent). Full table: [`attribution/ipython-session-bundle-replay.md`](../../attribution/ipython-session-bundle-replay.md).

## Tier 2 -- codebase-plural (mechanical)
The codebase makes the choice ≥2 conflicting live ways while the prose is silent, and the comparability pass confirmed they are the same decision. The plurality is the receipt — point at the precedents (clone `ipython/ipython` @ `0bb317d10fdc`):

- `IPython/core/interactiveshell.py` — stops the cell sequence on a failed ExecutionResult
- `IPython/core/shellapp.py` — continues through a sequence without inspecting run_cell success

[witness](AMBIGUITY_WITNESS.md)

## Materials
[spec.md](spec.md) · [gold.diff](gold.diff) · [hidden_test.diff](hidden_test.diff)
