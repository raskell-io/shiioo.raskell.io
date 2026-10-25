#!/usr/bin/env bash
# Build command for the Cloudflare Pages project (Git integration):
#   scripts/cf-pages-build.sh        output directory: public
# Always installs the pinned Zola (the Pages build image ships an older
# zola on PATH; using it silently changes how the site renders), then builds.
set -euo pipefail
ZOLA_VERSION="${ZOLA_VERSION:-0.23.6}"

mkdir -p .zola-bin
curl -fsSL "https://github.com/getzola/zola/releases/download/v$ZOLA_VERSION/zola-v$ZOLA_VERSION-x86_64-unknown-linux-gnu.tar.gz" | tar xz -C .zola-bin
export PATH="$PWD/.zola-bin:$PATH"

zola --version
zola build
