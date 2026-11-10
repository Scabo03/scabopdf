#!/usr/bin/env bash
#
# rete_cure_mirate.sh — LA RETE DELLE CURE MIRATE, da rifare in OGNI giro finché il registro ha delle voci
# (docs/CURE_MIRATE.md § 5; rilievo D1 della revisione indipendente del giro «cure mirate per lo studio», 2026-11-06).
#
# I documenti del registro non sono fra i 52 volumi del banco: senza questa rete una modifica futura del tronco potrebbe
# cambiare la loro lettura senza che nessuno se ne accorga. Per ciascuna generazione (iOS 26.5 e 27):
#   1. cattura i documenti curati (estrazione con l'impronta + regioni del modello) con il banco dell'app;
#   2. compila la catena dell'iPad del laboratorio contro il codice di QUESTO repo e ne produce le letture;
#   3. confronta al byte la lettura curata con il RIFERIMENTO congelato (`<lab>/studio_mirato/riferimento_cure_mirate/
#      dopo_<gen>`): una differenza è ROSSA finché non è giudicata contro la pagina e il riferimento aggiornato di proposito;
#   4. verifica che ogni documento curato passi dal ramo generico (le regole di documento vivono solo lì);
#   5. PROVA AL CONTRARIO: la stessa estrazione con un'impronta non registrata deve dare al byte la stessa lettura che senza
#      impronta (stesso codice), e la lettura curata deve differirne (altrimenti la voce è forse superflua: lo dice).
# I documenti stanno SOLO nel laboratorio, con nomi neutri (`studio_mirato/corpus/studio/<etichetta>.pdf`): mai nel repo.
# Dal giro «rifiniture e cure per capacità» (2026-11-07) la rete porta anche i VOLUMI STABILI fuori dal banco dei 52, senza
# cura mirata (oggi `ignoto_c`, il volume della prova alla cieca, letto con le cure per capacità della build 64): passi 1-3
# come i documenti curati (la loro lettura confrontata al byte col riferimento congelato) e la prova al contrario del
# cancello (un'impronta non registrata dà la stessa lettura che senza impronta); non il confronto «la cura cambia la
# lettura», che per loro non ha senso.
#
# Uso: app/ios/scripts/rete_cure_mirate.sh <etichetta>        (uscite in <lab>/studio_mirato/rete_cure_mirate/<etichetta>)
# Variabile SCABO_GENS (default "26.5:ios265 27.0:ios27"): le generazioni «runtime:sigla», come in rete_generazioni.sh; per un
# giro di livello medio su iOS 27 soltanto, SCABO_GENS="27.0:ios27".
# Codici d'uscita: 0 verde, 1 rosso, 2 prerequisito mancante.
# Dal giro «prove rifatte e granularità» (2026-11-10): ogni passo è verde solo col codice 0 e le uscite attese, con lo schema
# comune `generazioni/esiti_passi.sh` (riassunto finale coi passi rossi per nome; prova al contrario incorporata con
# SCABO_RETE_GUASTO=ferma:<passo> o togli:<passo>).
set -uo pipefail
export DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"
TAG="${1:-}"; [ -n "$TAG" ] || { echo "uso: $0 <etichetta>"; exit 2; }
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
# shellcheck source=generazioni/esiti_passi.sh
source "$SCRIPT_DIR/generazioni/esiti_passi.sh"
LAB="${SCABO_GEN_LAB:-$HOME/Developer/scabopdf-gen-lab}"
SM="$LAB/studio_mirato"
PY="${SCABO_TOOLS_PY:-$HOME/Developer/scabopdf-tools-venv/bin/python}"
DOCS=(studio_a studio_b)
STABILI=(ignoto_c)
TUTTI=("${DOCS[@]}" "${STABILI[@]}")
RIF="$SM/riferimento_cure_mirate"
read -r -a GENS <<< "${SCABO_GENS:-26.5:ios265 27.0:ios27}"
OUT="$SM/rete_cure_mirate/$TAG"
CATENA_SRC="$LAB/frazionamento/strumenti/costruisci_catena.sh"
[ -d "$SM/corpus/studio" ] && [ -d "$RIF" ] && [ -x "$CATENA_SRC" ] || { echo "prerequisiti del laboratorio assenti"; exit 2; }
# Un'etichetta nuova a ogni corsa, come la rete sul parlato e il confronto iPad-Mac: così nessun file di una corsa precedente
# (letture, prove al contrario) entra nei conteggi e nei confronti (rilievo R2 della revisione del giro «prove rifatte e
# granularità», 2026-11-10).
[ -e "$OUT" ] && { echo "l'etichetta «${TAG}» è già usata ($OUT): scegline un'altra"; exit 2; }
mkdir -p "$OUT"
RC=0
say() { printf '%s\n' "$*"; }

# ── 1. cattura (banco dell'app, i due simulatori iPad Pro 11-inch (M5)); spegne solo il proprio simulatore, per UDID ──
"$PY" -c "import json; json.dump(['studio/%s.pdf' % d for d in '${TUTTI[*]}'.split()], open('$OUT/lista.json', 'w'))"
for g in "${GENS[@]}"; do
  RT="${g%%:*}"; GEN="${g##*:}"; C="$OUT/catture_$GEN"; mkdir -p "$C/studio"
  UDID="$(xcrun simctl list devices -j | "$PY" -c "import json,sys; d=json.load(sys.stdin)['devices'].get('com.apple.CoreSimulator.SimRuntime.iOS-${RT//./-}',[]); print(next((x['udid'] for x in d if x['name']=='iPad Pro 11-inch (M5)'),''))")"
  [ -n "$UDID" ] || { say "[1] simulatore iOS $RT assente"; chiudi_passo "cattura $GEN" 2; continue; }
  "$PY" -c "import json; json.dump({'corpusDir': '$SM/corpus', 'outDir': '$C', 'pdfs': json.load(open('$OUT/lista.json'))}, open('/tmp/scabo_extraction_request.json', 'w'))"
  cp /tmp/scabo_extraction_request.json /tmp/scabo_regions_request.json
  xcrun simctl shutdown "$UDID" >/dev/null 2>&1
  SEGNO="$OUT/.inizio_cattura_$GEN"; : > "$SEGNO"; /bin/sleep 1
  esegui_passo "cattura $GEN" xcodebuild test -project "$REPO_ROOT/app/ios/ScaboPDF.xcodeproj" -scheme ScaboApp -destination "platform=iOS Simulator,id=$UDID" \
    -only-testing:ScaboAppTests/RealPdfBenchTests/test_extractionDump_fromRequest \
    -only-testing:ScaboAppTests/RealPdfBenchTests/test_visualRegionsDump_fromRequest \
    CODE_SIGNING_ALLOWED=NO -derivedDataPath "/tmp/scabo_dd_rete_$GEN" -collect-test-diagnostics never > "$OUT/cattura_$GEN.log" 2>&1
  rc=$?; n=$(find "$C" -name '*.extraction.json' -newer "$SEGNO" | wc -l | tr -d ' '); rm -f "$SEGNO"
  say "[1] cattura $GEN: exit=$rc, estrazioni=$n/${#TUTTI[@]}"
  chiudi_passo_conteggio "cattura $GEN" "$rc" "${#TUTTI[@]}" "$n"
  xcrun simctl shutdown "$UDID" >/dev/null 2>&1
done
rm -f /tmp/scabo_extraction_request.json /tmp/scabo_regions_request.json

# ── 2. catena dell'iPad contro il codice di questo repo ──────────────────────────────────────────────────────────────
CAT="$OUT/catena/.build/release/catena-ipad"
esegui_passo "catena" "$CATENA_SRC" "$REPO_ROOT" "$OUT/catena" > "$OUT/catena_build.txt" 2>&1; rc=$?
say "[2] catena compilata a HEAD $(cd "$REPO_ROOT" && git rev-parse --short HEAD): exit=$rc"
chiudi_passo "catena" "$rc" "$CAT" || { esito_rete "rete_cure_mirate" "$TAG"; exit 1; }

for g in "${GENS[@]}"; do
  GEN="${g##*:}"; C="$OUT/catture_$GEN"; L="$OUT/letture_$GEN"; mkdir -p "$L"
  esegui_passo "letture $GEN" "$CAT" --lista "$OUT/lista.json" --estrazioni "$C" --regioni "$C" --out "$L" > "$OUT/letture_$GEN.log" 2>&1; rc=$?
  nl=0; for d in "${TUTTI[@]}"; do [ -s "$L/studio/$d.lettura.json" ] && nl=$((nl + 1)); done
  chiudi_passo_conteggio "letture $GEN" "$rc" "${#TUTTI[@]}" "$nl" || continue
  # ── 3. confronto al byte col riferimento curato (e, per i volumi stabili, col loro riferimento); 4. ramo generico ──
  r3=0; r4=0; n3=0
  for d in "${TUTTI[@]}"; do
    for ext in lettura.json doc.json placed.json reading.json rv.reading.json; do
      n3=$((n3 + 1))
      if [ "$RETE_GUASTO" = "togli:confronto $GEN" ] && [ "$n3" = 1 ]; then rm -f "$L/studio/$d.$ext"; say "    GUASTO DI PROVA: tolta l'uscita «${d}.${ext}» del passo «confronto ${GEN}»"; fi
      cmp -s "$L/studio/$d.$ext" "$RIF/dopo_$GEN/$d.$ext" || { say "[3] ROSSO $GEN $d.$ext diverso dal riferimento curato (o mancante)"; r3=1; }
    done
    pid="$("$PY" -c "import json; print(json.load(open('$L/studio/$d.doc.json'))['profile'].get('profile_id'))" 2>/dev/null)"
    [ "$pid" = generic ] || { say "[4] ROSSO $GEN $d passa dal ramo «${pid}», non dal generico"; r4=1; }
  done
  [ "$RETE_GUASTO" = "ferma:confronto $GEN" ] && { r3=97; say "    GUASTO DI PROVA: il passo «confronto ${GEN}» non si esegue"; }
  [ "$RETE_GUASTO" = "ferma:ramo generico $GEN" ] && { r4=97; say "    GUASTO DI PROVA: il passo «ramo generico ${GEN}» non si esegue"; }
  chiudi_passo "confronto $GEN" "$r3"
  chiudi_passo "ramo generico $GEN" "$r4"
  say "[3-4] $GEN: confronto col riferimento ($n3 file) e ramo verificati"
  # ── 5. prova al contrario: con un'impronta non registrata la lettura è identica, al byte, a quella SENZA impronta (stesso
  #       codice); e la lettura curata ne differisce (se non differisse più, la voce sarebbe superflua: condizione di
  #       rimozione soddisfatta, da dire nel referto). ──
  RC=0   # gli errori delle due letture della prova al contrario di QUESTA generazione
  for variante in contro senza; do
    K="$OUT/${variante}_$GEN"; mkdir -p "$K/studio" "$OUT/letture_${variante}_$GEN"
    for d in "${TUTTI[@]}"; do
      cp "$C/studio/$d.regions.json" "$K/studio/"
      "$PY" -c "import json, hashlib, sys; e = json.load(open('$C/studio/$d.extraction.json')); (e.__setitem__('sourceSha256', hashlib.sha256(b'prova al contrario').hexdigest()) if sys.argv[1] == 'contro' else e.pop('sourceSha256', None)); json.dump(e, open('$K/studio/$d.extraction.json', 'w'))" "$variante"
    done
    esegui_passo "prova al contrario $GEN" "$CAT" --lista "$OUT/lista.json" --estrazioni "$K" --regioni "$K" --out "$OUT/letture_${variante}_$GEN" > /dev/null 2>&1 || RC=1
  done
  r5=0
  for d in "${TUTTI[@]}"; do
    for ext in lettura.json doc.json placed.json reading.json rv.reading.json; do
      cmp -s "$OUT/letture_contro_$GEN/studio/$d.$ext" "$OUT/letture_senza_$GEN/studio/$d.$ext" || { say "[5] ROSSO $GEN $d.$ext: un'impronta non registrata cambia la lettura (o manca)"; r5=1; }
    done
  done
  for d in "${DOCS[@]}"; do
    cmp -s "$L/studio/$d.lettura.json" "$OUT/letture_senza_$GEN/studio/$d.lettura.json" && say "[5] ATTENZIONE $GEN $d: la cura non cambia più la lettura (voce forse superflua)"
  done
  # Un volume stabile non ha cura mirata: con la sua impronta vera la lettura è identica a quella senza impronta.
  for d in "${STABILI[@]}"; do
    cmp -s "$L/studio/$d.lettura.json" "$OUT/letture_senza_$GEN/studio/$d.lettura.json" || { say "[5] ROSSO $GEN $d: il volume stabile cambia con l'impronta (nessuna voce lo prevede)"; r5=1; }
  done
  [ "$RC" = 0 ] || r5=1
  chiudi_passo "prova al contrario $GEN" "$r5"
  say "[5] $GEN: prova al contrario eseguita"
done
esito_rete "rete_cure_mirate" "$TAG"
exit $?
