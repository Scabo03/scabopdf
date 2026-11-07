#!/usr/bin/env bash
#
# rete_parlato.sh — LA RETE SUL PARLATO (giro «fondamenta della lettura per Mac», 2026-11-07), da rifare in OGNI giro che tocca
# la lettura: la vista, ciò che VoiceOver pronuncia, i rotori, le azioni, i segnali acustici.
#
# Il parlato di ogni elemento della lettura viene da una fonte sola, ScaboCore `ReadingSpeech` (`ReadingSpeech.swift`), che
# usano la vista dell'iPad e userà quella del Mac. La rete ne DESCRIVE ogni elemento (testo pronunciato, valore, ruolo,
# livello d'intestazione, segnale previsto, rotori, azioni, contenitore) su letture CONGELATE, le stesse in ogni giro, e
# confronta al byte con il RIFERIMENTO congelato: una modifica della catena non la tocca (gli ingressi sono fermi), una
# modifica del parlato sì. Il riferimento è stato prodotto dalla vista dell'iPad allo HEAD `56aaafe` (build 64), con la logica
# del parlato di prima dello spostamento, ed è identico al byte a ciò che il modulo dava dopo (630.124 elementi).
#   1. compila la riga di comando dell'officina Mac (`scabomac-officina`) contro il codice di QUESTO repo;
#   2. descrive ogni lettura dell'elenco (`<parlato>/libri.json`), Lettura Continua e Dottrina Inline, «note annunciate a voce»
#      spenta e accesa (`<parlato>/<etichetta>/<libro>.<lc|di>.<n0|n1>.jsonl`);
#   3. confronta con `<parlato>/riferimento`: ogni descrizione identica al byte, altrimenti ROSSO, con la prima divergenza e il
#      suo tipo per file (testi per lunghezza e impronta, mai il testo);
#   4. PROVA AL CONTRARIO del confronto: una copia di una descrizione del riferimento con un elemento alterato (testo pronunciato
#      e segnale) deve risultare diversa, con quei due tipi.
# Una differenza voluta del parlato si giudica, e il riferimento si aggiorna di proposito (copiando le uscite giudicate), come per
# le altre reti. Le uscite CONTENGONO TESTO dei volumi: stanno solo nel laboratorio.
#
# Uso: app/ios/scripts/rete_parlato.sh <etichetta>
# Variabili (con default): SCABO_GEN_LAB (~/Developer/scabopdf-gen-lab), SCABO_PARLATO (<lab>/parlato: libri.json, letture/,
# riferimento/), SCABO_TOOLS_PY (python del venv degli strumenti, solo per preparare la prova al contrario).
# Codici d'uscita: 0 verde, 1 rosso, 2 prerequisito mancante.
set -uo pipefail
export DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"
TAG="${1:-}"; [ -n "$TAG" ] || { echo "uso: $0 <etichetta>"; exit 2; }
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
LAB="${SCABO_GEN_LAB:-$HOME/Developer/scabopdf-gen-lab}"
PAR="${SCABO_PARLATO:-$LAB/parlato}"
PY="${SCABO_TOOLS_PY:-$HOME/Developer/scabopdf-tools-venv/bin/python}"
MAC="$REPO_ROOT/app/macos/ScaboMac"
[ -f "$PAR/libri.json" ] && [ -d "$PAR/riferimento" ] || { echo "prerequisiti del laboratorio assenti in $PAR"; exit 2; }
[ -d "$MAC/Vendor/llama.xcframework" ] || { echo "manca Vendor/llama.xcframework: app/macos/ScaboMac/scripts/prepara_llama.sh"; exit 2; }
[ -x "$PY" ] || { echo "python degli strumenti assente: $PY"; exit 2; }
OUT="$PAR/$TAG"
[ -e "$OUT" ] && { echo "etichetta già usata: $OUT"; exit 2; }
RC=0
say() { printf '%s\n' "$*"; }

# ── 1. la riga di comando dell'officina, a HEAD ──
( cd "$MAC" && swift build -c release --product scabomac-officina --scratch-path "$PAR/officina_build" ) > "$PAR/officina_build_$TAG.log" 2>&1
rc=$?; say "[1] scabomac-officina compilata a HEAD $(cd "$REPO_ROOT" && git rev-parse --short HEAD)$(cd "$REPO_ROOT" && git diff --quiet HEAD || echo " con modifiche non committate"): exit=$rc"
[ "$rc" = 0 ] || exit 1
OFF="$PAR/officina_build/release/scabomac-officina"

# ── 2. le descrizioni ──
"$OFF" descrivi --libri "$PAR/libri.json" --out "$OUT" > "$PAR/descrivi_$TAG.log" 2>&1; rc=$?
n=$(find "$OUT" -name '*.jsonl' | wc -l | tr -d ' '); nr=$(find "$PAR/riferimento" -name '*.jsonl' | wc -l | tr -d ' ')
say "[2] descrizioni: exit=$rc, $n file (riferimento $nr)"
[ "$rc" = 0 ] || RC=1

# ── 3. confronto al byte col riferimento ──
"$OFF" confronta-descrizioni --a "$PAR/riferimento" --b "$OUT" --al-byte --nomi riferimento,"$TAG" > "$PAR/confronto_$TAG.txt" 2>&1; rc=$?
say "[3] confronto col riferimento: exit=$rc (dettagli in $PAR/confronto_$TAG.txt)"
tail -2 "$PAR/confronto_$TAG.txt" | sed 's/^/      /'
[ "$rc" = 0 ] || RC=1

# ── 4. prova al contrario: un elemento alterato in una copia deve essere trovato, con i suoi due tipi ──
K="$PAR/${TAG}_contro"; mkdir -p "$K/a" "$K/b"
"$PY" -I - "$PAR/riferimento" "$K" <<'PYEOF' || RC=1
import json, os, sys
ref, k = sys.argv[1], sys.argv[2]
for d, _, fs in os.walk(ref):
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
"$OFF" confronta-descrizioni --a "$K/a" --b "$K/b" --al-byte > "$K/esito.txt" 2>&1; rc=$?
if [ "$rc" = 1 ] && grep -q 'testo pronunciato 1' "$K/esito.txt" && grep -q 'segnale 1' "$K/esito.txt"; then
  say "[4] prova al contrario: l'elemento alterato è trovato (testo pronunciato e segnale)"
else
  say "[4] ROSSO: la prova al contrario non è stata trovata come attesa (exit=$rc, $K/esito.txt)"; RC=1
fi

say ""; say "rete_parlato $TAG: exit=$RC"
exit $RC
