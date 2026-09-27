# B2 pilot grammar/discourse sources — pre-authoring verification

**Date:** 2026-09-27
**Purpose:** plan 8.3 / outline decision D8 — source verification completed
BEFORE any `spanish.json` edit for `es-unit-26`. Verification pass by a
research lane (lib-16) with a strict no-fabrication rule: only citations
actually retrieved and read are recorded; unverifiable items are marked as
such rather than asserted.
**Status key:** CONFIRMED = two independent sources · SINGLE-SOURCE = one
solid source · GAP = expected secondary source not found · UNVERIFIABLE-
ONLINE = authoritative work exists but text could not be retrieved.

## R1 — `aunque` + indicative vs subjunctive in concessive clauses

**Status: SINGLE-SOURCE** (primary solid; secondary unverifiable online)

- **Authority A — NGLE §47.13** (verified retrieved):
  *Nueva gramática de la lengua española*, sintaxis, "Tiempo y modo en las
  oraciones concesivas", https://www.rae.es/gram%C3%A1tica/sintaxis/tiempo-y-modo-en-las-oraciones-concesivas
  - "En las prótasis hipotéticas … *Las prótasis hipotéticas se construyen
    en subjuntivo.*"
  - "En las prótasis factuales … *Las prótasis factuales admiten los dos
    modos: el indicativo … y el subjuntivo*."
  - Note: the pre-identification table guessed §47.2 — the verified section
    is **§47.13**. Cite §47.13 only.
- **Authority B — Butt & Benjamin, *A New Reference Grammar of Modern
  Spanish* (4th/5th eds.): UNVERIFIABLE-ONLINE.** Search results confirm a
  section "Subjunctive after subordinators" (~§16.12) exists, but the text
  could not be retrieved; **do not cite a specific B&B section number for
  this rule.**

**Wording limits:** the content may state the factual/hypothetical
distinction (both modes possible for factual concessives; hypotheticals
take the subjunctive) citing NGLE §47.13. Do not claim multi-source
agreement; do not attribute to a specific B&B section.

## R2 — contrastive adverbial connectors `sin embargo` / `no obstante` / `en cambio`

**Status: SINGLE-SOURCE** (primary solid; expected Fundéu secondary = GAP)

- **Authority A — NGLE §30.13** (verified retrieved): *Nueva gramática*,
  sintaxis, "Conectores discursivos adverbiales (II). Clases semánticas",
  https://www.rae.es/gram%C3%A1tica/sintaxis/conectores-discursivos-adverbiales-ii-clases-sem%C3%A1nticas
  - Adversativos/contraargumentativos group includes *ahora bien, en cambio,
    eso sí, no obstante, sin embargo* (among others).
  - "*de ahí que sea posible la posposición de* sin embargo *pero no la de*
    pero." (postpositionality distinction).
- **Authority B — FundéuRAE: GAP.** No dedicated recommendation entry on
  `sin embargo` vs `no obstante` register/syntax was found on fundeu.es.
  Partial support only: RAE *Nueva gramática básica* classifies
  `sin embargo`/`no obstante` (equipollable to *pero*) vs `en cambio`
  (equipollable to *sino*).

**Wording limits:** classify connectors per NGLE §30.13 / gramática básica
groupings. Do NOT assert register distinctions between `sin embargo` and
`no obstante` beyond what the retrieved sources say — that specific claim
lacks a second source (gap flagged).

## R3 — `pero` (conjunction, not postposable) vs adverbial connectors; `pero sin embargo`

**Status: CONFIRMED** (primary retrieved; rule independently corroborated by
the §30.13 retrieval in R2)

- **Authority A — NGLE §31.10** (verified retrieved): *Nueva gramática*,
  sintaxis, "La coordinación adversativa",
  https://www.rae.es/gram%C3%A1tica/sintaxis/la-coordinaci%C3%B3n-adversativa
  - "*Son adversativas las conjunciones* pero, mas *y* sino."
  - postpositionality: adverbial connectors may follow; *pero* may not.
  - **§31.10j:** "*El español admite la combinación —redundante, pero
    enfática— de la conjunción* pero *y varias locuciones adverbiales de
    este grupo:* pero no obstante, pero sin embargo, pero en cambio."
- **Authority B — Butt & Benjamin: UNVERIFIABLE-ONLINE** (same access
  issue), but the conjunction/adverbial distinction is independently
  corroborated by R2's §30.13 retrieval (same RAE corpus, different
  chapter).

**Wording limits:** if quoting, use the exact §31.10j phrasing
("redundante, pero enfática") and cite §31.10/§31.10j.

## R4 — stance/hedging markers (`creo que`, `en mi opinión`, `parece que`)

**Status: SINGLE-SOURCE** (hedging-as-phenomenon confirmed; the specific
marker list NOT validated by the source)

- **Authority A — Yao, G. & Sun, W. (2025).** "Hedging use in Spanish
  academic writing: A contrastive corpus-based study." *Ibérica* 50,
  203–232. https://revistaiberica.org/index.php/iberica/article/view/1053
  - Abstract confirms: hedging is "a crucial rhetorical strategy in academic
    discourse"; the study examines lexico-grammatical and functional hedging
    categories in Spanish academic writing (non-native vs native writer
    groups).
  - The abstract does **not** enumerate `creo que` / `en mi opinión` /
    `parece que` as individual validated markers (full text is paywalled).
- **Authority B — Butt & Benjamin (attitude/evidentiality adverbials):
  UNVERIFIABLE-ONLINE.**

**Wording limits:** the content may teach these markers as natural stance
formulas (they are ordinary, widely attested usage), but the research file
must not claim Yao validates this specific marker list, and no citation may
assert a specific B&B section. Flag for native review: marker naturalness
at B2 is developer/native-review territory.

## Transfer summary (authoritative for the authoring slice)

| Point | Record | Do NOT |
|---|---|---|
| R1 | NGLE §47.13 (URL above) — hypothetical → subjunctive; factual → both modes | cite B&B §16.12.8; claim two-source confirmation |
| R2 | NGLE §30.13 — adversative/contraargumentative grouping; `sin embargo` postposable, `pero` not | claim Fundéu has a `sin embargo`/`no obstante` register entry; overstate register differences |
| R3 | NGLE §31.10 + §31.10j — conjunction vs adverbial; "redundante, pero enfática" combinations | paraphrase §31.10j loosely when quoting |
| R4 | Yao (2025) *Ibérica* abstract — hedging documented as a category in Spanish academic writing | claim the abstract validates `creo que`/`en mi opinión`/`parece que` specifically |

**Open gaps for later/native review:** R1/R4 secondary-source gap (B&B
unverifiable online); R2 Fundéu gap; R4 marker-specificity limit. None of
these blocks authoring — the content asserts only what the verified sources
support, and all learner-facing naturalness is developer-owned anyway.
