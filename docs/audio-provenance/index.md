# Audio provenance — bundled Listen tracks

Facts-only provenance records for the five bundled Listen tracks under
`Condisco/Content/listen-tracks/`. These records state what the repository
actually evidences and mark every unknown fact as `unknown` — no speaker,
voice, source, or date is ever invented.

Record | Track (lessonId) | Asset | SHA-256 (shipped file)
--- | --- | --- | ---
[italian-market-listen.json](italian-market-listen.json) | `it-market-foundation` | `/audio/italian-foundations/it-market-foundation-listen.mp3` | `4b62a0f6…`
[french-identity-listen.json](french-identity-listen.json) | `fr-identity-foundation` | `/audio/french-foundations/fr-identity-listen.mp3` | `5eccce10…`
[german-introductions-listen.json](german-introductions-listen.json) | `de-introductions-foundation` | `/audio/german-foundations/de-introductions-foundation-listen.mp3` | `e2dc03d2…`
[portuguese-introductions-listen.json](portuguese-introductions-listen.json) | `pt-introductions-foundation` | `/audio/portuguese-foundations/pt-introductions-foundation-listen.mp3` | `5cdec443…`
[spanish-introductions-listen.json](spanish-introductions-listen.json) | `es-introductions-foundation` | `/audio/spanish-foundations/es-introductions-foundation-listen.mp3` | `94623d3b…`

## What the repo evidences

- **Synthesis, not human recording.** Every Listen transcript is paired with
  audio that `Condisco/Listen/ListenModels.swift` describes as
  "synthesized at author time and bundled with the app". Nothing in the repo
  claims a human recording; the media `attribution` strings and
  `tools/device-speech-media.txt` likewise describe synthesized audio.
- **Italian market track generator.** The Italian pack's media entry
  `it-market-listen-audio` (`Condisco/Content/packs/italian.json`) attributes
  the clip to "Original VerbaLibera Kokoro 0.9.4 audio". Its declared SHA-256
  matches the shipped file.
- **Review status.** All five tracks ship with `reviewPending: true` in their
  transcripts; the Italian pack attribution additionally states
  "Native-speaker prosody review remains open."
- **No in-repo render script.** `tools/render_cafe_audio.py` renders the café
  mission clips with macOS `say` voices — it does **not** render Listen
  tracks. The repo history contains only commit `012ff1d` ("Initial commit:
  Condisco iOS app baseline") for the Listen assets; there is no later
  audio-generation commit.

## Unknown (verified absent from the repo)

- The generator **model** and **voice** for the French, German, Portuguese,
  and Spanish Listen tracks — those tracks are not declared in their packs'
  `media` arrays and carry no attribution. (The Italian market track is the
  only Listen track declared as a pack media entry.)
- The **generation date** of every Listen track. The dates `2026-09-05` /
  `2026-09-06` appear in Italian/French pack attributions for the foundation
  *model* clips only, not for the Listen tracks.
- The Kokoro **voice** used for the Italian Listen track ("if_sara" is
  documented only for the Italian foundation model clips).

## Keeping the citations honest

Pack media attributions cite this directory:

- `docs/audio-provenance/index.md` — cited by the Italian `it-polite-coffee-audio`
  and French `fr-polite-coffee-audio` media entries.
- `docs/audio-provenance/italian-market-listen.json` — cited by the Italian
  `it-market-listen-audio` media entry.
- `docs/audio-provenance/spanish-cafe-listen-pilot.json` — cited by the Spanish
  `es-cafe-listen-audio` and `es-cafe-listen-model` media entries (Phase 3.1
  café listen pilot; device-speech assets with no shipped file, so no SHA-256
  exists yet).

`tools/check_packs.sh` verifies every `docs/...` citation in attribution
strings resolves to a real file, so a citation cannot silently dangle again
(see `checkAttributionCitations` in `tools/check_packs.swift`).