# Receipt -- anko-default-function-arguments

- repo: `mattn/anko` @ `9d2d84bb1564`
- **verdict: CODEBASE-PLURAL (claimable -- multiplicity evidence)**

## Tier 1 -- coverage (grep-verified)
13/16 graded behaviors covered by a prose clause; **3 GAP** (test grades it, gold implements it, prose silent). Full table: [`attribution/anko-default-function-arguments.md`](../../attribution/anko-default-function-arguments.md).

## Tier 2 -- codebase-plural (mechanical)
The codebase makes the choice ≥2 conflicting live ways while the prose is silent, and the comparability pass confirmed they are the same decision. The plurality is the receipt — point at the precedents (clone `mattn/anko` @ `9d2d84bb1564`):

- `core/core.go` — load parses a file body by manually creating a Scanner and calling parser.Parse, bypassing ParseSrc
- `vm/vmStmt.go` — normal script execution parses source strings through parser.ParseSrc

[witness](AMBIGUITY_WITNESS.md)

## Materials
[spec.md](spec.md) · [gold.diff](gold.diff) · [hidden_test.diff](hidden_test.diff)
