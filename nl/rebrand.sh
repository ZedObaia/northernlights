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
    perl -pi -e 's/`t3 ([a-z][a-z -]*)(\\?)`/`nl $1$2`/g; s/Command\.make\("t3"/Command.make("nl"/g; s/commandPath: \["t3"/commandPath: ["nl"/g' "$f"
    case "$f" in apps/server/src/cli/*.test.ts) perl -pi -e 's/\["t3"(?=[,\]])/["nl"/g' "$f" ;; esac
  done

# Binary: the executable is `nl`, and every command shown to the user says `nl`.
# Left as `t3`: the npm package name (identity checks, `vp --filter t3`, `npx t3@<version>`) and
# upstream's installer, updater, service launcher and pinned runtimes, which this setup never runs.
SUBS='browser|triage|pair|serve|connect|up|status|service|update|install|uninstall|doctor|auth|thread|project|environment|policy|trace|theme|app|help|command'
perl -pi -e 's/"t3": "\.\/dist\/bin\.mjs"/"nl": ".\/dist\/bin.mjs"/' apps/server/package.json
grep -rlIE --exclude-dir=node_modules -e 'npx t3|"t3"|bin[./][t]3|"bin":\{"t3"|bin: \{ t3|\{ t3: Schema| t3["'"'"'`]|`t3|["'"'"'`( ]t3 ' \
  apps/server/src/cli/invocation*.ts apps/server/src/cli/up.ts apps/server/src/cli/up.*.ts apps/server/src/cli/server*.ts \
  apps/server/src/cli/pair*.ts apps/server/src/cli/connect*.ts apps/server/src/cli/thread*.ts \
  apps/server/src/cli/project*.ts apps/server/src/triage .github/triage \
  apps/web/src apps/mobile/src packages/client-runtime/src/preview 2>/dev/null |
  while IFS= read -r f; do
    # invocation.test.ts expects `npx t3` where the CLI rebuilds an npx command from the package name.
    case "$f" in *invocation.test.ts) NPX=0 ;; *) NPX=1 ;; esac
    SUBS="$SUBS" NPX="$NPX" perl -pi -e '
      my $subs = $ENV{SUBS};
      if ($ENV{NPX}) {
        s/sudo npx t3 browser setup/sudo env PATH=\$PATH nl browser setup/g;
        s/npx t3(?=[ .`"\x27])/nl/g;
      }
      s/path\.join\(([a-z]+(?:, "[^"]+")?), "t3"\)/path.join($1, "nl")/g;
      s/\bt3\.(cmd|exe)\b/nl.$1/g;
      s/(\? "nl\.(?:exe|cmd)" : )"t3"/$1"nl"/g;
      s/: \["t3"\]/: ["nl"]/g;
      s/resolveCommandPath\("t3"\)/resolveCommandPath("nl")/g;
      s/path\.join\(directory, "t3"\)/path.join(directory, "nl")/g;
      s/manifest\.bin\.t3\b/manifest.bin.nl/g;
      s#"bin/t3"#"bin/nl"#g;
      s#/bin/t3(?![.\w])#/bin/nl#g;
      s/"bin":\{"t3":/"bin":{"nl":/g;
      s/bin: \{ t3:/bin: { nl:/g;
      s/Struct\(\{ t3: Schema\.String \}\)/Struct({ nl: Schema.String })/g;
      s/(?<= )t3(?=["\x27`])/nl/g;
      s/`t3 \$\{/`nl \${/g;
      s/`t3(\\?)`/`nl$1`/g;
      s/(["\x27`])t3 (?!code\b)(?=[a-z.\/-])/$1nl /g;
      s/(?<=[ (])(?<!npx )t3 (?=(?:$subs|is uninstalled|\d)\b)/nl /g;
      s/Installed t3 /Installed nl /g;
    ' "$f"
  done

# Data home is ~/.nl, so Northern Lights never opens a real T3 Code install's ~/.t3.
for f in apps/server/src/os-jank.ts apps/server/src/os-jank.test.ts apps/server/src/cli/browser.ts \
  apps/desktop/src/app/DesktopStatePaths.ts; do
  if [ -f "$f" ]; then perl -pi -e 's/(["\x27])\.t3\1/$1.nl$1/g' "$f"; fi
done

# Desktop app: its own identity, so it never replaces or shares state with T3 Code.
perl -pi -e 's/"productName": "T3 Code \(Beta\)"/"productName": "Northern Lights"/' apps/desktop/package.json
perl -pi -e 's/const DESKTOP_APP_ID = "com\.t3tools\.t3code";/const DESKTOP_APP_ID = "com.zedobaia.northernlights";/; s/"T3 Code \(Nightly\)"/"Northern Lights (Nightly)"/; s/\?\? "T3 Code"\)/?? "Northern Lights")/' \
  scripts/build-desktop-artifact.ts
perl -pi -e 's#https://github\.com/pingdotgg/t3code/releases#https://github.com/ZedObaia/northernlights#' \
  apps/desktop/src/app/DesktopStartupRecovery.ts

# Wordmark: T3's glyph becomes an N, and the name beside it reads Northern Lights.
for f in apps/web/src/components/T3Wordmark.tsx apps/mobile/src/components/T3Wordmark.tsx; do
  perl -pi -e 's/viewBox="15\.5309 37 94\.3941 56\.96"/viewBox="0 0 60 60"/; s/d="M33\.4509[^"]*"/d="M6 54V6h12l24 34V6h12v48H42L18 20v34z"/; s#94\.3941 / 56\.96#1#; s/accessibilityLabel="T3"/accessibilityLabel="Northern Lights"/' "$f"
  if grep -q "M33.4509" "$f"; then echo "rebrand: $f no longer matches; update nl/rebrand.sh" >&2; exit 1; fi
done
perl -pi -e 's/^(\s+)Code$/$1Northern Lights/; s/aria-label="T3"/aria-label="Northern Lights"/' \
  apps/web/src/components/sidebar/SidebarChrome.tsx
perl -pi -e 's/>Code<\/span>/>Northern Lights<\/span>/' apps/web/src/components/ui/standalone-page.tsx
perl -pi -e 's/^(\s+)Code$/$1Northern/' apps/mobile/src/components/CompactBrandTitle.tsx
