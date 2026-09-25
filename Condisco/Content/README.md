# Condisco/Content

Bundled course content for the app. This folder is declared as a **folder
reference** in the Xcode project (`lastKnownFileType = folder; path = Content`
in Condisco.xcodeproj/project.pbxproj), so its layout is copied verbatim into
the app bundle — mirroring the web repo's `public/` directory.

- `packs/<lang>.json` — the five course packs (french, italian, german,
  portuguese, spanish). Validate them with `./tools/check_packs.sh`.
- `audio/` — generated audio; `tools/render_cafe_audio.py` produces the
  café-scenario clips referenced by the packs.
- `images/` — lesson images referenced by the packs as `images/…`.
- `listen-tracks/` — audio tracks for the Listen course, one `<lang>.json`
  track list per language.

`Condisco/DeepLink/LessonCatalog.generated.swift` is a generated snapshot of
every lesson in the packs; regenerate it with:

    python3 tools/gen_lesson_catalog.py Content/packs \
        Condisco/DeepLink/LessonCatalog.generated.swift