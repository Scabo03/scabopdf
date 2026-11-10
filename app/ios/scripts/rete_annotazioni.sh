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
#   6. con SCABO_ANNOT_RV=1 (giro «risorse visive», 2026-10-12): la catena attuale e l'altra generazione sono le letture
#      CON le risorse visive (`<stem>.rv.reading.json` di rete_generazioni.sh --risorse-visive), e in più annotazioni
#      coniate sulla lettura con le risorse (segnalibri anche sugli elementi «risorsa visiva») si riancorano sull'altra
#      generazione con le risorse e sulla stessa lettura senza risorse (lì le ancore delle risorse devono restare orfane).
# Il runner è quello del banco (SCABO_RUNNER_SRC), compilato contro lo ScaboCore di questo repo (a HEAD).
# Esce 1 se un volume è ROSSO. Uscite: $LAB/reti/annotazioni_<tag>_*.md, $LAB/logs/rete_annotazioni_<tag>.txt.
#
# Dal giro «prove rifatte e granularità» (2026-11-10): ogni passo è verde solo col codice 0 e le uscite attese, con lo schema
# comune `generazioni/esiti_passi.sh`. Un volume senza la lettura A, un confronto senza la sua lettura B, un giudizio senza la
# sua riga sono ROSSI (prima si saltavano in silenzio); con una generazione sola il confronto con l'altra è «non previsto», e
# così la catena diversa con SCABO_ALTRA_CATENA=no. SCABO_ANNOT_BASE (predefinita `base`) sceglie la lettura A su cui si coniano
# le annotazioni (`letture/<A>_<gen>`): con le letture della catena dell'iPad a granularità diverse (`g<N>_<foto>`) la rete
# prova un cambio di granularità nei due versi. Prova al contrario incorporata: SCABO_RETE_GUASTO=ferma:<passo> o togli:<passo>.
set -u
TAG="${1:?uso: rete_annotazioni.sh <etichetta della fotografia già letta da rete_generazioni.sh>}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
CORPUS="${SCABO_CORPUS:-$HOME/Developer/scabopdf-triple-take}"
LAB="${SCABO_GEN_LAB:-$HOME/Developer/scabopdf-gen-lab}"
PY="${SCABO_TOOLS_PY:-$HOME/Developer/scabopdf-tools-venv/bin/python}"
# La lista dei volumi: dal banco (etichette e impronte nel repo, corrispondenza nel laboratorio, verificata), o SCABO_LISTA.
if [ -n "${SCABO_LISTA:-}" ]; then LISTA="$SCABO_LISTA"; else
  LISTA="$LAB/annotazioni/lista_${TAG}.json"; mkdir -p "$LAB/annotazioni"
  "$PY" -I "$SCRIPT_DIR/generazioni/banco.py" risolvi "$LISTA" || exit 2
fi
RUNNER_SRC="${SCABO_RUNNER_SRC:-$CORPUS/ultrafocus_bench/runner}"
ALTRA="${SCABO_ALTRA_CATENA:-b44}"
ABASE="${SCABO_ANNOT_BASE:-base}"
RVS=""; [ "${SCABO_ANNOT_RV:-0}" = 1 ] && RVS=".rv"
read -r -a GENS <<< "${SCABO_GENS:-ios265 ios27}"
JUDGE="$SCRIPT_DIR/generazioni/rete_annotazioni.py"
# shellcheck source=generazioni/esiti_passi.sh
source "$SCRIPT_DIR/generazioni/esiti_passi.sh"
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
R="$RUNNER_DIR/.build/release/ultrafocus-runner"
( cd "$RUNNER_DIR" && esegui_passo "runner" swift build -c release > "$LAB/logs/${TAG}_annot_runner_build.log" 2>&1 ); rc=$?
say "[1] runner compilato a HEAD $(cd "$REPO_ROOT" && git rev-parse --short HEAD): exit=$rc"
chiudi_passo "runner" "$rc" "$R" || { esito_rete "rete_annotazioni" "$TAG"; exit 1; }
N_ATTESI=$("$PY" -c "import json,sys; print(len(json.load(open(sys.argv[1]))))" "$LISTA")

volumes() { "$PY" -c 'import json,sys,re; [print(re.sub(r"\.pdf$","",v if isinstance(v,str) else v["stem"])) for v in json.load(open(sys.argv[1]))]' "$LISTA"; }

for GEN in "${GENS[@]}"; do
  OTHER=""; for g in "${GENS[@]}"; do [ "$g" != "$GEN" ] && OTHER="$g"; done
  OUT="$LAB/annotazioni/$TAG/$GEN"; mkdir -p "$OUT"
  MD="$LAB/reti/annotazioni_${TAG}_$GEN.md"
  {
    echo "# Rete sulle annotazioni — fotografia $TAG, generazione $GEN"
    echo
    echo "A = letture/${ABASE}_$GEN (annotazioni sintetiche coniate qui). Confronti: catena attuale (\`$TAG\`), altra generazione (\`$OTHER\`), catena diversa (\`$ALTRA\`), prove al contrario (orfana/scambio/scorri)."
    echo
    echo "| volume | confronto | seg A/B | segnalibri ricollocati | orfani (evitabili) | SBAGLIATI | citazioni ok+incollate/orfane/SBAGLIATE | livelli | indice ms | verdetto |"
    echo "|---|---|---|---|---|---|---|---|---|---|"
  } > "$MD"
  n=0; rosso=0; mancanti=0
  [ -n "$OTHER" ] || non_previsto "altra generazione $GEN" "una generazione sola (SCABO_GENS)"
  [ "$ALTRA" = no ] && non_previsto "catena diversa $GEN" "SCABO_ALTRA_CATENA=no"
  while IFS= read -r stem; do
    A="$LAB/letture/${ABASE}_$GEN/$stem.reading.json"
    [ -f "$A" ] || { say "    MANCA la lettura A ${ABASE}_$GEN per $stem"; mancanti=$((mancanti+1)); continue; }
    base="$(basename "$stem")"; W="$OUT/$base"; mkdir -p "$W"
    n=$((n+1))
    "$R" anchors --reading "$A" --per-role 12 --quotes 40 --seed 7 --out "$W/anchors.json" >> "$LOG" 2>&1 || { say "    ERR anchors $GEN $stem"; RC=1; continue; }
    # confronti
    CONFRONTI=("catena:$LAB/letture/${TAG}_$GEN/$stem$RVS.reading.json")
    [ -n "$OTHER" ] && CONFRONTI+=("altra_gen:$LAB/letture/${TAG}_$OTHER/$stem$RVS.reading.json")
    [ "$ALTRA" != no ] && CONFRONTI+=("catena_$ALTRA:$LAB/letture/${ALTRA}_$GEN/$stem.reading.json")
    for cmp in "${CONFRONTI[@]}"; do
      name="${cmp%%:*}"; B="${cmp#*:}"
      if [ "$RETE_GUASTO" = "togli:confronti $GEN" ] && [ "$n" = 1 ] && [ "$name" = catena ]; then B="$B.tolto"; say "    GUASTO DI PROVA: tolta la lettura B «${name}» di $stem"; fi
      [ -f "$B" ] || { say "    MANCA la lettura B «${name}» per $stem: ROSSO"; rosso=$((rosso+1)); echo "| $(basename "$stem") | $name | — | — | — | — | — | — | — | MANCA B |" >> "$MD"; continue; }
      rm -f "$W/row_$name.json"
      esegui_passo "confronti $GEN" "$R" reanchor --anchors "$W/anchors.json" --reading "$B" --out "$W/res_$name.json" >> "$LOG" 2>&1 || { say "    ERR reanchor $name $stem"; rosso=$((rosso+1)); continue; }
      "$PY" "$JUDGE" giudica "$A" "$W/anchors.json" "$B" "$W/res_$name.json" "$base" --out "$W/row_$name.json" >> "$LOG" 2>&1 || { rosso=$((rosso+1)); RC=1; }
      [ -f "$W/row_$name.json" ] || { say "    ERR giudizio $name $stem (riga mancante)"; rosso=$((rosso+1)); echo "| $base | $name | — | — | — | — | — | — | — | ERRORE |" >> "$MD"; continue; }
      "$PY" - "$W/row_$name.json" "$name" >> "$MD" <<'PYEOF'
import json,sys
r=json.load(open(sys.argv[1])); name=sys.argv[2]
lv=" ".join(f"{k}={v}" for k,v in sorted(r["livelli"].items()))
print(f"| {r['volume'][:30]} | {name} | {r['segmenti_A']}/{r['segmenti_B']} | {r['ricollocati']}/{r['segnalibri']} | {r['orfani']} ({r['orfane_evitabili']}) | **{r['sbagliati']}** | {r['citazioni_ok']}+{r.get('citazioni_incollate',0)}/{r['citazioni_orfane']}/**{r['citazioni_sbagliate']}** | {lv} | {r['indice_ms']} | {r['verdetto']} |")
PYEOF
    done
    # risorse visive: annotazioni coniate sulla lettura CON le risorse (anche sugli elementi «risorsa visiva»)
    if [ -n "$RVS" ] && [ ! -f "$LAB/letture/${TAG}_$GEN/$stem.rv.reading.json" ]; then
      say "    MANCA la lettura con le risorse di $stem (SCABO_ANNOT_RV=1): ROSSO"; rosso=$((rosso+1))
    fi
    if [ -n "$RVS" ] && [ -f "$LAB/letture/${TAG}_$GEN/$stem.rv.reading.json" ]; then
      A2="$LAB/letture/${TAG}_$GEN/$stem.rv.reading.json"
      "$R" anchors --reading "$A2" --per-role 12 --quotes 40 --seed 7 --out "$W/anchors_rv.json" >> "$LOG" 2>&1 || { say "    ERR anchors rv $GEN $stem"; RC=1; }
      CONFRONTI_RV=("rv_senza_risorse:$LAB/letture/${TAG}_$GEN/$stem.reading.json")
      [ -n "$OTHER" ] && CONFRONTI_RV=("rv_altra_gen:$LAB/letture/${TAG}_$OTHER/$stem.rv.reading.json" "${CONFRONTI_RV[@]}")
      for cmp in "${CONFRONTI_RV[@]}"; do
        name="${cmp%%:*}"; B="${cmp#*:}"
        [ -f "$B" ] && [ -f "$W/anchors_rv.json" ] || { say "    MANCA «${name}» per $stem: ROSSO"; rosso=$((rosso+1)); continue; }
        "$R" reanchor --anchors "$W/anchors_rv.json" --reading "$B" --out "$W/res_$name.json" >> "$LOG" 2>&1 || { say "    ERR reanchor $name $stem"; RC=1; continue; }
        "$PY" "$JUDGE" giudica "$A2" "$W/anchors_rv.json" "$B" "$W/res_$name.json" "$base" --out "$W/row_$name.json" >> "$LOG" 2>&1 || { rosso=$((rosso+1)); RC=1; }
        [ -f "$W/row_$name.json" ] || { say "    ERR giudizio $name $stem (riga mancante)"; echo "| $base | $name | — | — | — | — | — | — | — | ERRORE |" >> "$MD"; continue; }
        "$PY" - "$W/row_$name.json" "$name" >> "$MD" <<'PYEOF'
import json,sys
r=json.load(open(sys.argv[1])); name=sys.argv[2]
lv=" ".join(f"{k}={v}" for k,v in sorted(r["livelli"].items()))
print(f"| {r['volume'][:30]} | {name} | {r['segmenti_A']}/{r['segmenti_B']} | {r['ricollocati']}/{r['segnalibri']} | {r['orfani']} ({r['orfane_evitabili']}) | **{r['sbagliati']}** | {r['citazioni_ok']}+{r.get('citazioni_incollate',0)}/{r['citazioni_orfane']}/**{r['citazioni_sbagliate']}** | {lv} | {r['indice_ms']} | {r['verdetto']} |")
PYEOF
      done
    fi
    # prove al contrario
    for modo in orfana scambio scorri; do
      "$PY" "$JUDGE" perturba "$A" "$W/anchors.json" "$modo" "$W/pert_$modo.reading.json" >> "$LOG" 2>&1 || { RC=1; continue; }
      rm -f "$W/row_pert_$modo.json"
      "$R" reanchor --anchors "$W/anchors.json" --reading "$W/pert_$modo.reading.json" --out "$W/res_pert_$modo.json" >> "$LOG" 2>&1 || { rosso=$((rosso+1)); continue; }
      "$PY" "$JUDGE" giudica "$A" "$W/anchors.json" "$W/pert_$modo.reading.json" "$W/res_pert_$modo.json" "$base" --atteso "$modo" --out "$W/row_pert_$modo.json" >> "$LOG" 2>&1 || { rosso=$((rosso+1)); RC=1; }
      [ -f "$W/row_pert_$modo.json" ] || { say "    ERR giudizio controprova $modo $stem (riga mancante)"; rosso=$((rosso+1)); echo "| $base | controprova_$modo | — | — | — | — | — | — | — | ERRORE |" >> "$MD"; rm -f "$W/pert_$modo.reading.json"; continue; }
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
  say "[2] $GEN: $n volumi su $N_ATTESI (letture A mancanti $mancanti), righe ROSSE $rosso → $MD"
  [ "$RETE_GUASTO" = "ferma:confronti $GEN" ] && rosso=$((rosso+1))
  [ "$rosso" = 0 ] && rc=0 || rc=1
  chiudi_passo_conteggio "confronti $GEN" "$rc" "$N_ATTESI" "$n"
done

# tabella dei volumi la cui sequenza dei nodi cambia (base → tag), per il referto di build
SEQ="$LAB/reti/sequenza_nodi_${TAG}.txt"
# Un passo interno fallito (ancore non coniate, giudizio fallito, letture con le risorse) segnato in RC fa rossa la rete.
[ "$RC" = 0 ] || _passo_rosso "passi interni" "almeno un conio o un giudizio è fallito (vedi $LOG)"
esegui_passo "sequenza dei nodi" "$PY" "$SCRIPT_DIR/generazioni/sequenza_nodi.py" "$LAB/letture" "$ABASE" "$TAG" "$LISTA" "${GENS[@]}" > "$SEQ" 2>>"$LOG"; rc=$?
say "[3] tabella sequenza dei nodi ${ABASE}→$TAG: exit=$rc → $SEQ"
chiudi_passo "sequenza dei nodi" "$rc" "$SEQ"
esito_rete "rete_annotazioni" "$TAG" | tee -a "$LOG"
exit "${PIPESTATUS[0]}"
