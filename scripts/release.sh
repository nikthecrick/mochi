#!/usr/bin/env bash
# Mochi — build, zip, and publish a GitHub release.
# Usage: ./scripts/release.sh 1.0.0
# Requires: gh (GitHub CLI), already authenticated
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="${1:-}"
if [[ -z "$VERSION" ]]; then
    echo "Usage: $0 <version>  (e.g. 1.0.0)"
    exit 1
fi

echo "==> building Mochi.app"
./scripts/build.sh

ZIP="Mochi-${VERSION}.zip"
echo "==> zipping -> $ZIP"
# Remove quarantine attribute so users don't have to right-click → Open
ditto -c -k --keepParent Mochi.app "$ZIP"

echo "==> creating GitHub release v${VERSION}"
gh release create "v${VERSION}" "$ZIP" \
    --title "Mochi v${VERSION}" \
    --notes "$(cat <<NOTES
## Download

Grab **${ZIP}** below, unzip, and drag **Mochi.app** to your Applications folder (or anywhere you like).

**First launch:** right-click Mochi.app → Open, then click Open in the dialog.
macOS flags apps that weren't downloaded from the App Store; this dismisses it once.

**Optional — browser tab feeding:**
Mochi can close browser tabs when you drag them onto it.
System Settings → Privacy & Security → Automation → allow Mochi to control your browser.

## Build from source

\`\`\`sh
./scripts/build.sh
open Mochi.app
\`\`\`
NOTES
)"

echo "==> done: https://github.com/$(gh repo view --json nameWithOwner -q .nameWithOwner)/releases/tag/v${VERSION}"
