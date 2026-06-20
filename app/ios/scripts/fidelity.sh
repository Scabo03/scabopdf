#!/usr/bin/env bash
#
# fidelity.sh — comando del banco: verifica la FEDELTA' del CONTENUTO di ScaboPDF
# su un volume vero del corpus, contro riferimenti indipendenti (PyMuPDF + docling).
#
# Lega i due pezzi:
#   1) DUMP: esegue la pipeline REALE on-device (PdfKitExtractor → buildDocumentFromPdf)
#      sul Simulator iPad e scrive il documento come JSON (Codable) — via il test
#      `RealPdfBenchTests/test_fidelityDump_fromRequest`, parametrizzato da un file
#      di richiesta a path fisso (il processo-test sul Simulator NON eredita l'env
#      della shell, ma legge il filesystem host: il file-richiesta è il canale).
#   2) ANALISI: `scripts/fidelity_report.py` confronta il dump col PDF e produce un
#      referto leggibile (completezza, struttura, ordine vs docling).
#
# Uso:  app/ios/scripts/fidelity.sh <NomePDF> [START:END]
#   <NomePDF>    file nel corpus (es. Marotta.pdf)
#   [START:END]  intervallo pagine 0-based della zona a 2 colonne (indice) per
#                l'asse ORDINE/STRUTTURA vs docling (cautela 3). Omesso → asse saltato.
#
# Copyright: PDF letti da SCABO_CORPUS_DIR (fuori repo), referto e dump scritti in
# SCABO_BENCH_OUT (fuori repo). NIENTE PDF né testo derivato entra nel repo.
#
set -euo pipefail

PDF_NAME="${1:?uso: fidelity.sh <NomePDF> [START:END]}"
ORDER_PAGES="${2:-}"
CORPUS="${SCABO_CORPUS_DIR:-$HOME/Developer/scabopdf-triple-take/originals}"
OUT="${SCABO_BENCH_OUT:-/tmp/scabo_bench}"
REQUEST="${SCABO_BENCH_REQUEST:-/tmp/scabo_bench_request.json}"  # concordato col test Swift
TOOLS_PY="${SCABO_TOOLS_PYTHON:-$HOME/Developer/scabopdf-tools-venv/bin/python}"
SIM="${SCABO_SIM:-iPad Pro 11-inch (M5)}"
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
HERE="$(cd "$(dirname "$0")/.." && pwd)"   # .../app/ios
STEM="${PDF_NAME%.pdf}"

mkdir -p "$OUT"
printf '{"corpusDir":"%s","outDir":"%s","pdfs":["%s"]}\n' "$CORPUS" "$OUT" "$PDF_NAME" > "$REQUEST"

echo "[fidelity] 1/2 dump pipeline reale di $PDF_NAME sul Simulator $SIM ..."
if ! xcodebuild test -project "$HERE/ScaboPDF.xcodeproj" -scheme ScaboApp \
        -destination "platform=iOS Simulator,name=$SIM" -derivedDataPath /tmp/scabo_dd \
        CODE_SIGNING_ALLOWED=NO \
        -only-testing:ScaboAppTests/RealPdfBenchTests/test_fidelityDump_fromRequest \
        > /tmp/scabo_fidelity_build.log 2>&1; then
    echo "[fidelity] dump FALLITO — vedi /tmp/scabo_fidelity_build.log" >&2
    exit 1
fi
[ -f "$OUT/$STEM.scabopdf.json" ] || { echo "[fidelity] dump assente: $OUT/$STEM.scabopdf.json" >&2; exit 1; }

echo "[fidelity] 2/2 analisi vs PyMuPDF${ORDER_PAGES:+ + docling $ORDER_PAGES} ..."
args=(--pdf "$CORPUS/$PDF_NAME" --dump "$OUT/$STEM.scabopdf.json" --name "$STEM"
      --report "$OUT/$STEM.fidelity.txt")
[ -n "$ORDER_PAGES" ] && args+=(--order-pages "$ORDER_PAGES")
PATH="/opt/homebrew/bin:$PATH" "$TOOLS_PY" "$HERE/scripts/fidelity_report.py" "${args[@]}"

echo "[fidelity] referto → $OUT/$STEM.fidelity.txt (fuori repo)"
