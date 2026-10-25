# shiioo.raskell.io

Website for [Shiioo](https://github.com/raskell-io/shiioo), the Virtual Company OS: a staff of AI
agents on your Mac, run from your phone.

**Live:** https://shiioo.raskell.io

## Quick start

```bash
mise install          # tools
mise run serve        # http://127.0.0.1:1111
```

## Tasks

| Task | Description |
|------|-------------|
| `mise run serve` | Dev server with live reload |
| `mise run build` | Build the site into `public/` |
| `mise run check` | Build and check internal links |
| `mise run brand` | Copy the brand assets from `../shiioo/assets/brand` and derive icons and the social card |
| `mise run clean` | Remove `public/` |

## Structure

```
shiioo.raskell.io/
├── config.toml            # Zola configuration
├── content/               # Getting started, how it works, design
├── sass/style.scss        # Paper, charcoal, teal; Bricolage Grotesque + Inter + JetBrains Mono
├── scripts/
│   ├── cf-pages-build.sh  # Cloudflare Pages build command
│   └── sync-brand.sh      # Brand assets -> static/ (pixel art stays PNG, scaled by the browser)
├── static/                # Icons, mascot, social card, _headers, robots.txt
└── templates/             # Zola templates; the home page is index.html
```

The pages follow [Shiioo's docs](https://github.com/raskell-io/shiioo/tree/main/docs). When a
phase lands, update the status table on the home page and the pages with it.

## Deploy

Cloudflare Pages, connected to this repository. Build command `scripts/cf-pages-build.sh`,
output directory `public`. Every push to `main` deploys.
