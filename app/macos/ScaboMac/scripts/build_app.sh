#!/usr/bin/env bash
#
# build_app.sh — compila ScaboMac e assembla il bundle `ScaboPDF.app` (ScaboPDF per Mac, l'app unica del Mac dal giro «app
# unica per Mac, tappa A», 2026-11-08; prima si chiamava ScaboMac.app) con sandbox attiva.
#
#   uso: scripts/build_app.sh [cartella_di_uscita]      (predefinita: build/)
#
# DUE MODI.
#   * Sviluppo (predefinito): firma LOCALE con l'identità di sviluppo presente nel portachiavi («Apple Development»), oppure ad
#     hoc («-») se assente. È la build da aprire su questo Mac, quella dei test e delle reti.
#   * Distribuzione (dal giro «ScaboPDF per Mac su TestFlight», 2026-11-12; `SCABOMAC_DISTRIBUZIONE=1`): la build per TestFlight
#     e il Mac App Store, nello stesso record dell'app dell'iPad (LAYER2 § 12.16, decisione 15). Firma «Apple Distribution» col
#     certificato del profilo «Mac App Store» (l'identità si sceglie dall'impronta del certificato dentro il profilo: i certificati
#     omonimi nel portachiavi sono tre), profilo incorporato in `Contents/embedded.provisionprofile`, nella firma dell'app
#     l'identificativo dell'app e della squadra (`com.apple.application-identifier`, `com.apple.developer.team-identifier`: senza,
#     TestFlight rifiuta l'app per Mac; fonte: Apple Developer Forums, thread 733942, DTS, 2023), e il pacchetto d'installazione
#     `ScaboPDF.pkg` firmato «3rd Party Mac Developer Installer», che è ciò che si carica. Il servizio di scaricamento ha solo
#     permessi senza profilo (sandbox e rete in uscita) e nessun identificativo nella firma: non gli serve un profilo suo.
#     Variabili: SCABOMAC_BUILD (il numero della build, obbligatorio), SCABOMAC_VERSIONE (predefinita: quella di Info.plist),
#     SCABOMAC_PROFILO (il file del profilo, obbligatorio), SCABOMAC_SQUADRA (predefinita D2KQYQ8YU8);
#     SCABOMAC_SENZA_PACCHETTO=1 si ferma all'app firmata, senza il pacchetto (per esaminarla).
#
# Che cosa c'è dentro (giro «costruzione della linea Mac», 2026-10-16, e giro del 2026-11-12):
#   Contents/MacOS/ScaboMac                      l'app: sandbox, file scelti dall'utente, NESSUNA rete
#   Contents/Frameworks/llama.framework          llama.cpp b11429 (release ufficiale, impronta verificata da
#                                                scripts/prepara_llama.sh): il motore di GLM-OCR dentro l'app
#   Contents/XPCServices/com.scabo.scabopdf.scaricatore.xpc
#                                                il servizio di scaricamento: sandbox e SOLO la rete in uscita
#   Contents/Resources/*.bundle                  risorse dei moduli (catalogo, pagina di prova, modello Heron)
#   Contents/Resources/Audio/*.mp3               i segnali acustici dell'iPad (app/ios/ScaboApp/Audio), copiati qui: un solo
#                                                originale nel repo
#   Contents/Resources/AppIcon.icns              l'icona, fatta qui dall'immagine dell'icona dell'iPad (nessuna copia nel repo)
#   Contents/Resources/PrivacyInfo.xcprivacy     il manifesto della privacy (scripts/PrivacyInfo.xcprivacy)
# Le impostazioni e i pesi scaricati vivono nel CONTENITORE dell'app, mai qui dentro: la firma resta intatta.
set -euo pipefail
cd "$(dirname "$0")/.."
OUT="${1:-build}"
DISTRIBUZIONE="${SCABOMAC_DISTRIBUZIONE:-0}"
SQUADRA="${SCABOMAC_SQUADRA:-D2KQYQ8YU8}"
ID_APP="com.scabo.scabopdf"
FRAMEWORK_SRC="Vendor/llama.xcframework/macos-arm64_x86_64/llama.framework"
[ -d "$FRAMEWORK_SRC" ] || { echo "manca llama.cpp: esegui prima scripts/prepara_llama.sh" >&2; exit 2; }
ICONA_SRC="../../ios/ScaboApp/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png"
[ -f "$ICONA_SRC" ] || { echo "manca l'immagine dell'icona dell'iPad: $ICONA_SRC" >&2; exit 2; }
# I file di lavoro in una cartella sola, tolta all'uscita (anche dopo un problema).
TMPD="$(mktemp -d -t scabomac_build)"
trap 'rm -rf "${TMPD:?}"' EXIT
# Le identità di firma del portachiavi, lette una volta (con `pipefail` un lettore che si ferma presto romperebbe il tubo).
IDENTITA_FIRMA="$(security find-identity -v -p codesigning 2>/dev/null || true)"
IDENTITA_TUTTE="$(security find-identity -v 2>/dev/null || true)"

if [ "$DISTRIBUZIONE" = "1" ]; then
  NUMERO_BUILD="${SCABOMAC_BUILD:?in distribuzione serve SCABOMAC_BUILD, il numero della build}"
  PROFILO="${SCABOMAC_PROFILO:?in distribuzione serve SCABOMAC_PROFILO, il profilo Mac App Store}"
  [ -f "$PROFILO" ] || { echo "il profilo non c'è: $PROFILO" >&2; exit 2; }
  # Il profilo, decodificato: deve essere un profilo Mac App Store dell'identificativo dell'app, e dà il certificato con cui firmare.
  PROFILO_PLIST="$TMPD/profilo.plist"
  security cms -D -i "$PROFILO" > "$PROFILO_PLIST"
  ID_NEL_PROFILO="$(/usr/libexec/PlistBuddy -c "Print :Entitlements:com.apple.application-identifier" "$PROFILO_PLIST")"
  [ "$ID_NEL_PROFILO" = "$SQUADRA.$ID_APP" ] || { echo "il profilo è di $ID_NEL_PROFILO, non di $SQUADRA.$ID_APP" >&2; exit 2; }
  if /usr/libexec/PlistBuddy -c "Print :ProvisionedDevices" "$PROFILO_PLIST" >/dev/null 2>&1; then
    echo "il profilo ha dei dispositivi: non è un profilo Mac App Store" >&2; exit 2
  fi
  IDENTITY="$(/usr/bin/python3 -I -c 'import hashlib, plistlib, sys; p = plistlib.load(open(sys.argv[1], "rb")); print(hashlib.sha1(p["DeveloperCertificates"][0]).hexdigest().upper())' "$PROFILO_PLIST")"
  case "$IDENTITA_FIRMA" in *"$IDENTITY"*) ;; *) echo "nel portachiavi manca l'identità del profilo ($IDENTITY)" >&2; exit 2;; esac
  INSTALLATORE="$(printf '%s\n' "$IDENTITA_TUTTE" | awk -v S="($SQUADRA)" '!f && /3rd Party Mac Developer Installer/ && index($0, S) {print $2; f=1}')"
  [ -n "$INSTALLATORE" ] || { echo "nel portachiavi manca «3rd Party Mac Developer Installer» della squadra" >&2; exit 2; }
else
  IDENTITY="${SCABOMAC_SIGN_IDENTITY:-}"
  if [ -z "$IDENTITY" ]; then
    case "$IDENTITA_FIRMA" in *"Apple Development"*) IDENTITY="Apple Development";; *) IDENTITY="-";; esac
  fi
fi

echo "[1/6] compilazione (release, arm64)"
swift build -c release --arch arm64
BIN=".build/arm64-apple-macosx/release"
[ -x "$BIN/ScaboMac" ] || BIN=".build/release"

APP="$OUT/ScaboPDF.app"
XPC="$APP/Contents/XPCServices/com.scabo.scabopdf.scaricatore.xpc"
echo "[2/6] assemblaggio di $APP"
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
cp scripts/PrivacyInfo.xcprivacy "$APP/Contents/Resources/PrivacyInfo.xcprivacy"
# I suoni dell'iPad (le stesse identità di ScaboCore `AudioSignal`).
mkdir -p "$APP/Contents/Resources/Audio"
cp ../../ios/ScaboApp/Audio/*.mp3 "$APP/Contents/Resources/Audio/"
echo -n "APPL????" > "$APP/Contents/PkgInfo"
# Il servizio di scaricamento.
cp "$BIN/ScaboMacScaricatore" "$XPC/Contents/MacOS/ScaboMacScaricatore"
cp scripts/ScaboMacScaricatore-Info.plist "$XPC/Contents/Info.plist"

echo "[3/6] icona, versione e strumenti di compilazione nell'Info.plist"
# L'icona del Mac dall'immagine dell'icona dell'iPad (1024 punti), nelle misure che il Mac vuole, fino a 512@2x.
SET="$TMPD/AppIcon.iconset"
mkdir -p "$SET"
for n in 16 32 128 256 512; do
  sips -z "$n" "$n" "$ICONA_SRC" --out "$SET/icon_${n}x${n}.png" >/dev/null
  d=$((n * 2)); sips -z "$d" "$d" "$ICONA_SRC" --out "$SET/icon_${n}x${n}@2x.png" >/dev/null
done
iconutil -c icns "$SET" -o "$APP/Contents/Resources/AppIcon.icns"
PB=/usr/libexec/PlistBuddy
VERSIONE="${SCABOMAC_VERSIONE:-$($PB -c "Print :CFBundleShortVersionString" scripts/Info.plist)}"
NUMERO_BUILD="${NUMERO_BUILD:-$($PB -c "Print :CFBundleVersion" scripts/Info.plist)}"
for pl in "$APP/Contents/Info.plist" "$XPC/Contents/Info.plist"; do
  $PB -c "Set :CFBundleShortVersionString $VERSIONE" -c "Set :CFBundleVersion $NUMERO_BUILD" "$pl"
done
# Gli strumenti con cui l'app è compilata, come li scrive Xcode (App Store Connect li legge): Xcode, SDK, sistema della macchina.
SDK_VER="$(xcrun --sdk macosx --show-sdk-version)"
SDK_BUILD="$(xcrun --sdk macosx --show-sdk-build-version)"
XC_VER="$(xcodebuild -version | awk 'NR==1 {print $2}')"
XC_BUILD="$(xcodebuild -version | awk 'NR==2 {print $3}')"
XC_NUM="$(echo "$XC_VER" | awk -F. '{printf "%d%d%d", $1, ($2==""?0:$2), ($3==""?0:$3)}')"
for pl in "$APP/Contents/Info.plist" "$XPC/Contents/Info.plist"; do
  $PB -c "Add :CFBundleSupportedPlatforms array" -c "Add :CFBundleSupportedPlatforms:0 string MacOSX" \
      -c "Add :DTCompiler string com.apple.compilers.llvm.clang.1_0" -c "Add :DTPlatformName string macosx" \
      -c "Add :DTPlatformVersion string $SDK_VER" -c "Add :DTPlatformBuild string $SDK_BUILD" \
      -c "Add :DTSDKName string macosx$SDK_VER" -c "Add :DTSDKBuild string $SDK_BUILD" \
      -c "Add :DTXcode string $XC_NUM" -c "Add :DTXcodeBuild string $XC_BUILD" \
      -c "Add :BuildMachineOSBuild string $(sw_vers -buildVersion)" "$pl"
done
echo "    versione $VERSIONE, build $NUMERO_BUILD; Xcode $XC_VER ($XC_BUILD), SDK macOS $SDK_VER"

ENT_APP="scripts/ScaboMac.entitlements"
if [ "$DISTRIBUZIONE" = "1" ]; then
  cp "$PROFILO" "$APP/Contents/embedded.provisionprofile"
  # I permessi dell'app di sempre, più l'identificativo dell'app e della squadra (gli stessi del profilo).
  ENT_APP="$TMPD/ScaboMac.entitlements"
  cp scripts/ScaboMac.entitlements "$ENT_APP"
  $PB -c "Add :com.apple.application-identifier string $SQUADRA.$ID_APP" \
      -c "Add :com.apple.developer.team-identifier string $SQUADRA" "$ENT_APP"
fi
# Gli attributi estesi dei file copiati (per esempio quelli del Finder sui suoni) non sono ammessi dentro un bundle firmato.
xattr -cr "$APP"
echo "[4/6] firma con «${IDENTITY}», dall'interno verso l'esterno"
codesign --force --sign "$IDENTITY" --timestamp=none "$APP/Contents/Frameworks/llama.framework"
for b in "$APP"/Contents/Resources/*.bundle; do [ -d "$b" ] && codesign --force --sign "$IDENTITY" --timestamp=none "$b"; done
codesign --force --sign "$IDENTITY" --timestamp=none --options runtime \
  --entitlements scripts/ScaboMacScaricatore.entitlements "$XPC"
codesign --force --sign "$IDENTITY" --timestamp=none --options runtime \
  --entitlements "$ENT_APP" "$APP"

echo "[5/6] verifiche della firma e dei permessi"
codesign --verify --deep --strict --verbose=2 "$APP"
app_ent="$(codesign -d --entitlements - --xml "$APP" 2>/dev/null)"
xpc_ent="$(codesign -d --entitlements - --xml "$XPC" 2>/dev/null)"
echo "$app_ent" | grep -q "com.apple.security.app-sandbox" || { echo "l'app non ha la sandbox" >&2; exit 3; }
if echo "$app_ent" | grep -q "com.apple.security.network"; then echo "l'app NON deve avere la rete" >&2; exit 3; fi
echo "$xpc_ent" | grep -q "com.apple.security.app-sandbox" || { echo "il servizio non ha la sandbox" >&2; exit 3; }
echo "$xpc_ent" | grep -q "com.apple.security.network.client" || { echo "il servizio non ha la rete in uscita" >&2; exit 3; }
if echo "$xpc_ent" | grep -q "com.apple.security.network.server"; then echo "il servizio non deve ascoltare" >&2; exit 3; fi
if echo "$xpc_ent" | grep -q "com.apple.application-identifier"; then echo "il servizio non deve avere un identificativo nella firma" >&2; exit 3; fi
echo "    app: sandbox sì, rete no; servizio di scaricamento: sandbox sì, rete in uscita sì"
if [ "$DISTRIBUZIONE" = "1" ]; then
  case "$app_ent" in *"$SQUADRA.$ID_APP"*) ;; *) echo "nella firma dell'app manca l'identificativo" >&2; exit 3;; esac
  # I simboli della build (dSYM) accanto al pacchetto, col numero della build: servono a leggere i rapporti dei crash dei
  # tester (il pacchetto non li porta). Dal binario di SwiftPM, che ha la mappa delle informazioni di debug.
  rm -rf "${OUT:?}/simboli_${VERSIONE}_${NUMERO_BUILD}"
  mkdir -p "$OUT/simboli_${VERSIONE}_${NUMERO_BUILD}"
  dsymutil "$BIN/ScaboMac" -o "$OUT/simboli_${VERSIONE}_${NUMERO_BUILD}/ScaboMac.dSYM"
  dsymutil "$BIN/ScaboMacScaricatore" -o "$OUT/simboli_${VERSIONE}_${NUMERO_BUILD}/ScaboMacScaricatore.dSYM"
  if [ "${SCABOMAC_SENZA_PACCHETTO:-0}" = "1" ]; then echo "[6/6] pronto (senza pacchetto): $APP"; exit 0; fi
  PKG="$OUT/ScaboPDF.pkg"
  rm -f "${PKG:?}"
  echo "[6/6] pacchetto d'installazione $PKG, firmato «3rd Party Mac Developer Installer» ($INSTALLATORE)"
  productbuild --component "$APP" /Applications --sign "$INSTALLATORE" "$PKG"
  pkgutil --check-signature "$PKG" | sed -n '1,4p'
  echo "pronto: $PKG"
else
  echo "[6/6] pronto: $APP  (apri con: open \"$APP\")"
fi
