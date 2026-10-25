#!/usr/bin/env bash
# Copies the brand assets from the shiioo repository (assets/brand, built by
# its build.py) into static/, and derives the icons and the social card.
# Pixel art is kept as small PNGs and scaled by the browser with
# image-rendering: pixelated. Needs ImageMagick.
set -euo pipefail
cd "$(dirname "$0")/.."
brand="${SHIIOO_REPO:-../shiioo}/assets/brand"
cp "$brand/source/mascot-128.png" static/img/mascot.png
cp "$brand/source/icon-expressions.png" static/img/staff.png
cp "$brand/shiioo-icon-64.png" static/img/icon-64.png
cp "$brand/shiioo-icon-256.png" static/img/icon-256.png
cp "$brand/shiioo-favicon.svg" static/img/favicon.svg
cp "$brand/favicon.ico" static/favicon.ico
cp "$brand/shiioo-icon-32.png" static/favicon.png
cp "$brand/shiioo-icon-256.png" static/icon-192.png
cp "$brand/shiioo-icon-256.png" static/apple-touch-icon.png
cp "$brand/shiioo-icon-512.png" static/icon-512.png
cp "$brand/shiioo-icon-512.png" static/icon-maskable-512.png
# The social card: 1200x630 from the 1280x640 brand card, paper background.
magick "$brand/shiioo-social.png" -gravity center -crop 1200x630+0+0 +repage static/img/og-image.png
echo "Brand synced."
