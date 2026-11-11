#!/bin/sh
# Build Northern (Release) and install it on an iPhone: nl/ios-build.sh [device-udid]
# Signs with the team's wildcard profile, which cannot carry push or associated domains,
# so those entitlements are dropped (alerts come from ntfy; T3's domains can't link here anyway).
set -eu
cd "$(dirname "$0")/../apps/mobile"
export PATH="$HOME/.local/share/vite-plus/bin:$HOME/.local/share/vite-plus/fallback-bin:$PATH"
export APP_VARIANT=production EXPO_NO_GIT_STATUS=1
npx expo prebuild --clean --platform ios
for ent in ios/*/*.entitlements; do
  /usr/libexec/PlistBuddy -c 'Delete :aps-environment' "$ent" 2>/dev/null || true
  /usr/libexec/PlistBuddy -c 'Delete :com.apple.developer.associated-domains' "$ent" 2>/dev/null || true
done
# iOS reuses a cached launch screen until the build number changes, so stamp each build.
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $(date +%Y%m%d%H%M)" ios/Northern/Info.plist
npx expo run:ios --configuration Release --no-bundler --device ${1:+"$1"}
