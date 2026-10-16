#!/usr/bin/env bash
#
# build_app.sh — compila ScaboMac e assembla il bundle `ScaboMac.app` con sandbox attiva e firma LOCALE.
#
#   uso: scripts/build_app.sh [cartella_di_uscita]      (predefinita: build/)
#
# SwiftPM non produce bundle `.app`: qui si assembla a mano e si firma con l'identità di sviluppo presente nel
# keychain («Apple Development»), oppure ad hoc («-») se assente. Nessuna registrazione sul portale, nessuna
# notarizzazione: è la build da aprire su questo Mac. Per la distribuzione servirà altro (README.md § «Distribuzione»).
#
# Che cosa c'è dentro (giro «costruzione della linea Mac», 2026-10-16):
#   Contents/MacOS/ScaboMac                      l'app: sandbox, file scelti dall'utente, NESSUNA rete
#   Contents/Frameworks/llama.framework          llama.cpp b11429 (release ufficiale, impronta verificata da
#                                                scripts/prepara_llama.sh): il motore di GLM-OCR dentro l'app
#   Contents/XPCServices/com.scabo.scabopdf.mac.scaricatore.xpc
#                                                il servizio di scaricamento: sandbox e SOLO la rete in uscita
#   Contents/Resources/*.bundle                  risorse dei moduli (catalogo, pagina di prova, modello Heron)
# Le impostazioni e i pesi scaricati vivono nel CONTENITORE dell'app, mai qui dentro: la firma resta intatta.
set -euo pipefail
cd "$(dirname "$0")/.."
OUT="${1:-build}"
IDENTITY="${SCABOMAC_SIGN_IDENTITY:-}"
if [ -z "$IDENTITY" ]; then
  if security find-identity -v -p codesigning 2>/dev/null | grep -q "Apple Development"; then IDENTITY="Apple Development"; else IDENTITY="-"; fi
fi
FRAMEWORK_SRC="Vendor/llama.xcframework/macos-arm64_x86_64/llama.framework"
[ -d "$FRAMEWORK_SRC" ] || { echo "manca llama.cpp: esegui prima scripts/prepara_llama.sh" >&2; exit 2; }

echo "[1/5] compilazione (release, arm64)"
swift build -c release --arch arm64
BIN=".build/arm64-apple-macosx/release"
[ -x "$BIN/ScaboMac" ] || BIN=".build/release"

APP="$OUT/ScaboMac.app"
XPC="$APP/Contents/XPCServices/com.scabo.scabopdf.mac.scaricatore.xpc"
echo "[2/5] assemblaggio di $APP"
rm -rf "${APP:?}"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$APP/Contents/Frameworks" "$XPC/Contents/MacOS"
cp "$BIN/ScaboMac" "$APP/Contents/MacOS/ScaboMac"
# llama.cpp nel posto canonico dei framework dell'app, e il percorso di ricerca dell'eseguibile verso di esso.
ditto "$FRAMEWORK_SRC" "$APP/Contents/Frameworks/llama.framework"
install_name_tool -add_rpath "@executable_path/../Frameworks" "$APP/Contents/MacOS/ScaboMac"
# Le risorse dei moduli: Bundle.module le cerca in Contents/Resources (mai i bundle dei test).
for b in "$BIN"/*.bundle; do
  case "$b" in *Tests.bundle) continue ;; esac
  [ -d "$b" ] && cp -R "$b" "$APP/Contents/Resources/"
done
cp scripts/Info.plist "$APP/Contents/Info.plist"
echo -n "APPL????" > "$APP/Contents/PkgInfo"
# Il servizio di scaricamento.
cp "$BIN/ScaboMacScaricatore" "$XPC/Contents/MacOS/ScaboMacScaricatore"
cp scripts/ScaboMacScaricatore-Info.plist "$XPC/Contents/Info.plist"

echo "[3/5] firma con «${IDENTITY}», dall'interno verso l'esterno"
codesign --force --sign "$IDENTITY" --timestamp=none "$APP/Contents/Frameworks/llama.framework"
for b in "$APP"/Contents/Resources/*.bundle; do [ -d "$b" ] && codesign --force --sign "$IDENTITY" --timestamp=none "$b"; done
codesign --force --sign "$IDENTITY" --timestamp=none --options runtime \
  --entitlements scripts/ScaboMacScaricatore.entitlements "$XPC"
codesign --force --sign "$IDENTITY" --timestamp=none --options runtime \
  --entitlements scripts/ScaboMac.entitlements "$APP"

echo "[4/5] verifiche della firma e dei permessi"
codesign --verify --deep --strict --verbose=2 "$APP"
app_ent="$(codesign -d --entitlements - --xml "$APP" 2>/dev/null)"
xpc_ent="$(codesign -d --entitlements - --xml "$XPC" 2>/dev/null)"
echo "$app_ent" | grep -q "com.apple.security.app-sandbox" || { echo "l'app non ha la sandbox" >&2; exit 3; }
if echo "$app_ent" | grep -q "com.apple.security.network"; then echo "l'app NON deve avere la rete" >&2; exit 3; fi
echo "$xpc_ent" | grep -q "com.apple.security.app-sandbox" || { echo "il servizio non ha la sandbox" >&2; exit 3; }
echo "$xpc_ent" | grep -q "com.apple.security.network.client" || { echo "il servizio non ha la rete in uscita" >&2; exit 3; }
if echo "$xpc_ent" | grep -q "com.apple.security.network.server"; then echo "il servizio non deve ascoltare" >&2; exit 3; fi
echo "    app: sandbox sì, rete no; servizio di scaricamento: sandbox sì, rete in uscita sì"

echo "[5/5] pronto: $APP  (apri con: open \"$APP\")"
