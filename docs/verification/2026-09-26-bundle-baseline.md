# Bundle growth baseline — plan §5.4.3

**Date:** 2026-09-26
**State:** Phase 5.3A tree (post Spanish café-pilot audio, pre-B1 content). `main` @ `50a9f7fd43f2442707bd35b5f4deb2054dae5b61` + working tree.
**Purpose:** pin the offline-content footprint before any B1 path is authored, so later measurements have a real baseline. The plan requires the first B1 path to stay bundled and offline; optional content packages remain a **separate project** decision if all five B1 paths ever make installation unreasonable — no server dependency is to be introduced by this plan.

## Measured (on-disk `du`, KB)

| Content area | Size |
| --- | --- |
| `Condisco/Content/` total | **37,312 KB (~36.4 MB)** |
| `audio/` (5 standalone Listen tracks) | 29,488 KB (~28.8 MB) |
| `packs/` (5 pack JSONs) | 4,828 KB (~4.7 MB) |
| `images/` | 2,904 KB (~2.8 MB) |
| `listen-tracks/` (5 track JSONs) | 80 KB |

### Audio by language (each = one bundled Listen track, the only bundled audio)

| Track | KB |
| --- | --- |
| spanish-foundations | 6,220 |
| portuguese-foundations | 6,136 |
| german-foundations | 6,040 |
| french-foundations | 5,904 |
| italian-foundations | 5,188 |

### Pack JSONs

| Pack | KB |
| --- | --- |
| portuguese | 1,040 |
| spanish | 992 (includes the 2 new checkpoint tasks) |
| italian | 992 |
| french | 936 |
| german | 868 |

## Observations

- Audio dominates: each ~6 MB Listen track ≈ 6 packs' worth of JSON. Every new bundled listen track adds ~6 MB (~30 MB across five languages); this is the primary lever if installation size ever matters.
- Device-speech assets add ~0 bytes (synthesized on device, declared but not shipped — allowlisted in `tools/device-speech-media.txt`).
- Pack JSON growth from new content is marginal (~1 MB/pack today; the two Spanish checkpoint tasks were unmeasurable at KB granularity).
- Images (~2.8 MB) are static scene/artwork assets.

## Re-measure rule

Run `du -sk Condisco/Content/{audio,packs,images,listen-tracks}` on any slice that adds bundled audio, long texts, or new packs, and append a dated row here. First planned re-measure: when a B1 path (Phase 7+) first ships content.
