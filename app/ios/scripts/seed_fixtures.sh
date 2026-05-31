#!/usr/bin/env bash
# Pre-seed the private PDF fixtures onto a booted Simulator so the test layers
# can read them on-device. The PDFs themselves stay gitignored (copyright); this
# mechanism is committed.
#
# Usage:
#   app/ios/scripts/seed_fixtures.sh [options]
#
# Options:
#   --source DIR     Source fixtures directory (default: app/fixtures-private)
#   --dest TARGET    Where to seed: "app" (default) seeds the app's own data
#                    container at Documents/<subdir>, readable by the app-hosted
#                    XCTest unit tests. "files" seeds the Simulator's local Files
#                    provider for the document-picker flow (the future XCUITest)
#                    — see the note below; finalised in the Mac session.
#   --bundle-id ID   App bundle id (default: com.scabo.scabopdf)
#   --device UDID    Simulator (default: "booted")
#   --subdir NAME    Subdirectory under Documents (default: scabo-fixtures)
#   -h, --help       Show this help.
#
# Design — one interface, two consumers:
#   * The app-hosted unit test (ScaboPDFExtractionTests) reads from the app
#     container, so "--dest app" is its pre-step. Verified on the sandbox.
#   * The future XCUITest drives the real document picker, which browses the
#     Files app, not the app container. Picker-visible seeding ("--dest files")
#     needs either the app to expose its Documents in Files
#     (UIFileSharingEnabled + LSSupportsOpeningDocumentsInPlace — a production
#     Info.plist change to confirm) or a write into the local File Provider
#     storage. That is left for the Mac/XCUITest session; this script's "files"
#     branch is a clearly-marked stub so the interface is stable now.
#
# Idempotent: re-running overwrites the seeded copies and never duplicates.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"   # .../app

SOURCE_DIR="${APP_DIR}/fixtures-private"
DEST="app"
BUNDLE_ID="com.scabo.scabopdf"
DEVICE="booted"
SUBDIR="scabo-fixtures"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --source) SOURCE_DIR="$2"; shift 2;;
    --dest) DEST="$2"; shift 2;;
    --bundle-id) BUNDLE_ID="$2"; shift 2;;
    --device) DEVICE="$2"; shift 2;;
    --subdir) SUBDIR="$2"; shift 2;;
    -h|--help) sed -n '2,40p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0;;
    *) echo "Unknown option: $1" >&2; exit 2;;
  esac
done

if [[ ! -d "$SOURCE_DIR" ]]; then
  echo "ERROR: source fixtures directory not found: $SOURCE_DIR" >&2
  echo "       (the private PDFs are gitignored; place them there first)" >&2
  exit 1
fi

shopt -s nullglob
PDFS=("$SOURCE_DIR"/*.pdf "$SOURCE_DIR"/*.PDF)
shopt -u nullglob
if [[ ${#PDFS[@]} -eq 0 ]]; then
  echo "ERROR: no PDF files in $SOURCE_DIR" >&2
  exit 1
fi

case "$DEST" in
  app)
    # Resolve the app's data container on the Simulator and seed Documents.
    if ! CONTAINER="$(xcrun simctl get_app_container "$DEVICE" "$BUNDLE_ID" data 2>/dev/null)"; then
      echo "ERROR: could not resolve data container for $BUNDLE_ID on $DEVICE." >&2
      echo "       Is the app installed on the booted Simulator?" >&2
      exit 1
    fi
    TARGET_DIR="${CONTAINER}/Documents/${SUBDIR}"
    mkdir -p "$TARGET_DIR"
    count=0
    for pdf in "${PDFS[@]}"; do
      cp -f "$pdf" "$TARGET_DIR/"
      count=$((count + 1))
    done
    echo "Seeded ${count} PDF(s) into the app container:"
    echo "  ${TARGET_DIR}"
    echo "Hosted XCTest reads them from Documents/${SUBDIR}/."
    ;;

  files)
    echo "ERROR: --dest files is not finalised yet." >&2
    echo "       The document-picker flow (future XCUITest on a non-sandbox Mac)" >&2
    echo "       will seed the local Files provider. Decide then between exposing" >&2
    echo "       the app's Documents in Files (UIFileSharingEnabled +" >&2
    echo "       LSSupportsOpeningDocumentsInPlace) and a direct File Provider" >&2
    echo "       write. Use --dest app for the unit-test layer." >&2
    exit 3
    ;;

  *)
    echo "ERROR: unknown --dest '$DEST' (expected: app | files)" >&2
    exit 2
    ;;
esac
