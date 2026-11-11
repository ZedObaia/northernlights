# Northern Lights

A personal fork of [T3 Code](https://github.com/pingdotgg/t3code), rebranded, running on the devbox
over Tailscale with no T3 Connect. Fork code lives in `nl/`, `apps/server/src/northernlights/` and
`.github/workflows/nl.yml`.

## Brand

`nl/rebrand.sh` turns T3 Code into Northern Lights. It swaps every brand image for `nl/brand/`,
renames "T3 Code" in app, server and test sources, and renames the CLI to `nl` in help and messages.
It is idempotent, and rebrand commits are its output, so never hand-edit a rebranded line: change
the script and re-run it. Hand-written changes are limited to `apps/server/src/server.ts`,
`apps/server/src/relay/AgentAwarenessRelay.ts` and `apps/mobile/app.config.ts`.

## How updates flow

1. `nl.yml` runs nightly (03:00 UTC). It merges upstream's latest stable release and re-runs
   `rebrand.sh`. A conflict in a rebranded file resolves to upstream's version, rebranded again.
   Then it typechecks and pushes `main`. A conflict in a hand-edited file, a `rebrand.sh` failure
   or a failed check opens an `upstream-sync` issue, and syncing pauses until that issue is closed.
2. At 04:30 the devbox runs `nl/deploy.sh`, which rebuilds and restarts the server if `main` moved.
   The restart interrupts any running agent turns.

To deploy right away: `ssh devbox systemctl --user start northernlights-deploy`.

## Host

The devbox runs it as `zeyad`, using the same agent logins and PATH as Paseo. Run
`nl/install-host.sh` there once. It deploys from `~/.northernlights`, a checkout that `deploy.sh`
hard-resets, so never work in it. The app is at `https://devbox.<tailnet>.ts.net:8443`, bound to
localhost and the tailnet only.

- CLI: `nl pair --tailscale --tailscale-serve-port 8443` pairs a device, and `nl auth session list`
  shows paired ones. Other arguments (`nl -ba file`) still reach coreutils `nl`.
- Alerts: set `NL_NTFY_URL=https://ntfy.sh/<long-random-topic>` in `~/.config/northernlights.env`,
  then run `systemctl --user restart northernlights`.

## Phone

`.env.local` (gitignored) sets the app name, bundle ID, Apple team and icon. With the iPhone paired
to Xcode (USB or the same Wi-Fi), run `nl/ios-build.sh [device-udid]` to build Release and install
it. Pairing happens in the app: Add environment, then Scan QR code. Notifications come from the
ntfy app subscribed to the same topic; tapping one opens the thread in Northern.
