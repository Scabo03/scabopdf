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
#   5. giudica i CONFINI DI PAROLA contro l'oracolo PyMuPDF (parole con lettere), per generazione.
#
# Uso:  app/ios/scripts/rete_generazioni.sh <etichetta> [--no-capture] [--all-pages] [--controllo-diverso-atteso]
#   <etichetta>    nome della fotografia (es. `base`, `cura_spazi`): le uscite vanno in
#                  <lab>/estrazioni/<etichetta>_<gen>/ e <lab>/letture/<etichetta>_<gen>/
#   --no-capture   riusa estrazioni già catturate con questa etichetta (solo letture e giudici)
#   --all-pages    l'oracolo giudica anche le pagine identiche fra le due generazioni (lento)
#   --controllo-diverso-atteso  il controllo (Marotta) PUÒ differire dalla base: la differenza è dichiarata e giudicata
#                  a parte (es. una cura che gli toglie un'intestazione vuota); il passo [4] la segnala senza fare rosso
#
# Variabili d'ambiente (con default): SCABO_CORPUS (~/Developer/scabopdf-triple-take, i PDF: MAI nel repo),
# SCABO_GEN_LAB (~/Developer/scabopdf-gen-lab, uscite e linee di base), SCABO_TOOLS_PY (python del venv
# con PyMuPDF: ~/Developer/scabopdf-tools-venv/bin/python), SCABO_LISTA (lista dei volumi, default la
# lista dei 52 in scripts/generazioni/lista_volumi.json), SCABO_CONTROLLO (default originals/Marotta), SCABO_GENS (le due
# generazioni «runtime:sigla», default "26.5:ios265 27.0:ios27").
# Codici d'uscita: 0 tutto verde (o nessuna linea di base da confrontare), 1 Marotta cambiato o lettura
# fallita, 2 prerequisito mancante. Ogni passo stampa il proprio codice d'uscita.
#
set -uo pipefail
export DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"

TAG="${1:-}"; [ -n "$TAG" ] || { echo "uso: $0 <etichetta> [--no-capture] [--all-pages]"; exit 2; }
shift
CAPTURE=1; ALLPAGES=""; CONTROLLO_ATTESO=0
for a in "$@"; do case "$a" in --no-capture) CAPTURE=0;; --all-pages) ALLPAGES="--all";; --controllo-diverso-atteso) CONTROLLO_ATTESO=1;; esac; done

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

[ -d "$CORPUS" ] || { echo "corpus assente: $CORPUS"; exit 2; }
[ -x "$PY" ] || { echo "python degli strumenti assente: $PY"; exit 2; }
"$PY" -c "import fitz" 2>/dev/null || { echo "PyMuPDF assente nel venv $PY"; exit 2; }
[ -f "$LISTA" ] || { echo "lista volumi assente: $LISTA"; exit 2; }
mkdir -p "$LAB/estrazioni" "$LAB/letture" "$LAB/logs" "$LAB/reti"
RC=0
N_ATTESI=$("$PY" -c "import json; print(len(json.load(open('$LISTA'))))")

say() { printf '%s\n' "$*"; }

# ── 1. cattura ───────────────────────────────────────────────────────────────────────────────────
if [ "$CAPTURE" = 1 ]; then
  for g in "${GENS[@]}"; do
    RT="${g%%:*}"; GEN="${g##*:}"
    OUT="$LAB/estrazioni/${TAG}_$GEN"; mkdir -p "$OUT/originals" "$OUT/originals_new" "$OUT/originals_maint"
    SCABO_REQ_CORPUS="$CORPUS" SCABO_REQ_OUT="$OUT" SCABO_REQ_LISTA="$LISTA" "$PY" -c "import json, os; e = os.environ; print(json.dumps({'corpusDir': e['SCABO_REQ_CORPUS'], 'outDir': e['SCABO_REQ_OUT'], 'pdfs': json.load(open(e['SCABO_REQ_LISTA']))}))" > /tmp/scabo_extraction_request.json
    xcrun simctl shutdown all >/dev/null 2>&1
    xcodebuild test -project "$PROJECT" -scheme ScaboApp -destination "platform=iOS Simulator,name=$DEVICE,OS=$RT" \
      -only-testing:ScaboAppTests/RealPdfBenchTests/test_extractionDump_fromRequest \
      CODE_SIGNING_ALLOWED=NO -derivedDataPath "/tmp/scabo_dd_rete_$GEN" > "$LAB/logs/${TAG}_cattura_$GEN.log" 2>&1
    rc=$?; n=$(find "$OUT" -name '*.extraction.json' | wc -l | tr -d ' ')
    say "[1] cattura $GEN (iOS $RT): exit=$rc, estrazioni=$n/$N_ATTESI (log $LAB/logs/${TAG}_cattura_$GEN.log)"
    [ "$rc" = 0 ] && [ "$n" = "$N_ATTESI" ] || { RC=1; say "    ROSSO: cattura incompleta o fallita"; }
  done
  rm -f /tmp/scabo_extraction_request.json
else
  for g in "${GENS[@]}"; do
    GEN="${g##*:}"; n=$(find -L "$LAB/estrazioni/${TAG}_$GEN" -name '*.extraction.json' 2>/dev/null | wc -l | tr -d ' ')
    say "[1] cattura saltata (--no-capture): riuso $LAB/estrazioni/${TAG}_$GEN, estrazioni=$n/$N_ATTESI"
    [ "$n" = "$N_ATTESI" ] || { echo "estrazioni mancanti per $GEN"; exit 2; }
  done
fi

# ── 2. runner a HEAD + letture ───────────────────────────────────────────────────────────────────
[ -d "$RUNNER_SRC" ] || { echo "runner dell'officina assente: $RUNNER_SRC"; exit 2; }
RUNNER_DIR="$LAB/runner"; mkdir -p "$RUNNER_DIR"
rsync -a --exclude .build "$RUNNER_SRC/" "$RUNNER_DIR/"
# il runner dipende da ScaboCore per percorso: lo si punta allo ScaboCore di QUESTO repo (a HEAD)
"$PY" - "$RUNNER_DIR/Package.swift" "$REPO_ROOT/app/ios/ScaboCore" <<'PYEOF'
import re, sys
p, core = sys.argv[1], sys.argv[2]
s = open(p).read()
s = re.sub(r'\.package\(path:\s*"[^"]*ScaboCore"\)', '.package(path: "%s")' % core, s)
open(p, "w").write(s)
PYEOF
( cd "$RUNNER_DIR" && swift build -c release > "$LAB/logs/${TAG}_runner_build.log" 2>&1 ); rc=$?
say "[2] runner compilato a HEAD $(cd "$REPO_ROOT" && git rev-parse --short HEAD): exit=$rc"
[ "$rc" = 0 ] || exit 1
R="$RUNNER_DIR/.build/release/ultrafocus-runner"
for g in "${GENS[@]}"; do
  GEN="${g##*:}"; SRC="$LAB/estrazioni/${TAG}_$GEN"; OUT="$LAB/letture/${TAG}_$GEN"; err=0; n=0
  for sub in originals originals_new originals_maint; do
    mkdir -p "$OUT/$sub"
    for ext in "$SRC/$sub"/*.extraction.json; do
      [ -e "$ext" ] || continue
      stem="$(basename "$ext" .extraction.json)"; n=$((n+1))
      "$R" build --extraction "$ext" --source-name "$stem.pdf" --out "$OUT/$sub/$stem.doc.json" >/dev/null 2>&1 || { err=1; say "    ERR build $GEN $sub/$stem"; }
      "$R" segments --document "$OUT/$sub/$stem.doc.json" --extraction "$ext" --out "$OUT/$sub/$stem.reading.json" >/dev/null 2>&1 || { err=1; say "    ERR segments $GEN $sub/$stem"; }
    done
  done
  say "[2] letture $GEN: $n volumi, exit=$err"
  [ "$err" = 0 ] || RC=1
done

# ── 3. parità con la linea di base della stessa generazione, e fra generazioni ──────────────────
for g in "${GENS[@]}"; do
  GEN="${g##*:}"; BASE="$LAB/letture/base_$GEN"; CUR="$LAB/letture/${TAG}_$GEN"
  if [ -d "$BASE" ] && [ "$BASE" != "$CUR" ]; then
    "$PY" "$SCRIPT_DIR/generazioni/parita_lettura.py" "$BASE" "$CUR" "$LISTA" "$BASE" "$LAB/estrazioni/${TAG}_$GEN" "$LAB/reti/parita_${TAG}_$GEN" > /dev/null; rc=$?
    say "[3] parità $GEN contro la linea di base: exit=$rc → $LAB/reti/parita_${TAG}_$GEN.md"
    sed -n '3p' "$LAB/reti/parita_${TAG}_$GEN.md" | sed 's/^/      /'
  else
    say "[3] nessuna linea di base per $GEN ($BASE): questa fotografia è la base"
  fi
done
"$PY" "$SCRIPT_DIR/generazioni/parita_lettura.py" "$LAB/letture/${TAG}_ios265" "$LAB/letture/${TAG}_ios27" "$LISTA" "$LAB/letture/${TAG}_ios265" "$LAB/estrazioni/${TAG}_ios265" "$LAB/reti/parita_${TAG}_265_27" > /dev/null; rc=$?
say "[3] parità 26.5 → 27 di questa fotografia: exit=$rc → $LAB/reti/parita_${TAG}_265_27.md"
sed -n '3p' "$LAB/reti/parita_${TAG}_265_27.md" | sed 's/^/      /'

# ── 4. Marotta, il controllo, per generazione ──────────────────────────────────────────────────
for g in "${GENS[@]}"; do
  GEN="${g##*:}"; BASE="$LAB/letture/base_$GEN/$CONTROLLO.reading.json"; CUR="$LAB/letture/${TAG}_$GEN/$CONTROLLO.reading.json"
  if [ -f "$BASE" ] && [ "$BASE" != "$CUR" ]; then
    if cmp -s "$BASE" "$CUR"; then say "[4] controllo $(basename "$CONTROLLO") $GEN: IDENTICO alla linea di base"
    elif [ "$CONTROLLO_ATTESO" = 1 ]; then say "[4] controllo $(basename "$CONTROLLO") $GEN: DIVERSO dalla linea di base — DICHIARATO ATTESO (da giudicare nella parità)"
    else say "[4] controllo $(basename "$CONTROLLO") $GEN: DIVERSO dalla linea di base (vedi parità) — ROSSO"; RC=1; fi
  else
    say "[4] controllo $(basename "$CONTROLLO") $GEN: nessuna linea di base"
  fi
done

# ── 5. confini di parola contro l'oracolo PyMuPDF ──────────────────────────────────────────────
SCABO_CORPUS="$CORPUS" "$PY" "$SCRIPT_DIR/generazioni/oracolo_parole.py" "$LAB/estrazioni/${TAG}_ios265" "$LAB/estrazioni/${TAG}_ios27" "$LISTA" "$LAB/reti/oracolo_${TAG}" $ALLPAGES > /dev/null; rc=$?
say "[5] oracolo confini di parola: exit=$rc → $LAB/reti/oracolo_${TAG}_volumi.md"
grep '^\*\*Totale' "$LAB/reti/oracolo_${TAG}_volumi.md" | sed 's/^/      /'

say ""; say "rete_generazioni $TAG: exit=$RC"
exit $RC
