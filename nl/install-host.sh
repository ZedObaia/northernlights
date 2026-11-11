#!/bin/sh
# One-time setup on the devbox (see devbox/provision.sh: Tailscale, operator, linger, agent CLIs).
# Run as the dev user that owns the agent logins. Safe to re-run.
set -eu
REPO=https://github.com/ZedObaia/northernlights.git
UNITS=~/.config/systemd/user

[ -x ~/.local/share/vite-plus/bin/vp ] ||
  { curl -fsSL https://vite.plus -o /tmp/vp-install.sh && bash /tmp/vp-install.sh </dev/null; }
# Deploy-only checkout: deploy.sh hard-resets it, so never work in it.
[ -d ~/.northernlights ] || git clone -q "$REPO" ~/.northernlights
mkdir -p "$UNITS"
touch ~/.config/northernlights.env

cat > "$UNITS/northernlights.service" <<'UNIT'
[Unit]
Description=Northern Lights server

[Service]
WorkingDirectory=%h/.northernlights
Environment=T3CODE_TELEMETRY_ENABLED=false
# NL_NTFY_URL=https://ntfy.sh/<long-random-topic> goes here
EnvironmentFile=-%h/.config/northernlights.env
# PATH comes from environment.d, so agents get the same CLIs as Paseo's.
ExecStart=%h/.local/share/vite-plus/fallback-bin/node apps/server/dist/bin.mjs serve --host 127.0.0.1 --tailscale-serve --tailscale-serve-port 8443 --no-browser
Restart=on-failure

[Install]
WantedBy=default.target
UNIT

cat > "$UNITS/northernlights-deploy.service" <<'UNIT'
[Unit]
Description=Deploy Northern Lights main

[Service]
Type=oneshot
ExecStart=/bin/sh %h/.northernlights/nl/deploy.sh
UNIT

cat > "$UNITS/northernlights-deploy.timer" <<'UNIT'
[Unit]
Description=Deploy Northern Lights main nightly

[Timer]
OnCalendar=*-*-* 04:30
Persistent=true

[Install]
WantedBy=timers.target
UNIT

# The `nl` CLI. Coreutils also has an `nl` that agents use (`nl -ba file`), so only
# Northern Lights subcommands go to the server; everything else reaches /usr/bin/nl.
# update/install/uninstall/service/up manage upstream's npm install, which this host doesn't use.
mkdir -p ~/.local/bin
cat > ~/.local/bin/nl <<'CLI'
#!/bin/sh
case "${1-}" in
  help|serve|app|pair|auth|environment|browser|project|thread|status|theme|trace|doctor|policy|triage)
    exec "$HOME/.local/share/vite-plus/fallback-bin/node" "$HOME/.northernlights/apps/server/dist/bin.mjs" "$@" ;;
  update|install|uninstall|service|up)
    echo "nl $1: not used here. Deploys come from nl.yml and the northernlights-deploy timer." >&2; exit 1 ;;
esac
exec /usr/bin/nl "$@"
CLI
chmod +x ~/.local/bin/nl

systemctl --user daemon-reload
systemctl --user enable northernlights northernlights-deploy.timer
systemctl --user start northernlights-deploy.timer
sh ~/.northernlights/nl/deploy.sh --force
