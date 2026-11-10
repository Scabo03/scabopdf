#!/usr/bin/env bash
#
# rete_generazioni.sh — LA DOPPIA RETE delle generazioni del lettore di sistema, in un comando solo.
#
# Dal 2026-10-06 le reti del progetto hanno doppio riferimento: iOS 27 (principale: è il sistema del
# maintainer e di quasi tutta l'utenza) e iOS 26.5 (secondario: chi non può aggiornare non va lasciato
# indietro). Il lettore PDF di sistema cambia fra generazioni (docs/GENERAZIONI_LETTORE.md), quindi
# ogni rete gira su ENTRAMBE, ciascuna contro la propria linea di base. Il comando:
#
#   1. CATTURA le estrazioni dei volumi della lista con l'estrattore dell'app (banco
#      `test_extractionDump_fromRequest`) sui due simulatori iPad Pro 11-inch (M5) iOS 26.5 e 27.0
#      (~5 minuti per generazione sui 52 volumi);
#   2. compila il RUNNER dell'officina (stessa catena ScaboCore dell'app, a HEAD) e produce le LETTURE
#      (doc.json + reading.json) per ciascuna generazione;
#   3. confronta le letture con la LINEA DI BASE della stessa generazione (cartella `<lab>/letture/base_<gen>`
#      se esiste) → `parita_<etichetta>_<gen>.md` privo di contenuto, e con le letture dell'ALTRA
#      generazione → `parita_<etichetta>_265_27.md`;
#   4. verifica che MAROTTA (volume di controllo) sia identico alla propria linea di base, per generazione;
#   5. giudica i CONFINI DI PAROLA contro l'oracolo PyMuPDF (parole con lettere), per generazione;
#   6. con `--risorse-visive` (giro 2026-10-12): cattura anche le REGIONI del modello d'impaginazione nello stesso
#      passaggio (banco `test_visualRegionsDump_fromRequest`, la catena dell'app), produce una seconda lettura CON le
#      regioni (`<stem>.rv.reading.json`, decisioni della guardia in `<stem>.visual.json`) e giudica che l'elemento
#      «risorsa visiva» sia additivo: tolti gli elementi, la lettura è identica (`rete_risorse_visive.py`). Con
#      SCABO_RV_GIUDICATE=<dir con le letture giudicate> ogni elemento è confrontato con quelli già giudicati. Dal giro
#      «chiusura del capitolo note» (2026-10-18) giudica anche il POSTO di ogni elemento nel flusso contro la verità
#      registrata in `generazioni/verita_posti_risorse_visive.json` (per generazione; altro file con SCABO_RV_POSTI=<file>,
#      nessun giudizio del posto con SCABO_RV_POSTI=no): un elemento spostato, un salto che finisce altrove, un elemento
#      nuovo o uno che manca fanno ROSSO.
#
# Dal giro «prove rifatte e granularità» (2026-11-10, rilievo R19 della revisione del giro «app unica per Mac»: la rete chiudeva
# verde con due passi fermi): OGNI PASSO è verde solo se il suo comando esce con 0 e le sue uscite attese ci sono
# (`generazioni/esiti_passi.sh`); un passo che non si compie fa rossa la rete, col suo nome. Con una generazione sola i passi fra
# generazioni (la parità 26.5 → 27 e l'oracolo) sono «non previsti» e il verdetto lo dice; una linea di base che manca è ROSSA,
# salvo `--senza-base`. Prova al contrario incorporata: SCABO_RETE_GUASTO=ferma:<passo> o togli:<passo> (nomi dei passi nel
# riassunto finale) deve far finire la rete rossa.
#
# Uso:  app/ios/scripts/rete_generazioni.sh <etichetta> [--no-capture] [--all-pages] [--controllo-diverso-atteso] [--risorse-visive]
#                                           [--base <etichetta>] [--senza-base] [--identiche-attese]
#   <etichetta>    nome della fotografia (es. `base`, `cura_spazi`): le uscite vanno in
#                  <lab>/estrazioni/<etichetta>_<gen>/ e <lab>/letture/<etichetta>_<gen>/
#   --no-capture   riusa estrazioni già catturate con questa etichetta (solo letture e giudici)
#   --all-pages    l'oracolo giudica anche le pagine identiche fra le due generazioni (lento)
#   --controllo-diverso-atteso  il controllo (Marotta) PUÒ differire dalla base: la differenza è dichiarata e giudicata
#                  a parte (es. una cura che gli toglie un'intestazione vuota); il passo [4] la segnala senza fare rosso
#   --base <e>     la linea di base delle parità e del controllo: <lab>/letture/<e>_<gen> (predefinita «base»)
#   --senza-base   nessuna linea di base da confrontare (la prima fotografia): le parità e il controllo sono «non previsti»
#   --identiche-attese  un giro d'invarianza: ogni lettura (e, con --risorse-visive, ogni lettura con le risorse) deve essere
#                  IDENTICA AL BYTE a quella della linea di base, altrimenti il passo «identità <gen>» è rosso
#
# Variabili d'ambiente (con default): SCABO_CORPUS (~/Developer/scabopdf-triple-take, i PDF: MAI nel repo),
# SCABO_GEN_LAB (~/Developer/scabopdf-gen-lab, uscite e linee di base), SCABO_TOOLS_PY (python del venv
# con PyMuPDF: ~/Developer/scabopdf-tools-venv/bin/python), SCABO_LISTA (lista dei volumi, default la
# lista dei 52 in scripts/generazioni/lista_volumi.json), SCABO_CONTROLLO (default originals/Marotta), SCABO_GENS (le due
# generazioni «runtime:sigla», default "26.5:ios265 27.0:ios27").
# Codici d'uscita: 0 tutti i passi previsti verdi, 1 almeno un passo rosso (un comando fallito, un'uscita mancante, il controllo
# cambiato, una linea di base assente senza --senza-base, una lettura diversa con --identiche-attese), 2 prerequisito mancante.
# Ogni passo stampa il proprio codice d'uscita; il riassunto finale elenca passi verdi, rossi e non previsti.
#
set -uo pipefail
export DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"

TAG="${1:-}"; [ -n "$TAG" ] || { echo "uso: $0 <etichetta> [--no-capture] [--all-pages] [--risorse-visive] [--base E] [--senza-base] [--identiche-attese]"; exit 2; }
shift
CAPTURE=1; ALLPAGES=""; CONTROLLO_ATTESO=0; RV=0; BASE_TAG="base"; SENZA_BASE=0; IDENTICHE=0
while [ $# -gt 0 ]; do
  case "$1" in
    --no-capture) CAPTURE=0;; --all-pages) ALLPAGES="--all";; --controllo-diverso-atteso) CONTROLLO_ATTESO=1;; --risorse-visive) RV=1;;
    --base) BASE_TAG="${2:?--base vuole il nome della fotografia}"; shift;; --senza-base) SENZA_BASE=1;; --identiche-attese) IDENTICHE=1;;
    *) echo "opzione sconosciuta: $1"; exit 2;;
  esac
  shift
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
PROJECT="$REPO_ROOT/app/ios/ScaboPDF.xcodeproj"
CORPUS="${SCABO_CORPUS:-$HOME/Developer/scabopdf-triple-take}"
LAB="${SCABO_GEN_LAB:-$HOME/Developer/scabopdf-gen-lab}"
PY="${SCABO_TOOLS_PY:-$HOME/Developer/scabopdf-tools-venv/bin/python}"
LISTA="${SCABO_LISTA:-$SCRIPT_DIR/generazioni/lista_volumi.json}"
CONTROLLO="${SCABO_CONTROLLO:-originals/Marotta}"
RUNNER_SRC="${SCABO_RUNNER_SRC:-$CORPUS/ultrafocus_bench/runner}"
DEVICE="iPad Pro 11-inch (M5)"
read -r -a GENS <<< "${SCABO_GENS:-26.5:ios265 27.0:ios27}"
# shellcheck source=generazioni/esiti_passi.sh
source "$SCRIPT_DIR/generazioni/esiti_passi.sh"

[ -d "$CORPUS" ] || { echo "corpus assente: $CORPUS"; exit 2; }
[ -x "$PY" ] || { echo "python degli strumenti assente: $PY"; exit 2; }
"$PY" -c "import fitz" 2>/dev/null || { echo "PyMuPDF assente nel venv $PY"; exit 2; }
[ -f "$LISTA" ] || { echo "lista volumi assente: $LISTA"; exit 2; }
mkdir -p "$LAB/estrazioni" "$LAB/letture" "$LAB/logs" "$LAB/reti"
N_ATTESI=$("$PY" -c "import json; print(len(json.load(open('$LISTA'))))")
# I passi fra le due generazioni chiedono entrambe: iOS 26.5 (ios265) e iOS 27 (ios27).
FRA_GEN=0; GSIGLE=" "; for g in "${GENS[@]}"; do GSIGLE="$GSIGLE${g##*:} "; done
case "$GSIGLE" in *" ios265 "*) case "$GSIGLE" in *" ios27 "*) FRA_GEN=1;; esac;; esac

say() { printf '%s\n' "$*"; }

# Si spegne SOLO il simulatore usato per la generazione (nome $DEVICE, iOS $1), per UDID: mai «shutdown all», perché sullo
# stesso Mac possono girare i simulatori di altre sessioni (giro «costruzione della linea Mac», 2026-10-16).
sim_udid() {
  "$PY" - "$DEVICE" "$1" <<'PYEOF2'
import json, subprocess, sys
name, rt = sys.argv[1], sys.argv[2]
out = subprocess.run(["xcrun", "simctl", "list", "devices", "-j"], capture_output=True, text=True).stdout
key = "com.apple.CoreSimulator.SimRuntime.iOS-" + rt.replace(".", "-")
for dev in json.loads(out)["devices"].get(key, []):
    if dev["name"] == name and dev.get("isAvailable", True):
        print(dev["udid"]); break
PYEOF2
}
shutdown_sim() { local u; u="$(sim_udid "$1")"; [ -n "$u" ] && xcrun simctl shutdown "$u" >/dev/null 2>&1; return 0; }

# ── 1. cattura ───────────────────────────────────────────────────────────────────────────────────
if [ "$CAPTURE" = 1 ]; then
  for g in "${GENS[@]}"; do
    RT="${g%%:*}"; GEN="${g##*:}"
    OUT="$LAB/estrazioni/${TAG}_$GEN"; mkdir -p "$OUT/originals" "$OUT/originals_new" "$OUT/originals_maint"
    SCABO_REQ_CORPUS="$CORPUS" SCABO_REQ_OUT="$OUT" SCABO_REQ_LISTA="$LISTA" "$PY" -c "import json, os; e = os.environ; print(json.dumps({'corpusDir': e['SCABO_REQ_CORPUS'], 'outDir': e['SCABO_REQ_OUT'], 'pdfs': json.load(open(e['SCABO_REQ_LISTA']))}))" > /tmp/scabo_extraction_request.json
    ONLY=(-only-testing:ScaboAppTests/RealPdfBenchTests/test_extractionDump_fromRequest)
    if [ "$RV" = 1 ]; then
      cp /tmp/scabo_extraction_request.json /tmp/scabo_regions_request.json
      ONLY+=(-only-testing:ScaboAppTests/RealPdfBenchTests/test_visualRegionsDump_fromRequest)
    fi
    shutdown_sim "$RT"
    # Si contano solo le estrazioni scritte da QUESTA cattura (una cartella già usata ne avrebbe di vecchie).
    SEGNO="$LAB/logs/.inizio_cattura_${TAG}_$GEN"; : > "$SEGNO"; /bin/sleep 1
    esegui_passo "cattura $GEN" xcodebuild test -project "$PROJECT" -scheme ScaboApp -destination "platform=iOS Simulator,name=$DEVICE,OS=$RT" \
      "${ONLY[@]}" \
      CODE_SIGNING_ALLOWED=NO -derivedDataPath "/tmp/scabo_dd_rete_$GEN" > "$LAB/logs/${TAG}_cattura_$GEN.log" 2>&1
    rc=$?; n=$(find "$OUT" -name '*.extraction.json' -newer "$SEGNO" | wc -l | tr -d ' ')
    say "[1] cattura $GEN (iOS $RT): exit=$rc, estrazioni=$n/$N_ATTESI (log $LAB/logs/${TAG}_cattura_$GEN.log)"
    chiudi_passo_conteggio "cattura $GEN" "$rc" "$N_ATTESI" "$n"
    if [ "$RV" = 1 ]; then
      nr=$(find "$OUT" -name '*.regions.json' -newer "$SEGNO" | wc -l | tr -d ' ')
      say "[1] regioni $GEN (iOS $RT): $nr/$N_ATTESI"
      chiudi_passo_conteggio "regioni $GEN" "$rc" "$N_ATTESI" "$nr"
    fi
    shutdown_sim "$RT"
    rm -f "$SEGNO"
  done
  rm -f /tmp/scabo_extraction_request.json /tmp/scabo_regions_request.json
else
  for g in "${GENS[@]}"; do
    GEN="${g##*:}"; n=$(find -L "$LAB/estrazioni/${TAG}_$GEN" -name '*.extraction.json' 2>/dev/null | wc -l | tr -d ' ')
    say "[1] cattura saltata (--no-capture): riuso $LAB/estrazioni/${TAG}_$GEN, estrazioni=$n/$N_ATTESI"
    [ "$n" = "$N_ATTESI" ] || { echo "estrazioni mancanti per $GEN"; exit 2; }
    non_previsto "cattura $GEN" "--no-capture: si riusano le estrazioni di $LAB/estrazioni/${TAG}_$GEN"
  done
fi

# ── 2. runner a HEAD + letture ───────────────────────────────────────────────────────────────────
[ -d "$RUNNER_SRC" ] || { echo "runner dell'officina assente: $RUNNER_SRC"; exit 2; }
RUNNER_DIR="$LAB/runner"; mkdir -p "$RUNNER_DIR"
rsync -a --exclude .build "$RUNNER_SRC/" "$RUNNER_DIR/"
# il runner dipende da ScaboCore per percorso: lo si punta allo ScaboCore di QUESTO repo (a HEAD)
"$PY" - "$RUNNER_DIR/Package.swift" "$REPO_ROOT/app/ios/ScaboCore" <<'PYEOF2'
import re, sys
p, core = sys.argv[1], sys.argv[2]
s = open(p).read()
s = re.sub(r'\.package\(path:\s*"[^"]*ScaboCore"\)', '.package(path: "%s")' % core, s)
open(p, "w").write(s)
PYEOF2
R="$RUNNER_DIR/.build/release/ultrafocus-runner"
( cd "$RUNNER_DIR" && esegui_passo "runner" swift build -c release > "$LAB/logs/${TAG}_runner_build.log" 2>&1 ); rc=$?
say "[2] runner compilato a HEAD $(cd "$REPO_ROOT" && git rev-parse --short HEAD): exit=$rc"
chiudi_passo "runner" "$rc" "$R" || { esito_rete "rete_generazioni" "$TAG"; exit 1; }
for g in "${GENS[@]}"; do
  GEN="${g##*:}"; SRC="$LAB/estrazioni/${TAG}_$GEN"; OUT="$LAB/letture/${TAG}_$GEN"; err=0; n=0
  leggi() {
    local sub ext stem
    for sub in originals originals_new originals_maint; do
      mkdir -p "$OUT/$sub"
      for ext in "$SRC/$sub"/*.extraction.json; do
        [ -e "$ext" ] || continue
        stem="$(basename "$ext" .extraction.json)"; n=$((n+1))
        "$R" build --extraction "$ext" --source-name "$stem.pdf" --out "$OUT/$sub/$stem.doc.json" >/dev/null 2>&1 || { err=1; say "    ERR build $GEN $sub/$stem"; }
        "$R" segments --document "$OUT/$sub/$stem.doc.json" --extraction "$ext" --out "$OUT/$sub/$stem.reading.json" >/dev/null 2>&1 || { err=1; say "    ERR segments $GEN $sub/$stem"; }
        if [ "$RV" = 1 ]; then
          reg="$SRC/$sub/$stem.regions.json"
          [ -f "$reg" ] || { err=1; say "    ERR regioni assenti $GEN $sub/$stem"; continue; }
          "$R" segments --document "$OUT/$sub/$stem.doc.json" --extraction "$ext" --regions "$reg" \
            --visual-report "$OUT/$sub/$stem.visual.json" --visual-elements "$OUT/$sub/$stem.visual_elements.json" \
            --out "$OUT/$sub/$stem.rv.reading.json" >/dev/null 2>&1 || { err=1; say "    ERR segments rv $GEN $sub/$stem"; }
        fi
      done
    done
    return $err
  }
  # Si contano solo le letture scritte da QUESTO passo (una fotografia rifatta avrebbe quelle di prima).
  SEGNO="$LAB/logs/.inizio_letture_${TAG}_$GEN"; : > "$SEGNO"; /bin/sleep 1
  esegui_passo "letture $GEN" leggi; rc=$?
  nl=$(find "$OUT" -name '*.reading.json' ! -name '*.rv.reading.json' -newer "$SEGNO" | wc -l | tr -d ' ')
  say "[2] letture $GEN: $n volumi, letture $nl/$N_ATTESI, exit=$rc"
  chiudi_passo_conteggio "letture $GEN" "$rc" "$N_ATTESI" "$nl"
  if [ "$RV" = 1 ]; then
    nrv=$(find "$OUT" -name '*.rv.reading.json' -newer "$SEGNO" | wc -l | tr -d ' ')
    chiudi_passo_conteggio "letture con le risorse $GEN" "$rc" "$N_ATTESI" "$nrv"
  fi
  rm -f "$SEGNO"
done

# ── 3. parità con la linea di base della stessa generazione, e fra generazioni ──────────────────
for g in "${GENS[@]}"; do
  GEN="${g##*:}"; BASE="$LAB/letture/${BASE_TAG}_$GEN"; CUR="$LAB/letture/${TAG}_$GEN"; MD="$LAB/reti/parita_${TAG}_$GEN.md"
  if [ "$BASE" = "$CUR" ]; then
    non_previsto "parità $GEN" "questa fotografia è la linea di base"
  elif [ -d "$BASE" ]; then
    esegui_passo "parità $GEN" "$PY" "$SCRIPT_DIR/generazioni/parita_lettura.py" "$BASE" "$CUR" "$LISTA" "$BASE" "$LAB/estrazioni/${TAG}_$GEN" "$LAB/reti/parita_${TAG}_$GEN" > /dev/null; rc=$?
    say "[3] parità $GEN contro la linea di base ${BASE_TAG}: exit=$rc → $MD"
    [ -f "$MD" ] && sed -n '3p' "$MD" | sed 's/^/      /'
    chiudi_passo "parità $GEN" "$rc" "$MD"
    if [ "$IDENTICHE" = 1 ]; then
      esegui_passo "identità $GEN" "$PY" -I - "$BASE" "$CUR" "$LISTA" "$RV" <<'PYEOF2'; rc=$?
import filecmp, json, os, sys
base, cur, lista, rv = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4] == "1"
forme = [".reading.json"] + ([".rv.reading.json"] if rv else [])
uguali = diverse = mancanti = 0
for v in json.load(open(lista)):
    for f in forme:
        a, b = f"{base}/{v[:-4]}{f}", f"{cur}/{v[:-4]}{f}"
        if not (os.path.exists(a) and os.path.exists(b)): mancanti += 1
        elif filecmp.cmp(a, b, shallow=False): uguali += 1
        else: diverse += 1
print(f"      identità al byte: {uguali} identiche, {diverse} diverse, {mancanti} mancanti ({len(forme)} forme per volume)")
sys.exit(0 if diverse == 0 and mancanti == 0 and uguali > 0 else 1)
PYEOF2
      say "[3] identità al byte $GEN contro ${BASE_TAG} (--identiche-attese): exit=$rc"
      chiudi_passo "identità $GEN" "$rc"
    fi
  elif [ "$SENZA_BASE" = 1 ]; then
    non_previsto "parità $GEN" "--senza-base: nessuna linea di base da confrontare"
  else
    say "[3] linea di base assente per $GEN: $BASE (con --senza-base, se è voluto)"
    chiudi_passo "parità $GEN" 2
  fi
done
if [ "$FRA_GEN" = 1 ]; then
  MD="$LAB/reti/parita_${TAG}_265_27.md"
  esegui_passo "parità 26.5→27" "$PY" "$SCRIPT_DIR/generazioni/parita_lettura.py" "$LAB/letture/${TAG}_ios265" "$LAB/letture/${TAG}_ios27" "$LISTA" "$LAB/letture/${TAG}_ios265" "$LAB/estrazioni/${TAG}_ios265" "$LAB/reti/parita_${TAG}_265_27" > /dev/null; rc=$?
  say "[3] parità 26.5 → 27 di questa fotografia: exit=$rc → $MD"
  [ -f "$MD" ] && sed -n '3p' "$MD" | sed 's/^/      /'
  chiudi_passo "parità 26.5→27" "$rc" "$MD"
else
  non_previsto "parità 26.5→27" "una generazione sola (SCABO_GENS=${SCABO_GENS:-})"
fi

# ── 4. Marotta, il controllo, per generazione ──────────────────────────────────────────────────
for g in "${GENS[@]}"; do
  GEN="${g##*:}"; BASE="$LAB/letture/${BASE_TAG}_$GEN/$CONTROLLO.reading.json"; CUR="$LAB/letture/${TAG}_$GEN/$CONTROLLO.reading.json"
  if [ "$BASE" = "$CUR" ]; then
    non_previsto "controllo $GEN" "questa fotografia è la linea di base"
  elif [ -f "$BASE" ]; then
    if [ "$RETE_GUASTO" = "ferma:controllo $GEN" ]; then rc=97; echo "    GUASTO DI PROVA: il passo «controllo ${GEN}» non si esegue"
    elif cmp -s "$BASE" "$CUR"; then say "[4] controllo $(basename "$CONTROLLO") $GEN: IDENTICO alla linea di base"; rc=0
    elif [ "$CONTROLLO_ATTESO" = 1 ]; then say "[4] controllo $(basename "$CONTROLLO") $GEN: DIVERSO dalla linea di base — DICHIARATO ATTESO (da giudicare nella parità)"; rc=0
    else say "[4] controllo $(basename "$CONTROLLO") $GEN: DIVERSO dalla linea di base (vedi parità) — ROSSO"; rc=1; fi
    chiudi_passo "controllo $GEN" "$rc" "$CUR"
  elif [ "$SENZA_BASE" = 1 ]; then
    non_previsto "controllo $GEN" "--senza-base"
  else
    say "[4] controllo $(basename "$CONTROLLO") $GEN: linea di base assente ($BASE)"
    chiudi_passo "controllo $GEN" 2
  fi
done

# ── 5. confini di parola contro l'oracolo PyMuPDF ──────────────────────────────────────────────
if [ "$FRA_GEN" = 1 ]; then
  MD="$LAB/reti/oracolo_${TAG}_volumi.md"
  SCABO_CORPUS="$CORPUS" esegui_passo "oracolo" "$PY" "$SCRIPT_DIR/generazioni/oracolo_parole.py" "$LAB/estrazioni/${TAG}_ios265" "$LAB/estrazioni/${TAG}_ios27" "$LISTA" "$LAB/reti/oracolo_${TAG}" $ALLPAGES > /dev/null; rc=$?
  say "[5] oracolo confini di parola: exit=$rc → $MD"
  [ -f "$MD" ] && grep '^\*\*Totale' "$MD" | sed 's/^/      /'
  chiudi_passo "oracolo" "$rc" "$MD"
else
  non_previsto "oracolo" "una generazione sola: l'oracolo giudica le pagine che cambiano fra 26.5 e 27"
fi

# ── 6. risorse visive: additive (identità tolti gli elementi), per generazione ──────────────────
if [ "$RV" = 1 ]; then
  for g in "${GENS[@]}"; do
    GEN="${g##*:}"; GIUD=(); MD="$LAB/reti/risorse_visive_${TAG}_$GEN.md"
    [ -n "${SCABO_RV_GIUDICATE:-}" ] && GIUD=(--giudicate "${SCABO_RV_GIUDICATE//\{gen\}/$GEN}")
    POSTI="${SCABO_RV_POSTI:-$SCRIPT_DIR/generazioni/verita_posti_risorse_visive.json}"
    rc_posti=0
    if [ "$POSTI" != no ]; then
      [ -f "$POSTI" ] || { say "    verità del posto assente: $POSTI"; rc_posti=2; }
      GIUD+=(--posti "$POSTI" --gen "$GEN")
    fi
    # ${GIUD[@]+…}: con «set -u» la bash 3.2 di macOS tratta l'array vuoto come variabile non definita.
    esegui_passo "risorse visive $GEN" "$PY" "$SCRIPT_DIR/generazioni/rete_risorse_visive.py" "$LAB/letture/${TAG}_$GEN" "$LISTA" "$LAB/reti/risorse_visive_${TAG}_$GEN" ${GIUD[@]+"${GIUD[@]}"} > /dev/null; rc=$?
    say "[6] risorse visive $GEN: exit=$rc → $MD"
    [ -f "$MD" ] && grep -E '^(Volumi [0-9]|Giudizio|POSTO)' "$MD" | sed 's/^/      /'
    [ "$rc" = 0 ] && rc=$rc_posti
    chiudi_passo "risorse visive $GEN" "$rc" "$MD"
  done
fi

esito_rete "rete_generazioni" "$TAG"
exit $?
