#!/usr/bin/env bash
#
# prepara_llama.sh — mette in Vendor/llama.xcframework la libreria llama.cpp della RELEASE UFFICIALE b11429 di ggml-org,
# dopo averne verificato l'impronta contro quella pubblicata (giro «costruzione della linea Mac», 2026-10-16).
#
#   uso: scripts/prepara_llama.sh                         (scarica dall'indirizzo ufficiale)
#        SCABOMAC_LLAMA_ZIP=/percorso/dello/zip scripts/prepara_llama.sh   (usa uno zip già scaricato e verificato)
#
# Fonte: https://github.com/ggml-org/llama.cpp/releases/tag/b11429 — asset llama-b11429-xcframework.zip, 61.992.495 byte,
# sha256 dichiarato dalla release (API di GitHub): vedi SHA qui sotto. La libreria a monte ha solo la firma ad hoc del
# linker (nessuna identità): si firma con l'app (scripts/build_app.sh). La cartella Vendor/ non entra nel repo (.gitignore): il binario non si versiona.
set -euo pipefail
cd "$(dirname "$0")/.."
TAG=b11429
URL="https://github.com/ggml-org/llama.cpp/releases/download/$TAG/llama-$TAG-xcframework.zip"
SHA=e26a6a0a813f5760fe45834ce239d5b525e4e2442d4fd017221d9f0438383174
DEST=Vendor/llama.xcframework
if [ -d "$DEST" ]; then echo "già presente: $DEST"; exit 0; fi
TMP="$(mktemp -d)"
ZIP="${SCABOMAC_LLAMA_ZIP:-}"
if [ -z "$ZIP" ]; then
  echo "scaricamento dall'indirizzo ufficiale: $URL"
  curl -fL --max-time 900 -o "$TMP/llama.zip" "$URL"
  ZIP="$TMP/llama.zip"
fi
GOT="$(shasum -a 256 "$ZIP" | cut -d' ' -f1)"
if [ "$GOT" != "$SHA" ]; then
  echo "IMPRONTA DIVERSA da quella pubblicata: $GOT (attesa $SHA). Niente installato."
  rm -rf "${TMP:?}"
  exit 1
fi
echo "impronta verificata: $GOT"
unzip -q "$ZIP" -d "$TMP/x"
mkdir -p Vendor
mv "$TMP/x/build-apple/llama.xcframework" "$DEST"
rm -rf "${TMP:?}"
echo "pronto: $DEST"
