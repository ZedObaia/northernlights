#!/bin/sh
# Rebrand T3 Code as Northern Lights. Idempotent: nl.yml re-runs it after every upstream merge,
# so conflicts in rebranded lines resolve by taking upstream's file and running this again.
set -eu
cd "$(dirname "$0")/.."
B=nl/brand

# Images: every T3 brand asset (all channels) becomes the Northern Lights icon.
for f in assets/prod/* assets/nightly/* assets/dev/*; do
  case "$f" in
    *-1024.png) cp "$B/icon.png" "$f" ;;
    *favicon-16x16.png) cp "$B/web/favicon-16x16.png" "$f" ;;
    *favicon-32x32.png) cp "$B/web/favicon-32x32.png" "$f" ;;
    *apple-touch-180.png) cp "$B/web/apple-touch-icon.png" "$f" ;;
    *icon-192x192.png) cp "$B/web/icon-192x192.png" "$f" ;;
    *icon-512x512.png) cp "$B/web/icon-512x512.png" "$f" ;;
    *.ico) cp "$B/web/favicon.ico" "$f" ;;
    */logo.svg) cp "$B/logo.svg" "$f" ;;
  esac
done

# The root README says what this fork is (upstream's README changes never conflict).
cp nl/README.md README.md

# Text: the product name everywhere users or agents read it (tests too, so they stay consistent).
# Kept as upstream: tests whose "T3 Code" is input data, and the MCP server's protocol name,
# which providers echo into tool labels that t3McpToolPresentation parses.
KEEP="packages/shared/src/speech.test.ts packages/shared/src/paletteSearch.test.ts
packages/shared/src/t3McpToolPresentation.test.ts apps/server/src/mcp/McpHttpServer.ts"
grep -rlI --exclude-dir=node_modules -e "T3 Code" -e "T3%20Code" -e "T3+Code" \
  apps/web/src apps/web/index.html apps/web/public apps/mobile/src apps/server/src \
  apps/server/scripts apps/desktop/src packages/*/src .github/triage 2>/dev/null |
  while IFS= read -r f; do
    case " $(echo $KEEP) " in *" $f "*) continue ;; esac
    perl -pi -e 's/T3 Code/Northern Lights/g; s/T3%20Code/Northern%20Lights/g; s/T3\+Code/Northern+Lights/g' "$f"
  done

# CLI: the command is `nl` in help and messages. Code that builds the command it executes
# (`t3 ${...}`) keeps the real binary name.
grep -rlI --exclude-dir=node_modules -e '`t3 ' -e '\["t3"' -e 'Command.make("t3"' \
  apps/server/src apps/web/src apps/mobile/src packages/*/src .github/triage 2>/dev/null |
  while IFS= read -r f; do
    # Its source interpolates the command, so the real `t3` stays and the test must match it.
    [ "$f" = apps/web/src/components/sidebar/updateEverything.logic.test.ts ] && continue
    perl -pi -e 's/`t3 ([a-z][a-z -]*)(\\?)`/`nl $1$2`/g; s/Command\.make\("t3"/Command.make("nl"/g; s/commandPath: \["t3"/commandPath: ["nl"/g' "$f"
    case "$f" in apps/server/src/cli/*.test.ts) perl -pi -e 's/\["t3"(?=[,\]])/["nl"/g' "$f" ;; esac
  done

# Wordmark: T3's glyph becomes an N, and the name beside it reads Northern Lights.
for f in apps/web/src/components/T3Wordmark.tsx apps/mobile/src/components/T3Wordmark.tsx; do
  perl -pi -e 's/viewBox="15\.5309 37 94\.3941 56\.96"/viewBox="0 0 60 60"/; s/d="M33\.4509[^"]*"/d="M6 54V6h12l24 34V6h12v48H42L18 20v34z"/; s#94\.3941 / 56\.96#1#; s/accessibilityLabel="T3"/accessibilityLabel="Northern Lights"/' "$f"
  if grep -q "M33.4509" "$f"; then echo "rebrand: $f no longer matches; update nl/rebrand.sh" >&2; exit 1; fi
done
perl -pi -e 's/^(\s+)Code$/$1Northern Lights/; s/aria-label="T3"/aria-label="Northern Lights"/' \
  apps/web/src/components/sidebar/SidebarChrome.tsx
perl -pi -e 's/>Code<\/span>/>Northern Lights<\/span>/' apps/web/src/components/ui/standalone-page.tsx
perl -pi -e 's/^(\s+)Code$/$1Northern/' apps/mobile/src/components/CompactBrandTitle.tsx
