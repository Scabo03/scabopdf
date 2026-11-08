#!/usr/bin/env bash
#
# rete_vista_mac.sh — LA RETE D'IDENTITÀ DELLA VISTA DEL MAC (giro «app unica per Mac, tappa A», 2026-11-08; DISEGNO_LETTURA_MAC
# § 3.4, passo 1): ciò che dice la lettura dell'app Mac contro ciò che dice la vista dell'iPad, su tutti i libri della rete sul
# parlato (i 52 volumi del banco e i tre documenti di studio), dentro il processo (banco `BancoIdentitaTests` del pacchetto
# ScaboMac, compilato in release). Per ogni libro due misure separate, perché si sappia da dove viene una differenza:
#   (V) la VISTA del Mac sulla lettura congelata dell'iPad, descritta da sé, contro i riferimenti dell'iPad (VoiceOver spento e
#       acceso, «note a voce» spenta e accesa), senza le azioni che la tappa A non ha (segnalibro, «Strumenti elemento»,
#       «Estrai come immagine»): una differenza qui è della vista;
#   (A) l'APP: il PDF importato dall'app Mac col percorso vero (estrattore del Mac), riaperto come l'app lo riapre, descritto
#       dalla vista; e la sua lettura contro quella congelata dell'iPad: una differenza che (V) non ha è dell'ESTRATTORE.
# Le letture del Mac restano nel laboratorio (`<uscite>/letture_mac/`) per il confronto con le due generazioni di iOS.
# È la misura della vista del Mac che il passo 3 di `confronto_letture_ipad_mac.sh` aspettava; quello script resta la prova a
# livello di catena (catena dell'iPad, vista vera dell'iPad, catena del Mac).
#
# Uso: app/ios/scripts/rete_vista_mac.sh <etichetta> [--solo STEM] [--misure STEM]
#   --solo     un libro solo, per fine del nome
#   --misure   il libro su cui misurare anche tempi e memoria (apertura, primo elemento, scorrimento)
# Variabili (con default): SCABO_GEN_LAB (~/Developer/scabopdf-gen-lab), SCABO_PARLATO (<lab>/parlato), SCABO_CORPUS
# (~/Developer/scabopdf-triple-take), SCABO_MAC_LAB (~/Developer/scabopdf-mac-lab/lettura_mac/app_unica: le uscite).
# Le uscite CONTENGONO TESTO dei volumi: solo nel laboratorio. Codici d'uscita: 0 verde, 1 rosso, 2 prerequisito mancante.
set -uo pipefail
export DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"
TAG="${1:-}"; [ -n "$TAG" ] || { echo "uso: $0 <etichetta> [--solo STEM] [--misure STEM]"; exit 2; }
shift
SOLO=""; MISURE=""
while [ $# -gt 0 ]; do case "$1" in --solo) SOLO="$2"; shift 2;; --misure) MISURE="$2"; shift 2;; *) echo "opzione sconosciuta: $1"; exit 2;; esac; done
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
LAB="${SCABO_GEN_LAB:-$HOME/Developer/scabopdf-gen-lab}"
PAR="${SCABO_PARLATO:-$LAB/parlato}"
CORPUS="${SCABO_CORPUS:-$HOME/Developer/scabopdf-triple-take}"
MACLAB="${SCABO_MAC_LAB:-$HOME/Developer/scabopdf-mac-lab/lettura_mac/app_unica}"
MAC="$REPO_ROOT/app/macos/ScaboMac"
OUT="$MACLAB/rete_vista/$TAG"
[ -e "$OUT" ] && { echo "etichetta già usata: $OUT"; exit 2; }
[ -f "$PAR/libri.json" ] && [ -d "$PAR/riferimento" ] && [ -d "$PAR/riferimento_vo" ] && [ -d "$CORPUS" ] || { echo "prerequisiti del laboratorio assenti"; exit 2; }
[ -d "$MAC/Vendor/llama.xcframework" ] || { echo "manca Vendor/llama.xcframework: app/macos/ScaboMac/scripts/prepara_llama.sh"; exit 2; }
mkdir -p "$OUT"
/usr/bin/python3 -I - "$OUT" "$PAR" "$CORPUS" "$LAB" "$SOLO" "$MISURE" <<'PYEOF' || exit 2
import json, sys
out, par, corpus, lab, solo, misure = sys.argv[1:7]
r = {"libri": f"{par}/libri.json", "riferimento": f"{par}/riferimento", "riferimentoVO": f"{par}/riferimento_vo",
     "corpus": {"originals": f"{corpus}/originals", "originals_new": f"{corpus}/originals_new",
                "originals_maint": f"{corpus}/originals_maint", "studio": f"{lab}/studio_mirato/corpus/studio"},
     "uscite": out}
if solo: r["solo"] = solo
if misure: r["misure"] = misure
json.dump(r, open(f"{out}/richiesta.json", "w"), ensure_ascii=False)
PYEOF
HEADINFO="$(cd "$REPO_ROOT" && git rev-parse --short HEAD)$(cd "$REPO_ROOT" && git diff --quiet HEAD -- app || echo " con modifiche non committate")"
( cd "$MAC" && SCABO_BANCO_MAC_RICHIESTA="$OUT/richiesta.json" swift test -c release -Xswiftc -enable-testing \
    --filter BancoIdentitaTests ) > "$OUT/banco.log" 2>&1
rc=$?
echo "[1] banco della vista del Mac a HEAD $HEADINFO: exit=$rc"
[ -f "$OUT/esiti.json" ] || { echo "esiti assenti"; exit 1; }
/usr/bin/python3 -I - "$OUT/esiti.json" <<'PYEOF'
import json, sys
d = json.load(open(sys.argv[1]))["libri"]
def ok(x): return isinstance(x, dict) and x.get("identiche") is True
v = sum(1 for b in d if all(ok(b.get("vista", {}).get(k)) for k in ("n0", "n1", "n0_vo", "n1_vo")))
f = sum(1 for b in d if all(b.get("vista", {}).get(k) is True for k in ("n0_moduloMac_rifFiltrato", "n1_moduloMac_rifFiltrato", "n0_vistaUgualeModulo_byte", "n1_vistaUgualeModulo_byte")))
a = sum(1 for b in d if isinstance(b.get("app"), dict) and ok(b["app"].get("n0")) and ok(b["app"].get("n1")))
s = sum(1 for b in d if isinstance(b.get("app"), dict) and b["app"].get("segmentiIdentici") is True)
n = len(d)
print(f"[2] vista del Mac sulla lettura dell'iPad ↔ vista dell'iPad (4 descrizioni per libro): {v}/{n} libri identici")
print(f"    modulo con le impostazioni del Mac ↔ riferimento filtrato, vista ↔ modulo al byte: {f}/{n}")
print(f"[3] app Mac (importa da sé) ↔ vista dell'iPad (2 descrizioni per libro): {a}/{n} libri identici")
print(f"    lettura del Mac ↔ lettura congelata dell'iPad, segmento per segmento: {s}/{n} identiche")
for b in d:
    app = b.get("app")
    if not (isinstance(app, dict) and ok(app.get("n0")) and ok(app.get("n1"))):
        quota = "vista" if not all(ok(b.get("vista", {}).get(k)) for k in ("n0", "n1")) else "estrattore"
        print(f"    diverso: {b['libro'].split('/')[0]}/… quota={quota} app={json.dumps(app, ensure_ascii=False)[:400] if isinstance(app, dict) else app}")
sys.exit(0 if v == n and f == n else 1)
PYEOF
r2=$?
echo ""; echo "rete_vista_mac $TAG: exit=$r2 (la vista; le differenze dell'app sono elencate sopra, con la loro quota)"
exit $r2
