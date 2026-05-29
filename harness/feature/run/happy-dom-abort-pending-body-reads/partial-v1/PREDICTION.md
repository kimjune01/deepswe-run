# Pre-flight prediction for happy-dom-abort-pending-body-reads (cheap survey, $0)

**2026-05-28 ~21:15.** Predicting whether Hₐ₈ would fire on a happy-dom fire before any tokens
spent. Reading the PRD, gold patch (1064 lines), and hidden test.patch only.

## Axis matrix induced from PRD + hidden tests

| Axis | Values | Source |
|---|---|---|
| A — shutdown trigger | `happyDOM.close()`, `page.close()`, `browser.close()`, navigation replacement | PRD sentence 1 |
| B — body type | Request body, Response body, Response.formData() multipart | PRD sentence 1 + 2 |
| C — consumption state | in-flight (reading now), already-buffered (read complete), never-started | PRD "successful reads unchanged" + "fully buffered remain readable" |
| D — side effects | body reads, timers, requestAnimationFrame | PRD sentence 3 |

Cross-axis space: 4 × 3 × 3 = 36 abort cases + 4 × 2 = 8 side-effect cases. Hidden bench
tests 19 of these (12 in-flight × A×B + 5 timer + 2 negative).

## What build-tools without Hₐ₈ would write at proxy-author time

By default, build-tools enumerates the surfaces the PRD *lists*:
- 4 shutdown triggers (single-axis A)
- 3 body types (single-axis B)
- 3 consumption states (single-axis C)
- 3 side-effect types (single-axis D)

Total: ~13 single-axis proxy tests. The PRD doesn't *spell out* the crossings; it just says
"the same shutdown behavior should apply." Without axis-crossing discipline, build-tools
treats this as "one test per body type" + "one test per trigger" — but **not** "every trigger
crossed with every body type."

## What Composer probably misses on a no-Hₐ₈ harness fire

Mapped from the cross-axis gaps:

1. **(70% confidence) Tests crossing `navigation replacement` with body reads will fail.**
   The PRD names this trigger near the end of sentence 1 ("or a navigation that swaps out
   the active page state"). Build-tools likely emphasizes `happyDOM.close()` (the first-named
   API) as the primary path; navigation is an after-thought. Composer's impl probably wires
   up `happyDOM.close()` cleanly, but the navigation handler (in BrowserWindow.ts or page
   switching) may not invoke the same abort path.
   - Hidden tests likely affected: 1× `it('Rejects in-flight response body reads when navigation replacement…')`, 1× request, 1× formData = **3 failures**.

2. **(50% confidence) Response.formData() multipart parsing has a separate gap.**
   PRD says "The same shutdown behavior should apply to multipart formData() parsing." The
   word "same" implies the implementer should reuse one code path — but multipart parsing is
   in `MultipartFormDataParser.ts` (separate file in gold). If Composer writes the
   abort-wiring on Request.ts / Response.ts but forgets the multipart parser, all 4 ×
   `it(Rejects multipart formData parsing when X interrupts consumption.)` fail.
   - 4 failures × (probability the parser is wired separately) ≈ 1-2 expected.

3. **(40% confidence) Timer/animationFrame cleanup misses page-vs-browser distinction.**
   PRD says "Scheduled timers and requestAnimationFrame callbacks associated with discarded
   page state must also be cleared." Hidden tests have 5 variants by scope (standalone window
   close, page close, browser close, navigation). The page/browser distinction is subtle:
   `browser.close()` should iterate all pages and close timers in each. Composer may write
   `browser.close()` as `for pages: page.close()` (correct) or as a direct timer iteration
   (incorrect — would miss the page-window distinction).
   - 1-2 timer test failures expected.

4. **(20% confidence) "Leaves successful response body reads unchanged" — should pass.** This
   is the negative test; Composer's abort should fire only on shutdown, not in normal flow.
   Composer's first-pass usually handles this correctly (we saw it on kysely + bandit).

## Predicted outcomes

| Outcome | Probability | Implication |
|---|---|---|
| Proxy-green + grade-green (REWARD 1) | 25% | Composer happens to wire all crossings; Hₐ₈ doesn't fire here. Substrate too easy. |
| Proxy-green + grade-red (3-6 failures, similar to bandit) | **55%** | **Hₐ₈ confirmed at n=2.** The proxy-vs-grade gap is real on a second feature class. Patches land at navigation + multipart + timer scope. |
| Proxy-red on first pass | 15% | Composer's first impl is structurally incomplete; adversary loop fires; H₉ overlap measurable. |
| Composer aborts / structural error | 5% | Operational gap; re-fire with diagnostics. |

## Hₐ₈ verification value

If outcome 2 lands AND the failing tests are predominantly in the *predicted axis-crossing
cases* (navigation × body-type, multipart-specific paths, timer scope), then Hₐ₈'s
meta-pattern transfers from bandit (compositional/selector) to happy-dom (additive/abort-wiring).
That's n=2 on the meta-pattern, on two structurally-different feature classes. Strong evidence
for encoding Hₐ₈ into build-tools regardless of feature class.

If outcome 2 lands but the failures are in OTHER unpredicted cases, Hₐ₈ is too narrow; the
substrate gap is a different shape we haven't named. Useful refutation.

If outcome 1 lands, Hₐ₈ may be Composer-specific to the bandit pattern OR happy-dom may not
have axis-crossing gaps the bench cares about.

## Cost ledger for this round of cheap learning

- 0 model tokens
- ~12 min reading PRD + gold patch structure + hidden test names + test-case enumeration
- One firm prediction with quantified probabilities and named axis-crossing cases
- If the next happy-dom fire confirms outcome 2 with predicted failure shape: Hₐ₈ becomes a
  general harness patch, not a one-substrate finding.

Recording at 2026-05-28 ~21:15. To verify, would need to spin up the happy-dom container
(`pier ensure` or equivalent) and fire Composer. Estimated cost of that verification:
~$0.50 model + container provisioning time.
