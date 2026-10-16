#!/bin/zsh
# Render ../collage.png from template.html and the four captures in shots/.
# Needs Chromium (or set CHROMIUM) and ImageMagick (`brew install imagemagick`).
set -e
HERE=${0:A:h}
CHROMIUM=${CHROMIUM:-/Applications/Chromium.app/Contents/MacOS/Chromium}
for f in hero orgs search types; do
  [ -f "$HERE/shots/$f.png" ] || { echo "missing shots/$f.png (run ./capture.sh $f)"; exit 1; }
done

sed -e "s#ICON#$HERE/../icon.png#" \
    -e "s#SHOT_CODES#$HERE/shots/hero.png#" \
    -e "s#SHOT_COLLECTIONS#$HERE/shots/orgs.png#" \
    -e "s#SHOT_FOLDERS#$HERE/shots/search.png#" \
    -e "s#SHOT_TYPES#$HERE/shots/types.png#" \
    "$HERE/template.html" > "$HERE/render.html"

"$CHROMIUM" --headless --disable-gpu --hide-scrollbars --force-device-scale-factor=1 \
  --window-size=2400,1600 --screenshot="$HERE/render.png" "file://$HERE/render.html" 2>/dev/null
magick "$HERE/render.png" -strip -define png:compression-level=9 "$HERE/../collage.png"
rm -f "$HERE/render.html" "$HERE/render.png"
echo "wrote assets/collage.png"
