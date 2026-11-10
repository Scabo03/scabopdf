# shellcheck shell=bash
#
# esiti_passi.sh — GLI ESITI DEI PASSI di una rete (giro «prove rifatte e granularità», 2026-11-10; rilievo R19 della revisione
# del giro «app unica per Mac, tappa A»: la rete delle generazioni chiudeva verde con due passi fermi). Si include con `source`
# dagli script delle reti; bash 3.2 di macOS, con `set -u` (attenzione: una variabile seguita da un carattere non ASCII, come
# «»», va scritta fra graffe, altrimenti bash 3.2 la legge come un nome più lungo e lo script si ferma).
#
# La regola: un passo è VERDE solo se il suo comando esce con 0 e TUTTE le sue uscite attese ci sono (file non vuoti, o il
# numero di file atteso). Qualunque altro esito lo fa ROSSO, col suo nome, e fa rossa la rete. Un passo che la configurazione
# esclude (per esempio la parità fra generazioni con una generazione sola) si dichiara «non previsto», col motivo, e il
# verdetto finale lo elenca. Una rete senza nessun passo verde è rossa.
#
# PROVA AL CONTRARIO, incorporata (così la si rifà in ogni giro): con la variabile SCABO_RETE_GUASTO
#   ferma:<nome del passo>   il comando del passo non si esegue (un passo fermo);
#   togli:<nome del passo>   un'uscita attesa del passo manca (la prima si cancella; per i conteggi se ne conta una in meno);
# con l'uno e con l'altro guasto la rete deve finire ROSSA, con quel nome (confrontato per intero). Un passo che non ha uscite
# attese da togliere, con `togli`, si chiude col codice 98 («uscita tolta»). Alla fine, con un guasto di prova, la rete guarda
# il passo bersaglio per nome: se è rosso il guasto ha funzionato; se è verde il guasto non ha avuto effetto, e se nessun passo
# con quel nome si è chiuso il nome è sbagliato (o il passo non si esegue in questa configurazione): negli ultimi due casi la
# rete è rossa e lo dice (rilievo R1 della revisione del giro «prove rifatte e granularità»: prima un nome sbagliato, o `togli`
# su un passo senza uscite, finivano verdi). Il controllo per nome vale anche per i passi eseguiti in una sottoshell.
#
# Uso negli script:
#   source "$SCRIPT_DIR/generazioni/esiti_passi.sh"
#   esegui_passo "<nome>" comando argomenti…; rc=$?
#   chiudi_passo "<nome>" "$rc" <file atteso>…                  (verde: codice 0 e ogni file presente e non vuoto)
#   chiudi_passo_conteggio "<nome>" "$rc" <attesi> <trovati>   (verde: codice 0 e trovati = attesi > 0)
#   non_previsto "<nome>" "<motivo>"
#   esito_rete "<rete>" "<etichetta>"; exit $?
# `chiudi_passo*` ritornano 0 se il passo è verde, 1 se è rosso (lo script decide se può proseguire).
RETE_ROSSI=()
RETE_VERDI=()
RETE_NON_PREVISTI=()
RETE_GUASTO="${SCABO_RETE_GUASTO:-}"
[ -n "$RETE_GUASTO" ] && echo "PROVA AL CONTRARIO ATTIVA: SCABO_RETE_GUASTO=${RETE_GUASTO} (la rete deve finire rossa)"

esegui_passo() {
  local nome="$1"; shift
  if [ "$RETE_GUASTO" = "ferma:$nome" ]; then
    echo "    GUASTO DI PROVA: il passo «${nome}» non si esegue"
    return 97
  fi
  "$@"
}

_passo_rosso() {
  RETE_ROSSI+=("$1")
  echo "    ROSSO: passo «${1}» ($2)"
}

chiudi_passo() {
  local nome="$1" rc="$2"; shift 2
  if [ "$RETE_GUASTO" = "togli:$nome" ]; then
    if [ $# -gt 0 ]; then
      rm -f -- "$1"
      echo "    GUASTO DI PROVA: tolta l'uscita «$(basename "$1")» del passo «${nome}»"
    else
      rc=98
      echo "    GUASTO DI PROVA: il passo «${nome}» non ha uscite da togliere: si chiude come se la sua uscita mancasse"
    fi
  fi
  local mancanti="" u
  for u in "$@"; do [ -s "$u" ] || mancanti="$mancanti $(basename "$u")"; done
  if [ "$rc" != 0 ] || [ -n "$mancanti" ]; then
    _passo_rosso "$nome" "codice d'uscita ${rc}${mancanti:+; uscite mancanti o vuote:$mancanti}"
    return 1
  fi
  RETE_VERDI+=("$nome")
  return 0
}

chiudi_passo_conteggio() {
  local nome="$1" rc="$2" attesi="$3" trovati="$4"
  if [ "$RETE_GUASTO" = "togli:$nome" ]; then
    trovati=$((trovati - 1))
    echo "    GUASTO DI PROVA: un'uscita in meno per «${nome}»"
  fi
  if [ "$rc" != 0 ] || [ "$attesi" -le 0 ] || [ "$trovati" != "$attesi" ]; then
    _passo_rosso "$nome" "codice d'uscita ${rc}; uscite ${trovati} su ${attesi} attese"
    return 1
  fi
  RETE_VERDI+=("$nome")
  return 0
}

non_previsto() {
  RETE_NON_PREVISTI+=("$1 — $2")
  echo "    non previsto: «${1}» — $2"
}

esito_rete() {
  local rete="$1" etichetta="$2" x
  echo ""
  echo "Passi verdi: ${#RETE_VERDI[@]}."
  if [ ${#RETE_NON_PREVISTI[@]} -gt 0 ]; then
    echo "Passi non previsti da questa configurazione:"; for x in "${RETE_NON_PREVISTI[@]}"; do echo "  - $x"; done
  fi
  if [ -n "$RETE_GUASTO" ]; then
    local bersaglio="${RETE_GUASTO#*:}" stato="assente"
    for x in ${RETE_VERDI[@]+"${RETE_VERDI[@]}"}; do [ "$x" = "$bersaglio" ] && stato="verde"; done
    for x in ${RETE_ROSSI[@]+"${RETE_ROSSI[@]}"}; do [ "$x" = "$bersaglio" ] && stato="rosso"; done
    case "$stato" in
      verde) RETE_ROSSI+=("guasto di prova «${RETE_GUASTO}» — il passo «${bersaglio}» è finito verde: il guasto non ha avuto effetto") ;;
      assente) RETE_ROSSI+=("guasto di prova «${RETE_GUASTO}» — nessun passo «${bersaglio}» si è chiuso (nome sbagliato o passo non eseguito)") ;;
    esac
  fi
  if [ ${#RETE_ROSSI[@]} -gt 0 ]; then
    echo "PASSI ROSSI (${#RETE_ROSSI[@]}):"; for x in "${RETE_ROSSI[@]}"; do echo "  - $x"; done
    echo "${rete} ${etichetta}: ROSSO, exit=1"
    return 1
  fi
  if [ ${#RETE_VERDI[@]} -eq 0 ]; then
    echo "${rete} ${etichetta}: ROSSO (nessun passo compiuto), exit=1"
    return 1
  fi
  echo "${rete} ${etichetta}: VERDE, exit=0"
  return 0
}
