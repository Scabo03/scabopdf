#!/usr/bin/env bash
#
# confronto_letture_ipad_mac.sh — IL CONFRONTO AUTOMATICO fra la lettura dell'iPad e quella del Mac (giro «fondamenta della lettura
# per Mac», 2026-11-07): è Code, non l'orecchio, a dire se le due letture sono la stessa. Sui libri del banco (i 52 di
# `generazioni/lista_volumi.json`) e sui volumi stabili della rete dei documenti di studio, dalle stesse catture del simulatore:
#   1. la CATENA DELL'IPAD (attrezzo del laboratorio `costruisci_catena.sh`, contro il codice di QUESTO repo) → le letture nella
#      forma della cache;
#   2. la VISTA VERA DELL'IPAD sul simulatore iPad Pro 11-inch (M5) con iOS 27, interrogata dentro il processo (banco
#      `RealPdfBenchTests/test_readingViewDescriptionWalk_fromRequest`): il lettore come lo apre l'app, ogni libro percorso per
#      intero senza tasti né VoiceOver (contenitori, rotori coi loro blocchi di ricerca, ogni elemento materializzato e messo a
#      fuoco in lettura lineare, i gestori delle azioni di navigazione eseguiti per sapere dove portano) → le descrizioni di ciò
#      che la vista ESPONE, più i referti del percorso, giudicati (`generazioni/verifica_percorsi_vista.py`);
#   3. la CATENA DEL MAC a innesto spento (`scabomac-officina catena --politica spenta`), passata nella fonte unica del parlato →
#      le descrizioni di ciò che il Mac dirà per costruzione;
#   4. `scabomac-officina confronta-descrizioni --al-byte`: per ogni libro e flusso coincidono o no, e se no la prima divergenza
#      col suo tipo (elemento mancante o in più, testo pronunciato, valore, ruolo, livello, segnale, rotore, azione, contenitore,
#      testata), senza testo dei volumi nel referto.
# Quando esisterà la vista di lettura del Mac, la sua descrizione (interrogata con XCTest per macOS, che chiede la modalità
# automazione) prenderà il posto del passo 3; il passo 4 resta com'è. Le uscite CONTENGONO TESTO dei volumi: solo nel laboratorio.
#
# Uso: app/ios/scripts/confronto_letture_ipad_mac.sh <etichetta> [--flussi lc|lc,di] [--solo STEM]
#   --flussi   i flussi da percorrere nella vista dell'iPad (predefiniti Lettura Continua e Dottrina Inline: lc,di)
#   --solo     un libro solo, per fine del nome (prova veloce)
# Variabili (con default): SCABO_GEN_LAB (~/Developer/scabopdf-gen-lab), SCABO_CORPUS (~/Developer/scabopdf-triple-take, i PDF del
# banco), SCABO_CATTURE (<lab>/estrazioni/cm1_ios27), SCABO_CATTURE_STUDIO (<lab>/studio_mirato/rete_cure_mirate/p2/catture_ios27),
# SCABO_CORPUS_STUDIO (<lab>/studio_mirato/corpus), SCABO_TOOLS_PY (python del venv degli strumenti, per gli elenchi).
# Codici d'uscita: 0 identiche, 1 diverse o passo fallito, 2 prerequisito mancante. Spegne solo il proprio simulatore, per UDID.
set -uo pipefail
export DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"
TAG="${1:-}"; [ -n "$TAG" ] || { echo "uso: $0 <etichetta> [--flussi lc|lc,di] [--solo STEM]"; exit 2; }
shift
FLUSSI="lc,di"; SOLO=""
while [ $# -gt 0 ]; do case "$1" in --flussi) FLUSSI="$2"; shift 2;; --solo) SOLO="$2"; shift 2;; *) echo "opzione sconosciuta: $1"; exit 2;; esac; done
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
LAB="${SCABO_GEN_LAB:-$HOME/Developer/scabopdf-gen-lab}"
CORPUS="${SCABO_CORPUS:-$HOME/Developer/scabopdf-triple-take}"
CATTURE="${SCABO_CATTURE:-$LAB/estrazioni/cm1_ios27}"
CATTURE_STUDIO="${SCABO_CATTURE_STUDIO:-$LAB/studio_mirato/rete_cure_mirate/p2/catture_ios27}"
CORPUS_STUDIO="${SCABO_CORPUS_STUDIO:-$LAB/studio_mirato/corpus}"
PY="${SCABO_TOOLS_PY:-$HOME/Developer/scabopdf-tools-venv/bin/python}"
CATENA_SRC="$LAB/frazionamento/strumenti/costruisci_catena.sh"
MAC="$REPO_ROOT/app/macos/ScaboMac"
OUT="$LAB/confronto_ipad_mac/$TAG"
[ -e "$OUT" ] && { echo "etichetta già usata: $OUT"; exit 2; }
[ -x "$CATENA_SRC" ] && [ -d "$CATTURE" ] && [ -d "$CORPUS" ] && [ -x "$PY" ] || { echo "prerequisiti del laboratorio assenti"; exit 2; }
[ -d "$MAC/Vendor/llama.xcframework" ] || { echo "manca Vendor/llama.xcframework: app/macos/ScaboMac/scripts/prepara_llama.sh"; exit 2; }
mkdir -p "$OUT/logs"
RC=0
say() { printf '%s\n' "$*"; }

# Gli elenchi: i 52 del banco e i volumi stabili della rete dei documenti di studio (gli stessi di rete_cure_mirate.sh).
"$PY" -I - "$SCRIPT_DIR/generazioni/lista_volumi.json" "$OUT" "$SOLO" "$CATTURE_STUDIO" <<'PYEOF' || exit 2
import json, os, sys
lista, out, solo, cs = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
banco = [v for v in json.load(open(lista)) if not solo or v[:-4].endswith(solo)]
studio = [f"studio/{d}.pdf" for d in ("studio_a", "studio_b", "ignoto_c") if os.path.exists(f"{cs}/studio/{d}.extraction.json")]
studio = [v for v in studio if not solo or v[:-4].endswith(solo)]
json.dump(banco, open(f"{out}/lista_banco.json", "w"), ensure_ascii=False)
json.dump(studio, open(f"{out}/lista_studio.json", "w"), ensure_ascii=False)
print(f"libri: {len(banco)} del banco, {len(studio)} di studio")
PYEOF

# ── 1. catena dell'iPad, contro il codice di questo repo ──
"$CATENA_SRC" "$REPO_ROOT" "$OUT/catena_build" > "$OUT/logs/catena_build.txt" 2>&1; rc=$?
say "[1] catena dell'iPad compilata a HEAD $(cd "$REPO_ROOT" && git rev-parse --short HEAD): exit=$rc"
[ "$rc" = 0 ] || exit 1
CAT="$OUT/catena_build/.build/release/catena-ipad"
"$CAT" --lista "$OUT/lista_banco.json" --estrazioni "$CATTURE" --regioni "$CATTURE" --out "$OUT/letture" > "$OUT/logs/catena_banco.log" 2>&1 || RC=1
if [ "$("$PY" -c "import json; print(len(json.load(open('$OUT/lista_studio.json'))))")" != 0 ]; then
  "$CAT" --lista "$OUT/lista_studio.json" --estrazioni "$CATTURE_STUDIO" --regioni "$CATTURE_STUDIO" --out "$OUT/letture" > "$OUT/logs/catena_studio.log" 2>&1 || RC=1
fi
say "[1] letture dell'iPad: $(find "$OUT/letture" -name '*.lettura.json' | wc -l | tr -d ' '), exit=$RC"

# La richiesta del banco della vista: lettura, impronta (dall'estrazione catturata).
"$PY" -I - "$OUT" "$CATTURE" "$CATTURE_STUDIO" "$FLUSSI" <<'PYEOF' || exit 2
import json, sys
out, cb, cs, flussi = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4].split(",")
letture = []
for lista, cat in ((f"{out}/lista_banco.json", cb), (f"{out}/lista_studio.json", cs)):
    for v in json.load(open(lista)):
        stem = v[:-4]
        letture.append({"libro": stem, "lettura": f"{out}/letture/{stem}.lettura.json",
                        "impronta": json.load(open(f"{cat}/{stem}.extraction.json")).get("sourceSha256")})
json.dump({"letture": letture, "outDir": f"{out}/vista_ipad", "flussi": flussi}, open(f"{out}/richiesta_vista.json", "w"), ensure_ascii=False)
PYEOF

# ── 2. la vista vera dell'iPad, sul proprio simulatore iOS 27 ──
UDID="$(xcrun simctl list devices -j | "$PY" -c "import json,sys; d=json.load(sys.stdin)['devices'].get('com.apple.CoreSimulator.SimRuntime.iOS-27-0',[]); print(next((x['udid'] for x in d if x['name']=='iPad Pro 11-inch (M5)' and x.get('isAvailable', True)),''))")"
[ -n "$UDID" ] || { say "[2] simulatore iPad Pro 11-inch (M5) iOS 27 assente"; exit 2; }
# Si spegne alla fine solo se l'ha avviato questo script (mai un simulatore già acceso da altri).
ACCESO_PRIMA="$(xcrun simctl list devices | grep -c "$UDID) (Booted)")"
[ "$ACCESO_PRIMA" = 0 ] && xcrun simctl boot "$UDID" >/dev/null 2>&1
PBX="$REPO_ROOT/app/ios/ScaboPDF.xcodeproj/project.pbxproj"
( cd "$REPO_ROOT" && git diff --quiet -- "$PBX" ); PBX_PULITO=$?
# La libreria dei test si svuota prima di ogni uso del simulatore (il banco aggiunge e toglie un documento per libro).
xcrun simctl uninstall "$UDID" com.scabo.scabopdf >/dev/null 2>&1
( cd "$REPO_ROOT/app/ios" && xcodebuild build-for-testing -project ScaboPDF.xcodeproj -scheme ScaboApp \
    -destination "platform=iOS Simulator,id=$UDID" -configuration Release ENABLE_TESTABILITY=YES CODE_SIGNING_ALLOWED=NO \
    -derivedDataPath "$OUT/dd" ) > "$OUT/logs/vista_build.log" 2>&1; rc=$?
say "[2] app compilata per il banco (Release, provabile): exit=$rc"
if [ "$rc" = 0 ]; then
  ( cd "$REPO_ROOT/app/ios" && TEST_RUNNER_SCABO_DESCRIZIONI_REQUEST="$OUT/richiesta_vista.json" xcodebuild test-without-building \
      -project ScaboPDF.xcodeproj -scheme ScaboApp -destination "platform=iOS Simulator,id=$UDID" -configuration Release \
      -only-testing:ScaboAppTests/RealPdfBenchTests/test_readingViewDescriptionWalk_fromRequest -derivedDataPath "$OUT/dd" \
      -collect-test-diagnostics never ) > "$OUT/logs/vista.log" 2>&1; rc=$?
  say "[2] vista dell'iPad percorsa: exit=$rc, $(find "$OUT/vista_ipad" -name '*.jsonl' 2>/dev/null | wc -l | tr -d ' ') flussi descritti"
fi
[ "$rc" = 0 ] || RC=1
[ "$ACCESO_PRIMA" = 0 ] && xcrun simctl shutdown "$UDID" >/dev/null 2>&1
# xcodebuild riordina due righe del progetto: si ripristina SOLO se era pulito prima (mai modifiche altrui perse).
[ "$PBX_PULITO" = 0 ] && ( cd "$REPO_ROOT" && git checkout -q -- "$PBX" )
# Il giudice dei referti del percorso: una corsa con un flusso percorso a metà, un layout sbagliato o un rotore interrotto è rossa.
"$PY" -I "$SCRIPT_DIR/generazioni/verifica_percorsi_vista.py" "$OUT/vista_ipad" > "$OUT/percorsi_vista.txt" 2>&1; rc=$?
say "[2] referti del percorso: exit=$rc ($(head -1 "$OUT/percorsi_vista.txt"))"
[ "$rc" = 0 ] || RC=1

# ── 3. la catena del Mac, a innesto spento, nel modulo del parlato ──
( cd "$MAC" && swift build -c release --product scabomac-officina --scratch-path "$OUT/officina_build" ) > "$OUT/logs/officina_build.log" 2>&1; rc=$?
say "[3] scabomac-officina compilata: exit=$rc"
[ "$rc" = 0 ] || exit 1
OFF="$OUT/officina_build/release/scabomac-officina"
"$OFF" catena --lista "$OUT/lista_banco.json" --corpus "$CORPUS" --out "$OUT/mac" --politica spenta --estrazioni "$CATTURE" \
  --regioni "$CATTURE" --lettura --descrizioni "$OUT/mac_descrizioni" > "$OUT/logs/mac_banco.log" 2>&1 || RC=1
if [ "$("$PY" -c "import json; print(len(json.load(open('$OUT/lista_studio.json'))))")" != 0 ]; then
  "$OFF" catena --lista "$OUT/lista_studio.json" --corpus "$CORPUS_STUDIO" --out "$OUT/mac" --politica spenta \
    --estrazioni "$CATTURE_STUDIO" --regioni "$CATTURE_STUDIO" --lettura --descrizioni "$OUT/mac_descrizioni" > "$OUT/logs/mac_studio.log" 2>&1 || RC=1
fi
say "[3] descrizioni del Mac: $(find "$OUT/mac_descrizioni" -name '*.jsonl' | wc -l | tr -d ' '), exit=$RC"

# ── 4. il confronto (solo i flussi percorsi nella vista) ──
mkdir -p "$OUT/mac_confrontate"
( cd "$OUT/mac_descrizioni" && find . -name '*.jsonl' | while IFS= read -r f; do
    for fl in ${FLUSSI//,/ }; do case "$f" in *".$fl.n"*) mkdir -p "$OUT/mac_confrontate/$(dirname "$f")"; cp "$f" "$OUT/mac_confrontate/$f";; esac; done
  done )
"$OFF" confronta-descrizioni --a "$OUT/vista_ipad" --b "$OUT/mac_confrontate" --al-byte --nomi vista-ipad,mac > "$OUT/confronto.txt" 2>&1; rc=$?
say "[4] confronto vista dell'iPad ↔ catena del Mac: exit=$rc (dettagli in $OUT/confronto.txt)"
tail -2 "$OUT/confronto.txt" | sed 's/^/      /'
[ "$rc" = 0 ] || RC=1
say ""; say "confronto_letture_ipad_mac $TAG: exit=$RC"
exit $RC
