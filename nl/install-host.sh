#!/bin/sh
# One-time setup on an Ubuntu host, run as root. Safe to re-run.
# Agents run as the unprivileged `nl` user, capped so they cannot starve other services.
set -eu
REPO=https://github.com/ZedObaia/northernlights.git

id nl >/dev/null 2>&1 || useradd --create-home --shell /bin/bash nl
loginctl enable-linger nl
dpkg -s libatomic1 >/dev/null 2>&1 || apt-get install -y libatomic1 # Node 26 needs it
systemctl set-property "user-$(id -u nl).slice" CPUQuota=400% MemoryMax=8G

command -v tailscale >/dev/null || curl -fsSL https://tailscale.com/install.sh | sh
tailscale status >/dev/null 2>&1 || tailscale up
tailscale set --operator=nl
if command -v ufw >/dev/null; then ufw allow in on tailscale0; fi

sudo -iu nl sh -eu <<EOF
[ -x ~/.local/share/vite-plus/bin/vp ] || { curl -fsSL https://vite.plus -o /tmp/vp-install.sh && bash /tmp/vp-install.sh </dev/null; }
[ -d ~/northernlights ] || git clone $REPO ~/northernlights
mkdir -p ~/.config/systemd/user
touch ~/.config/northernlights.env

cat > ~/.config/systemd/user/northernlights.service <<'UNIT'
[Unit]
Description=Northern Lights server

[Service]
WorkingDirectory=%h/northernlights
Environment=PATH=%h/.local/bin:%h/.local/share/vite-plus/bin:/usr/local/bin:/usr/bin:/bin
Environment=T3CODE_TELEMETRY_ENABLED=false
# NL_NTFY_URL=https://ntfy.sh/<long-random-topic> goes here
EnvironmentFile=-%h/.config/northernlights.env
ExecStart=%h/.local/share/vite-plus/bin/node apps/server/dist/bin.mjs serve --host 127.0.0.1 --tailscale-serve --tailscale-serve-port 8443 --no-browser
Restart=on-failure

[Install]
WantedBy=default.target
UNIT

cat > ~/.config/systemd/user/northernlights-deploy.service <<'UNIT'
[Unit]
Description=Deploy Northern Lights main

[Service]
Type=oneshot
WorkingDirectory=%h/northernlights
Environment=PATH=%h/.local/share/vite-plus/bin:/usr/local/bin:/usr/bin:/bin
ExecStart=/bin/sh %h/northernlights/nl/deploy.sh
UNIT

cat > ~/.config/systemd/user/northernlights-deploy.timer <<'UNIT'
[Unit]
Description=Deploy Northern Lights main nightly

[Timer]
OnCalendar=*-*-* 04:30
Persistent=true

[Install]
WantedBy=timers.target
UNIT

export XDG_RUNTIME_DIR=/run/user/\$(id -u)
systemctl --user daemon-reload
systemctl --user enable northernlights northernlights-deploy.timer
systemctl --user start northernlights-deploy.timer
PATH=\$HOME/.local/share/vite-plus/bin:\$PATH sh ~/northernlights/nl/deploy.sh --force
EOF
