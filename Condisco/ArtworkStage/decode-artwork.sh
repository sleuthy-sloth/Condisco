#!/bin/sh
# Run manually when the master artwork changes to regenerate the app icon files.
# Xcode builds use the generated icons already present in Assets.xcassets.
set -eu

ROOT="${SRCROOT:?SRCROOT not set}"
STAGE="$ROOT/Condisco/ArtworkStage"
ICONSET="$ROOT/Condisco/Assets.xcassets/AppIcon.appiconset"
MASTER_B64="$STAGE/Icon-1024.png.b64"
MASTER_PNG="$STAGE/Icon-1024.png"

mkdir -p "$STAGE"
mkdir -p "$ICONSET"

if [ -f "$MASTER_B64" ]; then
  base64 -D -i "$MASTER_B64" -o "$MASTER_PNG"
fi

if [ ! -f "$MASTER_PNG" ]; then
  echo "error: missing $MASTER_PNG" >&2
  exit 1
fi

for spec in "40:Icon-20@2x.png" "60:Icon-20@3x.png" "58:Icon-29@2x.png" \
           "87:Icon-29@3x.png" "80:Icon-40@2x.png" "120:Icon-40@3x.png" \
           "120:Icon-60@2x.png" "180:Icon-60@3x.png" "152:Icon-76@2x.png" "167:Icon-83.5@2x.png"; do
  px="${spec%%:*}"
  name="${spec#*:}"
  sips -z "$px" "$px" "$MASTER_PNG" --out "$ICONSET/$name" >/dev/null
done

cp "$MASTER_PNG" "$ICONSET/Icon-1024.png"
