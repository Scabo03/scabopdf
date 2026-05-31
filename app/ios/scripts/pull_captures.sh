#!/usr/bin/env bash
# Pull the on-device extraction captures written by the ScaboPDFExtractionTests
# layer (Caches/scabo-extractions/*.capture.json in the app container) to the
# host, where the TypeScript report generator consumes them. The captures carry
# document text (copyright) so they land under the gitignored test-output-private/.
#
# Usage:
#   app/ios/scripts/pull_captures.sh [--bundle-id ID] [--device UDID]
#
# Run after `xcodebuild test -only-testing:ScaboPDFExtractionTests`, then run the
# generator: `npx jest measureRealCaptures` from app/.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"

BUNDLE_ID="com.scabo.scabopdf"
DEVICE="booted"
SUBDIR="scabo-extractions"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --bundle-id) BUNDLE_ID="$2"; shift 2;;
    --device) DEVICE="$2"; shift 2;;
    -h|--help) sed -n '2,12p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0;;
    *) echo "Unknown option: $1" >&2; exit 2;;
  esac
done

if ! CONTAINER="$(xcrun simctl get_app_container "$DEVICE" "$BUNDLE_ID" data 2>/dev/null)"; then
  echo "ERROR: could not resolve data container for $BUNDLE_ID on $DEVICE." >&2
  exit 1
fi

SRC="${CONTAINER}/Library/Caches/${SUBDIR}"
if [[ ! -d "$SRC" ]]; then
  echo "ERROR: no captures at $SRC." >&2
  echo "       Run the extraction unit test first." >&2
  exit 1
fi

DEST="${REPO_ROOT}/test-output-private/extractions"
mkdir -p "$DEST"

count=0
shopt -s nullglob
for cap in "$SRC"/*.capture.json; do
  cp -f "$cap" "$DEST/"
  count=$((count + 1))
done
shopt -u nullglob

echo "Pulled ${count} capture(s) to:"
echo "  ${DEST}"
