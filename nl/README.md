# Northern Lights

A personal fork of [T3 Code](https://github.com/pingdotgg/t3code). It runs on my own server over Tailscale,
with no T3 Connect. Everything specific to this fork lives in `nl/`, `apps/server/src/northernlights/`
and `.github/workflows/nl.yml`. Upstream files carry only one-line hooks, so upstream merges stay clean.

## How updates flow

1. `nl.yml` runs nightly (03:00 UTC). It merges upstream's latest stable release, typechecks, and pushes `main`.
   A merge conflict or a failed check opens an `upstream-sync` issue, and syncing pauses until that issue is closed.
2. At 04:30 the host runs `nl/deploy.sh`, which rebuilds and restarts the server if `main` moved.
   The restart interrupts any running agent turns.

To deploy your own changes right away: `ssh personal systemctl --user -M nl@ start northernlights-deploy`.

## Host

Run `nl/install-host.sh` as root once. It creates the `nl` user (capped at 4 CPUs and 8 GB),
joins the tailnet, and serves the app at `https://<host>.<tailnet>.ts.net:8443`, bound to localhost only.
Then, as `nl` (`sudo -iu nl`):

- log in to each provider you use, e.g. `claude` or `codex login`;
- put `NL_NTFY_URL=https://ntfy.sh/<long-random-topic>` in `~/.config/northernlights.env`
  then, as root, restart with `systemctl --user -M nl@ restart northernlights`;
- pair a device: `node ~/northernlights/apps/server/dist/bin.mjs pair --tailscale --tailscale-serve-port 8443`.

## Phone

`.env.local` (gitignored) sets the app name, bundle ID and Apple team. Plug in the iPhone, then run:

```sh
cd apps/mobile && vp run ios:release -- --device
```

Rebuild after syncs when you want the new version. Notifications come from the ntfy app: subscribe to
the same topic, and tapping an alert opens the thread in Northern.
