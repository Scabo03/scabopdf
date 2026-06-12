#!/usr/bin/env bash
#
# validate.sh — Validation loop (lo "scudo") della migrazione Swift.
#
# Esegue TUTTI i test Swift del progetto e produce un verdetto unico verde/rosso:
#
#   1) ScaboCore   — i test della libreria SwiftPM via `swift test`
#                    (toolchain di Xcode, comando canonico del README di ScaboCore).
#   2) App tests   — il target `ScaboAppTests` (harness W1 + PdfKitExtractorTests
#                    + eventuali test di esplorazione) via `xcodebuild test` sul
#                    Simulator iPhone 16 / iOS 26.5.
#
# Aggrega i due esiti in un riepilogo conciso (totale / passati / falliti, e in
# rosso QUALI test sono caduti e in quale suite) e restituisce un exit code netto:
#   0  → tutto verde
#   1  → almeno un test rosso
#   2  → prerequisito mancante / fallimento d'infrastruttura (build, toolchain,
#        Simulator assente)
#
# È auto-contenuto: imposta `DEVELOPER_DIR` internamente (non dipende dalla shell
# chiamante) e si localizza da solo la root del repo, quindi funziona lanciato da
# qualsiasi cartella, tipicamente da root:  app/ios/scripts/validate.sh
#
# NON è agganciato ad alcun hook git: la suite app/Simulator è lenta e va invocata
# a mano (o da CI), non a ogni commit. Vedi docs/VALIDATION_LOOP.md.
#
# Questo è lo scudo sui test ESISTENTI. I guardiani su contenuto-perso e ordine di
# lettura arriveranno col gradino 2 (reading view), dove avranno cosa misurare.
#

# Niente `set -e`: vogliamo eseguire ENTRAMBE le suite e aggregare, anche se la
# prima cade. Catturiamo gli exit code esplicitamente.
set -uo pipefail

# ── Toolchain: auto-contenuta, indipendente dall'ambiente del chiamante ──────────
export DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"

# ── Configurazione ──────────────────────────────────────────────────────────────
DEVICE_NAME="iPhone 16"
RUNTIME_LABEL="iOS 26.5"
SCHEME="ScaboApp"

# ── Localizzazione della root del repo dalla posizione di questo script ──────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"   # app/ios/scripts → root
CORE_DIR="$REPO_ROOT/app/ios/ScaboCore"
PROJECT="$REPO_ROOT/app/ios/ScaboPDF.xcodeproj"

# ── Log temporanei (per estrarre il dettaglio dei fallimenti) ────────────────────
LOG_DIR="$(mktemp -d "${TMPDIR:-/tmp}/scabo_validate.XXXXXX")"
CORE_LOG="$LOG_DIR/scabocore.log"
APP_LOG="$LOG_DIR/app.log"

# ── Colori (disattivati se non si scrive su un terminale) ────────────────────────
if [ -t 1 ] && command -v tput >/dev/null 2>&1 && [ -n "$(tput colors 2>/dev/null || echo)" ]; then
  C_GREEN="$(tput setaf 2)"; C_RED="$(tput setaf 1)"; C_YELLOW="$(tput setaf 3)"
  C_BOLD="$(tput bold)"; C_RST="$(tput sgr0)"
else
  C_GREEN=""; C_RED=""; C_YELLOW=""; C_BOLD=""; C_RST=""
fi

say() { printf '%s\n' "$*"; }
hr()  { printf '%s\n' "════════════════════════════════════════════════════════════"; }

die_prereq() {
  say ""
  say "${C_RED}${C_BOLD}✗ PREREQUISITO MANCANTE${C_RST}"
  say "${C_RED}  $*${C_RST}"
  say "  (log: $LOG_DIR)"
  exit 2
}

# ── Prerequisiti: falliamo con un messaggio esplicito, non un errore oscuro ──────
check_prereqs() {
  [ -d "$DEVELOPER_DIR" ] \
    || die_prereq "Xcode non trovato in $DEVELOPER_DIR — installa Xcode 26.5."
  command -v xcodebuild >/dev/null 2>&1 \
    || die_prereq "xcodebuild non disponibile sotto DEVELOPER_DIR=$DEVELOPER_DIR."
  command -v xcrun >/dev/null 2>&1 \
    || die_prereq "xcrun non disponibile."
  command -v swift >/dev/null 2>&1 \
    || die_prereq "swift non disponibile sotto DEVELOPER_DIR=$DEVELOPER_DIR."
  [ -f "$CORE_DIR/Package.swift" ] \
    || die_prereq "ScaboCore non trovato: manca $CORE_DIR/Package.swift."
  [ -d "$PROJECT" ] \
    || die_prereq "Progetto Xcode non trovato: $PROJECT."

  # Runtime iOS 26.5 installato?
  if ! xcrun simctl list runtimes 2>/dev/null | grep -q "$RUNTIME_LABEL"; then
    die_prereq "Runtime Simulator '$RUNTIME_LABEL' non installato. \
In Xcode → Settings → Components, scarica iOS 26.5."
  fi
  # Device 'iPhone 16' presente sotto iOS 26.5?
  if ! xcrun simctl list devices available 2>/dev/null \
        | awk -v r="-- $RUNTIME_LABEL --" '$0 ~ r {f=1; next} /^-- /{f=0} f' \
        | grep -q "$DEVICE_NAME ("; then
    die_prereq "Simulatore '$DEVICE_NAME' su '$RUNTIME_LABEL' non disponibile. \
Crealo da Xcode → Window → Devices and Simulators."
  fi
}

# ── Parsing dell'output XCTest (uguale per swift test e xcodebuild) ──────────────
# Legge dal log l'ULTIMA riga "Executed N tests, with M failures": è il totale
# complessivo dell'invocazione. Scrive N e M nelle due variabili nominate.
# M = -1 segnala "nessun riepilogo trovato" → fallimento di build/infrastruttura.
parse_summary() {
  local log="$1" __tot="$2" __fail="$3" line tot fail
  line="$(grep -E 'Executed [0-9]+ test' "$log" 2>/dev/null | tail -1)"
  if [ -z "$line" ]; then
    tot=0; fail=-1
  else
    tot="$(printf '%s' "$line" | sed -E 's/.*Executed ([0-9]+) test.*/\1/')"
    fail="$(printf '%s' "$line" | sed -E 's/.*with ([0-9]+) failure.*/\1/')"
  fi
  printf -v "$__tot" '%s' "$tot"
  printf -v "$__fail" '%s' "$fail"
}

# Nomi dei test caduti (univoci) da un log XCTest.
list_failures() {
  grep -E "Test Case '.*' failed" "$1" 2>/dev/null \
    | sed -E "s/.*Test Case '([^']*)' failed.*/\1/" \
    | sort -u
}

# ── Esecuzione: ScaboCore ────────────────────────────────────────────────────────
CORE_RC=1; CORE_TOTAL=0; CORE_FAILS=0
run_core() {
  say "${C_BOLD}[1/2] ScaboCore — swift test (toolchain Xcode)…${C_RST}"
  ( cd "$CORE_DIR" && swift test ) 2>&1 | tee "$CORE_LOG" \
    | grep --line-buffered -E "Test Suite '.*' (passed|failed)|Test Case '.*' failed|error:" \
    | sed 's/^/    /'
  CORE_RC=${PIPESTATUS[0]}
  parse_summary "$CORE_LOG" CORE_TOTAL CORE_FAILS
}

# ── Esecuzione: target app sul Simulator ─────────────────────────────────────────
APP_RC=1; APP_TOTAL=0; APP_FAILS=0
run_app() {
  say ""
  say "${C_BOLD}[2/2] App — xcodebuild test (ScaboApp · $DEVICE_NAME · $RUNTIME_LABEL)…${C_RST}"
  say "    (build + test: può richiedere uno o due minuti)"
  xcodebuild test \
      -project "$PROJECT" \
      -scheme "$SCHEME" \
      -destination "platform=iOS Simulator,name=$DEVICE_NAME,OS=26.5" \
      2>&1 | tee "$APP_LOG" \
    | grep --line-buffered -E "Test Suite '.*' (passed|failed)|Test Case '.*' failed|^\*\* (TEST|BUILD)|error:" \
    | sed 's/^/    /'
  APP_RC=${PIPESTATUS[0]}
  parse_summary "$APP_LOG" APP_TOTAL APP_FAILS
}

# ── Riga di verdetto per una suite ───────────────────────────────────────────────
# $1 nome, $2 rc, $3 total, $4 fails
arm_line() {
  local name="$1" rc="$2" tot="$3" fails="$4"
  if [ "$rc" -eq 0 ]; then
    printf '  %-12s %s%s%s  %s test, 0 falliti\n' "$name" "$C_GREEN" "VERDE" "$C_RST" "$tot"
  elif [ "$fails" = "-1" ]; then
    printf '  %-12s %s%s%s  build/infrastruttura fallita (nessun test eseguito)\n' \
      "$name" "$C_RED" "ROSSO" "$C_RST"
  else
    printf '  %-12s %s%s%s  %s test, %s%s falliti%s\n' \
      "$name" "$C_RED" "ROSSO" "$C_RST" "$tot" "$C_RED" "$fails" "$C_RST"
  fi
}

main() {
  hr
  say "${C_BOLD}VALIDATION LOOP — scudo sui test esistenti${C_RST}"
  say "  repo: $REPO_ROOT"
  hr
  check_prereqs

  run_core
  run_app

  say ""
  hr
  say "${C_BOLD}VERDETTO${C_RST}"
  hr
  arm_line "ScaboCore" "$CORE_RC" "$CORE_TOTAL" "$CORE_FAILS"
  arm_line "App tests" "$APP_RC" "$APP_TOTAL" "$APP_FAILS"

  local overall_rc=0
  if [ "$CORE_RC" -ne 0 ] || [ "$APP_RC" -ne 0 ]; then
    overall_rc=1
  fi

  if [ "$overall_rc" -ne 0 ]; then
    say ""
    say "${C_RED}${C_BOLD}  Test caduti:${C_RST}"
    if [ "$CORE_RC" -ne 0 ]; then
      say "    ${C_YELLOW}ScaboCore:${C_RST}"
      if [ "$CORE_FAILS" = "-1" ]; then
        say "      (build fallita — vedi $CORE_LOG)"
      else
        list_failures "$CORE_LOG" | sed 's/^/      • /'
      fi
    fi
    if [ "$APP_RC" -ne 0 ]; then
      say "    ${C_YELLOW}App tests:${C_RST}"
      if [ "$APP_FAILS" = "-1" ]; then
        say "      (build fallita — vedi $APP_LOG)"
      else
        list_failures "$APP_LOG" | sed 's/^/      • /'
      fi
    fi
  fi

  hr
  if [ "$overall_rc" -eq 0 ]; then
    local tot=$(( CORE_TOTAL + APP_TOTAL ))
    say "  ${C_GREEN}${C_BOLD}✓ TUTTO VERDE${C_RST}  —  $tot test, 0 falliti"
  else
    say "  ${C_RED}${C_BOLD}✗ ROSSO${C_RST}  —  una o più suite hanno fallito (vedi sopra)"
  fi
  say "  Log completi: $LOG_DIR"
  hr
  exit "$overall_rc"
}

main "$@"
