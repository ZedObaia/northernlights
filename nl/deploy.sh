#!/bin/sh
# Build and restart Northern Lights when origin/main moved. Runs as the dev user.
# Wrapped in main() so sh parses it fully before git replaces this file.
main() {
  set -eu
  export PATH="$HOME/.local/share/vite-plus/bin:$HOME/.local/share/vite-plus/fallback-bin:$PATH"
  cd "$HOME/.northernlights"
  git fetch -q origin main
  if [ "${1-}" != "--force" ] && [ "$(git rev-parse HEAD)" = "$(git rev-parse origin/main)" ]; then
    exit 0
  fi
  git reset -q --hard origin/main
  vp install
  vp run --filter t3 build
  cp nl/brand/web/* apps/server/dist/client/
  # Restarting interrupts running agent turns, hence the 04:30 timer.
  systemctl --user restart northernlights
}
main "$@"
exit
