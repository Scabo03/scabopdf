#!/usr/bin/env bash
#
# rete_parlato.sh — LA RETE SUL PARLATO (giro «fondamenta della lettura per Mac», 2026-11-07), da rifare in OGNI giro che tocca
# la lettura: la vista, ciò che VoiceOver pronuncia, i rotori, le azioni e dove portano, i segnali acustici.
#
# Il parlato di ogni elemento della lettura viene da una fonte sola, ScaboCore `ReadingSpeech` (`ReadingSpeech.swift`), che
# usano la vista dell'iPad e userà quella del Mac. La rete DESCRIVE ogni elemento (testo pronunciato, valore, ruolo, livello
# d'intestazione, segnale previsto, rotori, azioni con i loro bersagli, contenitore) su letture CONGELATE, le stesse in ogni giro,
# e confronta al byte con il RIFERIMENTO congelato: una modifica della catena non la tocca (gli ingressi sono fermi), una modifica
# del parlato sì. Il riferimento è stato prodotto dalla vista dell'iPad allo HEAD `56aaafe` (build 64), con la logica del parlato di
# prima dello spostamento nel modulo, bersagli dei salti compresi (gestori eseguiti), ed è identico al byte a ciò che dà il modulo.
#
# CHE COSA COPRE. Senza opzioni, il MODULO: (1) compila `scabomac-officina` a HEAD; (2) descrive ogni lettura dell'elenco con il
# modulo, Lettura Continua e Dottrina Inline, «note annunciate a voce» spenta e accesa, VoiceOver spento, e confronta al byte con
# `riferimento/`; (3) lo stesso a VoiceOver ACCESO, confrontato con `riferimento_vo/` (questo riferimento viene dal modulo: nei test
# la vista ha VoiceOver spento, e la differenza è la sola azione «Strumenti elemento»); (4) prova al contrario del confronto.
# Con `--vista` percorre anche la VISTA VERA dell'iPad (banco `test_readingViewDescriptionWalk_fromRequest`, simulatore iPad Pro
# 11-inch (M5) con iOS 27) sulle stesse letture congelate e la confronta al byte con `riferimento/`, giudicando anche i referti del
# percorso: è il passo da fare nei giri che toccano la VISTA dell'iPad (una regressione nella vista, senza `--vista`, resta verde).
# Non coperti al byte, coperti dai test d'unità del modulo: un segnalibro presente, una ricerca attiva, le granularità 600 e 900
# (le letture congelate sono a 400, e a 1200 i volumi enormi).
# Una differenza voluta del parlato si giudica, e il riferimento si aggiorna di proposito (copiando le uscite giudicate), come per
# le altre reti. Le uscite CONTENGONO TESTO dei volumi: stanno solo nel laboratorio.
#
# Uso: app/ios/scripts/rete_parlato.sh <etichetta> [--vista] [--solo STEM]
#   --vista   percorre anche la vista vera dell'iPad sul simulatore (circa 25 minuti per i 55 libri)
#   --solo    un libro solo, per fine del nome (prova veloce)
# Variabili (con default): SCABO_GEN_LAB (~/Developer/scabopdf-gen-lab), SCABO_PARLATO (<lab>/parlato: libri.json, letture/,
# riferimento/, riferimento_vo/), SCABO_TOOLS_PY (python del venv degli strumenti: elenchi, prova al contrario, giudice).
# Codici d'uscita: 0 verde, 1 rosso, 2 prerequisito mancante. Spegne solo il simulatore che ha acceso, per UDID.
# Dal giro «prove rifatte e granularità» (2026-11-10): ogni passo è verde solo col codice 0 e le uscite attese (le descrizioni
# tante quante quelle del riferimento), con lo schema comune `generazioni/esiti_passi.sh`; il riassunto finale dice i passi
# rossi per nome. Prova al contrario incorporata: SCABO_RETE_GUASTO=ferma:<passo> o togli:<passo> deve finire rossa.
set -uo pipefail
export DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"
TAG="${1:-}"; [ -n "$TAG" ] || { echo "uso: $0 <etichetta> [--vista] [--solo STEM]"; exit 2; }
shift
VISTA=0; SOLO=""
while [ $# -gt 0 ]; do case "$1" in --vista) VISTA=1; shift;; --solo) SOLO="$2"; shift 2;; *) echo "opzione sconosciuta: $1"; exit 2;; esac; done
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
# shellcheck source=generazioni/esiti_passi.sh
source "$SCRIPT_DIR/generazioni/esiti_passi.sh"
LAB="${SCABO_GEN_LAB:-$HOME/Developer/scabopdf-gen-lab}"
PAR="${SCABO_PARLATO:-$LAB/parlato}"
PY="${SCABO_TOOLS_PY:-$HOME/Developer/scabopdf-tools-venv/bin/python}"
MAC="$REPO_ROOT/app/macos/ScaboMac"
[ -f "$PAR/libri.json" ] && [ -d "$PAR/riferimento" ] && [ -d "$PAR/riferimento_vo" ] || { echo "prerequisiti del laboratorio assenti in $PAR"; exit 2; }
[ -d "$MAC/Vendor/llama.xcframework" ] || { echo "manca Vendor/llama.xcframework: app/macos/ScaboMac/scripts/prepara_llama.sh"; exit 2; }
[ -x "$PY" ] || { echo "python degli strumenti assente: $PY"; exit 2; }
OUT="$PAR/$TAG"
[ -e "$OUT" ] && { echo "etichetta già usata: $OUT"; exit 2; }
mkdir -p "$OUT"
RC=0
say() { printf '%s\n' "$*"; }
HEADINFO="$(cd "$REPO_ROOT" && git rev-parse --short HEAD)$(cd "$REPO_ROOT" && git diff --quiet HEAD || echo " con modifiche non committate")"

# L'elenco (tutti i libri o uno solo) e i riferimenti corrispondenti, copiati accanto alle uscite.
"$PY" -I - "$PAR" "$OUT" "$SOLO" <<'PYEOF' || exit 2
import json, os, shutil, sys
par, out, solo = sys.argv[1], sys.argv[2], sys.argv[3]
libri = json.load(open(f"{par}/libri.json"))
libri["letture"] = [b for b in libri["letture"] if not solo or b["libro"].endswith(solo)]
if not libri["letture"]: sys.exit(f"nessun libro per «{solo}»")
json.dump(libri, open(f"{out}/libri.json", "w"), ensure_ascii=False)
for ref in ("riferimento", "riferimento_vo"):
    for b in libri["letture"]:
        for k in ("lc.n0", "lc.n1", "di.n0", "di.n1"):
            src = f"{par}/{ref}/{b['libro']}.{k}.jsonl"
            if os.path.exists(src):
                dst = f"{out}/{ref}/{b['libro']}.{k}.jsonl"; os.makedirs(os.path.dirname(dst), exist_ok=True); shutil.copy(src, dst)
print(f"libri: {len(libri['letture'])}")
PYEOF

# ── 1. la riga di comando dell'officina, a HEAD ──
OFF="$PAR/officina_build/release/scabomac-officina"
( cd "$MAC" && esegui_passo "officina" swift build -c release --product scabomac-officina --scratch-path "$PAR/officina_build" ) > "$OUT/officina_build.log" 2>&1
rc=$?; say "[1] scabomac-officina compilata a HEAD $HEADINFO: exit=$rc"
chiudi_passo "officina" "$rc" "$OFF" || { esito_rete "rete_parlato" "$TAG"; exit 1; }

# ── 2-3. le descrizioni del modulo, VoiceOver spento e acceso, confrontate al byte coi riferimenti ──
for passo in modulo modulo_vo; do
  ref="riferimento"; extra=(); [ "$passo" = modulo_vo ] && { ref="riferimento_vo"; extra=(--voiceover); }
  esegui_passo "descrizioni $passo" "$OFF" descrivi --libri "$OUT/libri.json" --out "$OUT/$passo" ${extra[@]+"${extra[@]}"} > "$OUT/descrivi_$passo.log" 2>&1; rc=$?
  nd=$(find "$OUT/$passo" -name '*.jsonl' 2>/dev/null | wc -l | tr -d ' '); nr=$(find "$OUT/$ref" -name '*.jsonl' | wc -l | tr -d ' ')
  chiudi_passo_conteggio "descrizioni $passo" "$rc" "$nr" "$nd"
  esegui_passo "confronto $passo" "$OFF" confronta-descrizioni --a "$OUT/$ref" --b "$OUT/$passo" --al-byte --nomi "$ref,$passo" > "$OUT/confronto_$passo.txt" 2>&1; rc=$?
  say "[2] $passo ($nd descrizioni su $nr del riferimento) contro $ref: exit=$rc"
  tail -2 "$OUT/confronto_$passo.txt" | sed 's/^/      /'
  chiudi_passo "confronto $passo" "$rc" "$OUT/confronto_$passo.txt"
done

# ── 4. prova al contrario: un elemento alterato in una copia deve essere trovato, con i suoi due tipi ──
K="$OUT/contro"; mkdir -p "$K/a" "$K/b"
"$PY" -I - "$OUT/riferimento" "$K" <<'PYEOF' || RC=1
import json, os, sys
ref, k = sys.argv[1], sys.argv[2]
for d, _, fs in sorted(os.walk(ref)):
    for f in sorted(fs):
        if not f.endswith(".jsonl"): continue
        lines = open(os.path.join(d, f), encoding="utf-8").read().splitlines()
        if len(lines) < 3: continue
        e = json.loads(lines[2])
        e["testo"] = e["testo"] + " (alterato)"
        if "segnale" in e: e.pop("segnale")
        else: e["segnale"] = "medium"
        open(f"{k}/a/prova.jsonl", "w", encoding="utf-8").write("\n".join(lines) + "\n")
        lines[2] = json.dumps(e, ensure_ascii=False, sort_keys=True, separators=(",", ":"))
        open(f"{k}/b/prova.jsonl", "w", encoding="utf-8").write("\n".join(lines) + "\n")
        sys.exit(0)
sys.exit(1)
PYEOF
esegui_passo "prova al contrario" "$OFF" confronta-descrizioni --a "$K/a" --b "$K/b" --al-byte > "$K/esito.txt" 2>&1; rc=$?
if [ "$rc" = 1 ] && grep -q 'testo pronunciato 1' "$K/esito.txt" && grep -q 'segnale 1' "$K/esito.txt"; then
  say "[3] prova al contrario: l'elemento alterato è trovato (testo pronunciato e segnale)"; rc=0
else
  say "[3] la prova al contrario non è stata trovata come attesa (exit=$rc, $K/esito.txt)"; [ "$rc" = 0 ] && rc=1
fi
chiudi_passo "prova al contrario" "$rc" "$K/esito.txt"

# ── 5. con --vista: la vista vera dell'iPad sulle stesse letture congelate ──
if [ "$VISTA" = 1 ]; then
  UDID="$(xcrun simctl list devices -j | "$PY" -c "import json,sys; d=json.load(sys.stdin)['devices'].get('com.apple.CoreSimulator.SimRuntime.iOS-27-0',[]); print(next((x['udid'] for x in d if x['name']=='iPad Pro 11-inch (M5)' and x.get('isAvailable', True)),''))")"
  [ -n "$UDID" ] || { say "[4] simulatore iPad Pro 11-inch (M5) iOS 27 assente"; exit 2; }
  ACCESO_PRIMA="$(xcrun simctl list devices | grep -c "$UDID) (Booted)")"
  [ "$ACCESO_PRIMA" = 0 ] && xcrun simctl boot "$UDID" >/dev/null 2>&1
  # La libreria dei test si svuota prima di ogni uso del simulatore (il banco aggiunge e toglie un documento per libro).
  xcrun simctl uninstall "$UDID" com.scabo.scabopdf >/dev/null 2>&1
  PBX="$REPO_ROOT/app/ios/ScaboPDF.xcodeproj/project.pbxproj"
  ( cd "$REPO_ROOT" && git diff --quiet -- "$PBX" ); PBX_PULITO=$?
  "$PY" -I -c "import json, sys; l = json.load(open(sys.argv[1])); l['outDir'] = sys.argv[2]; json.dump(l, open(sys.argv[3], 'w'), ensure_ascii=False)" \
    "$OUT/libri.json" "$OUT/vista" "$OUT/richiesta_vista.json"
  ( cd "$REPO_ROOT/app/ios" && esegui_passo "vista compilata" xcodebuild build-for-testing -project ScaboPDF.xcodeproj -scheme ScaboApp \
      -destination "platform=iOS Simulator,id=$UDID" -configuration Release ENABLE_TESTABILITY=YES CODE_SIGNING_ALLOWED=NO \
      -derivedDataPath "$PAR/dd" ) > "$OUT/vista_build.log" 2>&1; rc=$?
  chiudi_passo "vista compilata" "$rc"
  if [ "$rc" = 0 ]; then
    ( cd "$REPO_ROOT/app/ios" && TEST_RUNNER_SCABO_DESCRIZIONI_REQUEST="$OUT/richiesta_vista.json" esegui_passo "vista percorsa" xcodebuild test-without-building \
        -project ScaboPDF.xcodeproj -scheme ScaboApp -destination "platform=iOS Simulator,id=$UDID" -configuration Release \
        -only-testing:ScaboAppTests/RealPdfBenchTests/test_readingViewDescriptionWalk_fromRequest -derivedDataPath "$PAR/dd" \
        -collect-test-diagnostics never ) > "$OUT/vista.log" 2>&1; rc=$?
  fi
  nv=$(find "$OUT/vista" -name '*.jsonl' 2>/dev/null | wc -l | tr -d ' '); nr=$(find "$OUT/riferimento" -name '*.jsonl' | wc -l | tr -d ' ')
  say "[4] vista vera dell'iPad percorsa: exit=$rc, $nv descrizioni su $nr del riferimento"
  chiudi_passo_conteggio "vista percorsa" "$rc" "$nr" "$nv"
  [ "$ACCESO_PRIMA" = 0 ] && xcrun simctl shutdown "$UDID" >/dev/null 2>&1
  [ "$PBX_PULITO" = 0 ] && ( cd "$REPO_ROOT" && git checkout -q -- "$PBX" )   # xcodebuild riordina due righe del progetto
  esegui_passo "referti del percorso" "$PY" -I "$SCRIPT_DIR/generazioni/verifica_percorsi_vista.py" "$OUT/vista" > "$OUT/percorsi_vista.txt" 2>&1; rc=$?
  say "[4] referti del percorso: exit=$rc ($(head -1 "$OUT/percorsi_vista.txt"))"
  chiudi_passo "referti del percorso" "$rc" "$OUT/percorsi_vista.txt"
  esegui_passo "confronto vista" "$OFF" confronta-descrizioni --a "$OUT/riferimento" --b "$OUT/vista" --al-byte --nomi riferimento,vista > "$OUT/confronto_vista.txt" 2>&1; rc=$?
  say "[4] vista contro riferimento: exit=$rc"
  tail -2 "$OUT/confronto_vista.txt" | sed 's/^/      /'
  chiudi_passo "confronto vista" "$rc" "$OUT/confronto_vista.txt"
fi

[ "$RC" = 0 ] || _passo_rosso "preparazione" "un passo di preparazione è fallito"
esito_rete "rete_parlato" "$TAG"
exit $?
