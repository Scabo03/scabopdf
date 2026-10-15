#!/usr/bin/env bash
#
# build_app.sh — compila ScaboMac e assembla il bundle `ScaboMac.app` con sandbox attiva e firma LOCALE.
#
#   uso: scripts/build_app.sh [cartella_di_uscita]      (predefinita: build/)
#
# SwiftPM non produce bundle `.app`: qui si assembla a mano (Contents/MacOS, Info.plist, risorse del
# pacchetto, entitlement) e si firma con l'identità di sviluppo presente nel keychain («Apple Development»),
# oppure ad hoc («-») se assente. Nessuna registrazione sul portale, nessuna notarizzazione: è la build da
# aprire su questo Mac. Per la distribuzione servirà altro (vedi README.md § «Distribuzione»).
set -euo pipefail
cd "$(dirname "$0")/.."
OUT="${1:-build}"
IDENTITY="${SCABOMAC_SIGN_IDENTITY:-}"
if [ -z "$IDENTITY" ]; then
  if security find-identity -v -p codesigning 2>/dev/null | grep -q "Apple Development"; then IDENTITY="Apple Development"; else IDENTITY="-"; fi
fi

echo "[1/4] compilazione (release, arm64)"
swift build -c release --arch arm64
BIN=".build/arm64-apple-macosx/release"
[ -x "$BIN/ScaboMac" ] || BIN=".build/release"

APP="$OUT/ScaboMac.app"
echo "[2/4] assemblaggio di $APP"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN/ScaboMac" "$APP/Contents/MacOS/ScaboMac"
# Le risorse del pacchetto (catalogo) sono in un bundle a sé che Bundle.module cerca accanto all'eseguibile o in Resources.
for b in "$BIN"/ScaboMac_ScaboMacKit.bundle; do [ -d "$b" ] && cp -R "$b" "$APP/Contents/Resources/"; done
cp scripts/Info.plist "$APP/Contents/Info.plist"
echo -n "APPL????" > "$APP/Contents/PkgInfo"

echo "[3/4] firma con «${IDENTITY}», sandbox attiva (entitlement in scripts/ScaboMac.entitlements)"
for b in "$APP"/Contents/Resources/*.bundle; do [ -d "$b" ] && codesign --force --sign "$IDENTITY" "$b"; done
codesign --force --sign "$IDENTITY" --entitlements scripts/ScaboMac.entitlements --options runtime "$APP"
codesign --verify --strict --verbose=2 "$APP"
codesign -d --entitlements - "$APP" 2>&1 | grep -q "com.apple.security.app-sandbox" && echo "    sandbox: sì"

echo "[4/4] pronto: $APP  (apri con: open \"$APP\")"
