#!/usr/bin/env bash
# Build command for the Cloudflare Pages project (Git integration):
#   scripts/cf-pages-build.sh        output directory: public
# Installs Zola and builds the site.
set -euo pipefail
ZOLA_VERSION="${ZOLA_VERSION:-0.23.6}"

if ! command -v zola >/dev/null; then
    curl -fsSL "https://github.com/getzola/zola/releases/download/v$ZOLA_VERSION/zola-v$ZOLA_VERSION-x86_64-unknown-linux-gnu.tar.gz" | tar xz
    export PATH="$PWD:$PATH"
fi

zola build
