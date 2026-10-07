#!/usr/bin/env bash
# Rete sulle annotazioni (docs/ANCORE_ANNOTAZIONI.md § 4) — comando unico, entra fra le reti fisse di ogni build.
#
# Per ogni generazione (26.5 e 27, come la doppia rete) e per ogni volume della lista:
#   1. conia annotazioni SINTETICHE (segnalibri su ogni ruolo + citazioni) sulla lettura A = linea di base
#      della generazione (letture/base_<gen>);
#   2. le riancora su: la lettura della CATENA ATTUALE (letture/<tag>_<gen>), la lettura dell'ALTRA
#      generazione (letture/<tag>_<altra>), una CATENA DIVERSA (letture/<SCABO_ALTRA_CATENA>_<gen>, default b44);
#   3. prova al contrario: tre perturbazioni della lettura A (orfana / scambio / scorri) con l'esito atteso;
#   4. giudica (rete_annotazioni.py): ZERO ricollocazioni sbagliate; le orfane sono contate e dichiarate;
#   5. tabella dei volumi la cui SEQUENZA DEI NODI cambia fra base e catena attuale (base vs <tag>): referto di build.
# Il runner è quello del banco (SCABO_RUNNER_SRC), compilato contro lo ScaboCore di questo repo (a HEAD).
# Esce 1 se un volume è ROSSO. Uscite: $LAB/reti/annotazioni_<tag>_*.md, $LAB/logs/rete_annotazioni_<tag>.txt.
set -u
TAG="${1:?uso: rete_annotazioni.sh <etichetta della fotografia già letta da rete_generazioni.sh>}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
CORPUS="${SCABO_CORPUS:-$HOME/Developer/scabopdf-triple-take}"
LAB="${SCABO_GEN_LAB:-$HOME/Developer/scabopdf-gen-lab}"
PY="${SCABO_TOOLS_PY:-$HOME/Developer/scabopdf-tools-venv/bin/python}"
LISTA="${SCABO_LISTA:-$SCRIPT_DIR/generazioni/lista_volumi.json}"
RUNNER_SRC="${SCABO_RUNNER_SRC:-$CORPUS/ultrafocus_bench/runner}"
ALTRA="${SCABO_ALTRA_CATENA:-b44}"
read -r -a GENS <<< "${SCABO_GENS:-ios265 ios27}"
JUDGE="$SCRIPT_DIR/generazioni/rete_annotazioni.py"
mkdir -p "$LAB/reti" "$LAB/logs" "$LAB/annotazioni/$TAG"
LOG="$LAB/logs/rete_annotazioni_$TAG.txt"; : > "$LOG"
say() { echo "$*" | tee -a "$LOG"; }
RC=0

# runner a HEAD
RUNNER_DIR="$LAB/runner"; mkdir -p "$RUNNER_DIR"
rsync -a --exclude .build "$RUNNER_SRC/" "$RUNNER_DIR/"
"$PY" - "$RUNNER_DIR/Package.swift" "$REPO_ROOT/app/ios/ScaboCore" <<'PYEOF'
import re, sys
p, core = sys.argv[1], sys.argv[2]
s = open(p).read()
s = re.sub(r'\.package\(path:\s*"[^"]*ScaboCore"\)', '.package(path: "%s")' % core, s)
open(p, "w").write(s)
PYEOF
( cd "$RUNNER_DIR" && swift build -c release > "$LAB/logs/${TAG}_annot_runner_build.log" 2>&1 ); rc=$?
say "[1] runner compilato a HEAD $(cd "$REPO_ROOT" && git rev-parse --short HEAD): exit=$rc"
[ "$rc" = 0 ] || exit 1
R="$RUNNER_DIR/.build/release/ultrafocus-runner"

volumes() { "$PY" -c 'import json,sys,re; [print(re.sub(r"\.pdf$","",v if isinstance(v,str) else v["stem"])) for v in json.load(open(sys.argv[1]))]' "$LISTA"; }

for GEN in "${GENS[@]}"; do
  OTHER=""; for g in "${GENS[@]}"; do [ "$g" != "$GEN" ] && OTHER="$g"; done
  OUT="$LAB/annotazioni/$TAG/$GEN"; mkdir -p "$OUT"
  MD="$LAB/reti/annotazioni_${TAG}_$GEN.md"
  {
    echo "# Rete sulle annotazioni — fotografia $TAG, generazione $GEN"
    echo
    echo "A = letture/base_$GEN (annotazioni sintetiche coniate qui). Confronti: catena attuale (\`$TAG\`), altra generazione (\`$OTHER\`), catena diversa (\`$ALTRA\`), prove al contrario (orfana/scambio/scorri)."
    echo
    echo "| volume | confronto | seg A/B | segnalibri ricollocati | orfani (evitabili) | SBAGLIATI | citazioni ok+incollate/orfane/SBAGLIATE | livelli | indice ms | verdetto |"
    echo "|---|---|---|---|---|---|---|---|---|---|"
  } > "$MD"
  n=0; rosso=0
  while IFS= read -r stem; do
    A="$LAB/letture/base_$GEN/$stem.reading.json"; [ -f "$A" ] || continue
    base="$(basename "$stem")"; W="$OUT/$base"; mkdir -p "$W"
    n=$((n+1))
    "$R" anchors --reading "$A" --per-role 12 --quotes 40 --seed 7 --out "$W/anchors.json" >> "$LOG" 2>&1 || { say "    ERR anchors $GEN $stem"; RC=1; continue; }
    # confronti
    for cmp in "catena:$LAB/letture/${TAG}_$GEN/$stem.reading.json" "altra_gen:$LAB/letture/${TAG}_$OTHER/$stem.reading.json" "catena_$ALTRA:$LAB/letture/${ALTRA}_$GEN/$stem.reading.json"; do
      name="${cmp%%:*}"; B="${cmp#*:}"; [ -f "$B" ] || { say "    (manca $name per $stem)"; continue; }
      "$R" reanchor --anchors "$W/anchors.json" --reading "$B" --out "$W/res_$name.json" >> "$LOG" 2>&1 || { say "    ERR reanchor $name $stem"; RC=1; continue; }
      "$PY" "$JUDGE" giudica "$A" "$W/anchors.json" "$B" "$W/res_$name.json" "$base" --out "$W/row_$name.json" >> "$LOG" 2>&1 || { rosso=$((rosso+1)); RC=1; }
      [ -f "$W/row_$name.json" ] || { say "    ERR giudizio $name $stem (riga mancante)"; echo "| $base | $name | — | — | — | — | — | — | — | ERRORE |" >> "$MD"; continue; }
      "$PY" - "$W/row_$name.json" "$name" >> "$MD" <<'PYEOF'
import json,sys
r=json.load(open(sys.argv[1])); name=sys.argv[2]
lv=" ".join(f"{k}={v}" for k,v in sorted(r["livelli"].items()))
print(f"| {r['volume'][:30]} | {name} | {r['segmenti_A']}/{r['segmenti_B']} | {r['ricollocati']}/{r['segnalibri']} | {r['orfani']} ({r['orfane_evitabili']}) | **{r['sbagliati']}** | {r['citazioni_ok']}+{r.get('citazioni_incollate',0)}/{r['citazioni_orfane']}/**{r['citazioni_sbagliate']}** | {lv} | {r['indice_ms']} | {r['verdetto']} |")
PYEOF
    done
    # prove al contrario
    for modo in orfana scambio scorri; do
      "$PY" "$JUDGE" perturba "$A" "$W/anchors.json" "$modo" "$W/pert_$modo.reading.json" >> "$LOG" 2>&1 || { RC=1; continue; }
      "$R" reanchor --anchors "$W/anchors.json" --reading "$W/pert_$modo.reading.json" --out "$W/res_pert_$modo.json" >> "$LOG" 2>&1 || { RC=1; continue; }
      "$PY" "$JUDGE" giudica "$A" "$W/anchors.json" "$W/pert_$modo.reading.json" "$W/res_pert_$modo.json" "$base" --atteso "$modo" --out "$W/row_pert_$modo.json" >> "$LOG" 2>&1 || { rosso=$((rosso+1)); RC=1; }
      [ -f "$W/row_pert_$modo.json" ] || { say "    ERR giudizio controprova $modo $stem (riga mancante)"; echo "| $base | controprova_$modo | — | — | — | — | — | — | — | ERRORE |" >> "$MD"; rm -f "$W/pert_$modo.reading.json"; continue; }
      "$PY" - "$W/row_pert_$modo.json" "controprova_$modo" >> "$MD" <<'PYEOF'
import json,sys
r=json.load(open(sys.argv[1])); name=sys.argv[2]
lv=" ".join(f"{k}={v}" for k,v in sorted(r["livelli"].items()))
print(f"| {r['volume'][:30]} | {name} | {r['segmenti_A']}/{r['segmenti_B']} | {r['ricollocati']}/{r['segnalibri']} | {r['orfani']} ({r['orfane_evitabili']}) | **{r['sbagliati']}** | {r['citazioni_ok']}+{r.get('citazioni_incollate',0)}/{r['citazioni_orfane']}/**{r['citazioni_sbagliate']}** | {lv} | {r['indice_ms']} | {r['verdetto']} |")
PYEOF
      rm -f "$W/pert_$modo.reading.json"
    done
  done < <(volumes)
  # totali
  "$PY" - "$OUT" >> "$MD" <<'PYEOF'
import json,sys,glob,collections
tot=collections.Counter(); per=collections.Counter(); orf_role=collections.Counter(); tot_role=collections.Counter(); ms=[]
for f in glob.glob(sys.argv[1]+"/*/row_*.json"):
    r=json.load(open(f)); kind="controprova" if "pert_" in f else f.split("row_")[1][:-5]
    for k in ("segnalibri","ricollocati","orfani","orfane_evitabili","sbagliati","citazioni","citazioni_ok","citazioni_incollate","citazioni_orfane","citazioni_sbagliate"): per[(kind,k)]+=r.get(k,0)
    tot[r["verdetto"]]+=1
    if kind=="catena":
        for k,v in r["orfani_per_ruolo"].items(): orf_role[k]+=v
        for k,v in r["campioni_per_ruolo"].items(): tot_role[k]+=v
        ms.append(r["indice_ms"] or 0)
print("\n**Totali per confronto** (segnalibri ricollocati/totale, orfani (evitabili), SBAGLIATI; citazioni ok/orfane/SBAGLIATE):\n")
for kind in sorted({k for k,_ in per}):
    g=lambda k: per[(kind,k)]
    print(f"- `{kind}`: {g('ricollocati')}/{g('segnalibri')} ricollocati, {g('orfani')} orfani ({g('orfane_evitabili')} evitabili), **{g('sbagliati')} sbagliati**; citazioni {g('citazioni_ok')} ok + {g('citazioni_incollate')} su parole incollate / {g('citazioni_orfane')} orfane / **{g('citazioni_sbagliate')} sbagliate**")
print(f"\n**Orfani per ruolo (catena attuale)**: " + ", ".join(f"{k} {orf_role[k]}/{tot_role[k]}" for k in sorted(tot_role)))
print(f"\n**Indice**: max {max(ms) if ms else 0} ms, mediana {sorted(ms)[len(ms)//2] if ms else 0} ms (costruzione dell'indice delle ancore sul volume).")
print(f"\n**Verdetti**: {dict(tot)}")
PYEOF
  say "[2] $GEN: $n volumi, righe ROSSE $rosso → $MD"
  [ "$rosso" = 0 ] || RC=1
done

# tabella dei volumi la cui sequenza dei nodi cambia (base → tag), per il referto di build
SEQ="$LAB/reti/sequenza_nodi_${TAG}.txt"
"$PY" "$SCRIPT_DIR/generazioni/sequenza_nodi.py" "$LAB/letture" "base" "$TAG" "$LISTA" "${GENS[@]}" > "$SEQ" 2>>"$LOG"; rc=$?
say "[3] tabella sequenza dei nodi base→$TAG: exit=$rc → $SEQ"
say "rete_annotazioni $TAG: exit=$RC"
exit $RC
