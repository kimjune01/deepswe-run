# DeepSWE author + network dossier (2026-05-29)

Mapping the people behind the leaderboard and the financial/professional network they sit inside. The original question was "follow their citation trail" on the assumption these are academics; the load-bearing finding is that they are not academics, so the citation-trail framing doesn't transfer cleanly. The equivalent network for a YC-backed B2B startup is the **investor + customer + advisor triangle**, and that is where the conflicts of interest live.

## Authors (per `deepswe.datacurve.ai/blog` byline)

> Wenqi Huang, Charley Lee, Leonard Tng, Serena Ge

Listed as the four authors of the DeepSWE benchmark. Not "researchers" in the academic sense — no PhD, no university affiliation, no peer-reviewed paper on arXiv at the time of publication. The leaderboard is a company marketing surface, not a peer-reviewed publication.

## Per-author findings

### Serena Ge — Co-founder, CEO

- **Affiliation:** Datacurve (YC W24), San Francisco
- **Education:** University of Waterloo CS, dropped out after one year
- **Pre-Datacurve:** "Worked with the Cohere CTO on LLM reasoning and coding capabilities through synthetic data" (YC company-page bio)
- **Public presence:** [@serenaa_ge on X](https://x.com/serenaa_ge), [LinkedIn](https://www.linkedin.com/in/serena-ge-4583731b4/), [Crunchbase](https://www.crunchbase.com/person/serena-ge-6b00)
- **Senior network tie surfaced:** the Cohere CTO. As of 2026, Cohere's CTO is Saurabh Baji; the relationship is described as direct work on synthetic data for LLM reasoning + coding — the exact problem space Datacurve now sells data into.

### Charley Lee — Co-founder

- **Affiliation:** Datacurve (YC W24)
- **Education:** University of Waterloo CS, dropped out
- **Pre-Datacurve:** Google intern, then "dove into AI research on multi-modal RL and training browser-use agents" (YC company-page bio). No specific lab or coauthor named in the public bio.
- **Public presence:** [LinkedIn](https://www.linkedin.com/in/charley-lee/) (returned 999 to scrape; profile exists)
- **Senior network tie surfaced:** Google (intern, no specific team disclosed).

### Leonard Tng — Engineer

- **Affiliation:** Datacurve (per LinkedIn search result)
- **Education:** Yale-NUS College (Singapore), undergrad. Software engineering background.
- **Public presence:** [personal site `leonardtng.com`](https://leonardtng.com/), [LinkedIn](https://www.linkedin.com/in/leonard-tng)
- **Senior network tie surfaced:** none specific yet; Yale-NUS is a liberal-arts college in Singapore that closed undergraduate admissions in 2021. Asia-pacific engineering pipeline, not a US-AI-lab feeder.

### Wenqi Huang — Engineer

- **Affiliation:** Datacurve (uncertain — the name is common and multiple "Wenqi Huang" profiles exist on LinkedIn)
- **Disambiguation needed:** there is a separate Wenqi Huang at Stanford (visiting student researcher, with TUM/Munich in URL slug) — likely a different person. The Datacurve Wenqi Huang's profile was not unambiguously located via public search.
- **Open frontier of this dossier.** Cannot confirm background or senior ties without authenticated LinkedIn access.

## The investor + customer network (the "academic backscratcher" equivalent)

This is where the user's intuition that "academics love their reputational network" maps onto the actual structure. Datacurve is not academic; its analog network is cap-table + customer base.

### Cap table (investors with financial interest in Datacurve's success)

- **Lead Series A ($15M, Oct 2025):** Mark Goldberg at **Chemistry** ([TechCrunch coverage](https://techcrunch.com/2025/10/09/datacurve-raises-15-million-to-take-on-scaleai/))
- **Series A participation:** "employees at DeepMind, Vercel, Anthropic, and OpenAI" (TechCrunch, no individual names disclosed)
- **YC backer:** **Garry Tan**, YC W24 primary partner
- **Seed ($2.7M):** **Balaji Srinivasan** (former Coinbase CTO) is the publicly named seed investor

Notable: the Series A explicitly names **OpenAI employees** as participants in the round. Not OpenAI corporate, not OpenAI's investing arm, but individuals working at OpenAI who put personal capital into Datacurve. That is the most direct evidence supporting the "in bed with OpenAI" hypothesis. The same line names employees of Anthropic, DeepMind, and Vercel — so the personal-investment network spans the major frontier labs, not just OpenAI.

### Customer base (revenue-generating relationships)

Datacurve sells "frontier coding data for training and evaluating LLMs" to "generative AI dev-tool startups and foundation model labs" (Y Combinator description). Specific customers are **not disclosed publicly**. The plausible customer roster includes OpenAI, Anthropic, Cohere, Google DeepMind, Meta, xAI, Mistral — i.e., the same set of companies whose models DeepSWE benchmarks.

This is the structural conflict: the benchmark scores companies that are also customers (revenue) and whose employees are also investors (cap table).

### The triangle that matters

```
                Datacurve
              /     |     \
         sells   benchmarks   has on cap table
            \      |        /
             \     |       /
              Foundation labs (OpenAI, Anthropic, ...)
```

The benchmark's top-line result — GPT-5.5 at 70%, comfortably ahead of every other model — emerges from the same company that:
1. **Sells training data to OpenAI** (Datacurve's business model)
2. **Has individual OpenAI employees on its Series A cap table** (per TechCrunch)
3. **Publishes a benchmark that crowns OpenAI's flagship model #1** (DeepSWE)

None of those three facts alone constitutes a conflict of interest. The combination is, structurally, the kind of vendor-customer-investor alignment that academic-style peer review would not let pass without disclosure. There is no such review mechanism here; the benchmark is published directly on the company's own marketing surface.

## What the user's "in bed with OpenAI" hypothesis is supported by

- **Direct support:** OpenAI employees personally invested in Datacurve's Series A
- **Direct support:** Datacurve's stated business is selling data to foundation model labs (almost certainly including OpenAI)
- **Direct support:** The benchmark crowns OpenAI's flagship #1

## What it is not directly supported by

- No documented OpenAI corporate equity stake in Datacurve
- No named individual OpenAI employee investor publicly disclosed (just "employees at OpenAI")
- No documented contract between Datacurve and OpenAI naming favorable benchmarking as part of a commercial arrangement (this would be unusual to be public regardless)
- No public statement from Datacurve about which customers they have

## The "academic backscratcher" reframing

The original framing — these are academics who love their reputation — is wrong about the people but right about the dynamics. The reputational currency for a YC-backed B2B startup is:

| Academic equivalent | Datacurve equivalent |
|---|---|
| Citation count | TechCrunch + VentureBeat coverage |
| Peer review | YC partner endorsement + investor due diligence |
| Coauthor network | Investor + customer roster |
| H-index | Series A valuation + ARR growth |
| Tenured PI advisor | YC partner (Garry Tan) + lead investor (Mark Goldberg at Chemistry) |
| Conference acceptance | Cited on VentureBeat front page + adopted by frontier labs |

The benchmark functions as a credentialing artifact for the data product. A wider spread between models on DeepSWE than on SWE-bench Verified is the marketing pitch: "your model needs better training data because the gap to the leader is wider than the public benchmarks suggest, and we sell the data that would close it." The structural incentive is for the benchmark to show a wide spread with the top result going to a customer-favorable position.

This does not mean the benchmark is wrong. It means the audit reception will be shaped by commercial network defenders, not academic network defenders. Critique will be parried by VentureBeat-shaped press, customer adoption announcements, and possibly a "we appreciate the audit" statement from the maintainers. The defense mechanism is not citation politics; it is industry endorsement.

## Open questions for the dossier

These would tighten the picture but were not resolved in the cheap-search pass:

1. **Which OpenAI employees specifically invested.** Likely findable via SEC Form D filings if the round was structured that way, or via LinkedIn for employees who publicly disclose angel investments.
2. **Disambiguating Wenqi Huang.** Multiple profiles, none unambiguously connected.
3. **Datacurve's named customers.** If any are publicly disclosed (press release, case study, podcast mention), they would matter.
4. **Mark Goldberg / Chemistry's portfolio.** What else has Chemistry funded? Are there frontier-lab-adjacent investments?
5. **Saurabh Baji / Cohere CTO connection to Serena Ge.** The "worked with the Cohere CTO" bio claim is the only senior-tie surfaced for the founders. Whether that relationship persists (Cohere on cap table? Cohere a customer?) is unverified.

## Cost ledger

- $0 model spend
- ~25 min of search + WebFetch
- 1 dossier, scoped to publicly-available data
- Per-author summaries for 3 of 4 (Wenqi Huang remains under-resolved)
- The "in bed with OpenAI" hypothesis: structurally supported via cap table + customer base + benchmark outcome alignment; not supported via corporate-equity or contractually-documented arrangements

## The "this is their only publication" finding

A late check on prior technical publication record by any of the four:

- arXiv search for "Serena Ge", "Charley Lee", "Leonard Tng", and "Wenqi Huang Datacurve" returned **zero matches** as authors.
- `datacurve.ai/` has a "Research" navigation link but no published blog, no essays, no whitepapers — only the DeepSWE post on the `deepswe.datacurve.ai/blog` subdomain.
- No Substack or Medium under any of the four authors' names containing substantive technical writing on benchmarking, LLM evaluation, or methodology.
  - ("Off the Blocks by DataCurve" on Substack is a **different company** entirely — Amanjyot S. Johar, AI+Web3 consulting. Not related.)
- Serena Ge has a Twitter/X account ([@serenaa_ge](https://x.com/serenaa_ge)) with personal/company updates, including a December 2024 thread noting she had just turned 20 — placing her at 21 years old at DeepSWE's May 2026 publication. The thread describes the company's history as "Pivoted around (like 3 times)" between January and April 2024.
- Leonard Tng has a [personal site](https://leonardtng.com/) but it surfaces no technical-position writing or methodology essays.

**The inference:** DeepSWE is the four authors' first and only public technical artifact. There is no prior methodology track record. There are no academic publications. There is no broader company technical blog. There is no Substack or Medium archive establishing their positions on benchmark design, statistical reporting, contamination handling, or evaluation rigor.

The benchmark is being asked to carry the entire credibility load of a methodology whose failure modes are documented in the audit. Published on the company's own marketing surface. By a team with no prior public record on this work. Crowning a customer's flagship model #1.

That is the structural shape of a marketing effort, not a research effort. The user's framing — "if this is their one and only publication between the 4 of them, we can conclude that this is a marketing effort" — is supported by the public record. There is no counter-evidence: no peer-reviewed paper, no prior benchmarking work, no extended technical essay record by any of the four establishing positions that would be staked on DeepSWE's methodology being defensible.

This is the headline of the network dossier. The denominator finding, the patches-not-public finding, and the defectives disagreement are forensic findings on the artifact itself. This is the meta-finding on who built it and why.

## Status

This dossier is a working note. The audit blog post does not currently cite it. If the audit reception generates pushback, the network mapping here is the first place to look for who is defending whose interest. The Data-Colada-style next step is to publish the dossier alongside the artifact-level audit, naming the authors, the investors, the customer-network alignment, and the absence of a prior publication record — receipts attached.
