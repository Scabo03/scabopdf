# Validation loop — lo scudo sui test

`app/ios/scripts/validate.sh` è l'automatismo unico che esegue **tutti i test
Swift del progetto** e restituisce un verdetto netto verde/rosso. È il gesto
standard **prima e dopo ogni lavoro**: lo scudo che segnala subito le regressioni,
in piedi prima di costruire la reading view (gradino 2).

## Come si lancia

Dalla root del repo (lo script si auto-localizza, quindi funziona da qualsiasi
cartella):

```sh
app/ios/scripts/validate.sh
```

Nessun prerequisito d'ambiente da preparare a mano: lo script imposta
internamente `DEVELOPER_DIR` sulla toolchain di Xcode, quindi non dipende da dove
punti `xcode-select` né da variabili della shell chiamante.

## Cosa esegue

1. **ScaboCore** — i test della libreria SwiftPM via `swift test` (il comando
   canonico del README di ScaboCore, con la toolchain di Xcode). Baseline: 126
   test.
2. **App tests** — il target `ScaboAppTests` (harness W1 + `PdfKitExtractorTests`
   + eventuali test di esplorazione) via `xcodebuild test` sul Simulator
   **iPhone 16 / iOS 26.5**.

Esegue **entrambe** le suite anche se la prima cade, così il verdetto mostra
tutte le rotture in un colpo solo, non solo la prima.

## Cosa significa l'output

Output progressivo durante l'esecuzione (suite passate/fallite in tempo reale),
poi un riepilogo finale:

```
VERDETTO
  ScaboCore    VERDE  126 test, 0 falliti
  App tests    VERDE  9 test, 0 falliti
  ✓ TUTTO VERDE  —  135 test, 0 falliti
```

Se rosso, il riepilogo elenca **quali** test sono caduti e **in quale** suite,
senza dover scavare nel log:

```
VERDETTO
  ScaboCore    ROSSO  127 test, 1 falliti
  App tests    VERDE  9 test, 0 falliti
  Test caduti:
    ScaboCore:
      • -[ScaboCoreTests.SomeTests test_something]
  ✗ ROSSO  —  una o più suite hanno fallito
```

I log completi delle due suite restano in una cartella temporanea, indicata
nell'ultima riga, per l'analisi di dettaglio.

## Exit code

| Code | Significato |
|---|---|
| `0` | Tutto verde |
| `1` | Almeno un test rosso |
| `2` | Prerequisito mancante / fallimento d'infrastruttura (toolchain, build, Simulator assente) |

Usabile sia a mano sia in automatismi futuri (CI): il codice è la fonte di verità.

## Prerequisiti

Se mancano, lo script fallisce con un messaggio esplicito (exit 2), non con un
errore oscuro: Xcode in `/Applications/Xcode.app`, il runtime Simulator
**iOS 26.5** installato, e un device **iPhone 16** su quel runtime.

## Perché NON è agganciato a un hook git

Scelta deliberata: il loop è **separato e invocabile a mano** (o da CI), non
auto-eseguito a ogni commit. La suite app/Simulator (`xcodebuild test`) è lenta
(build + test, uno o due minuti); legarla a ogni commit lo renderebbe penoso.
L'unico hook configurato nel repo è il `.pre-commit-config.yaml` del **pipeline
Python** (`files: ^pipeline/`), orthogonale al lavoro Swift e non toccato da
questo loop.
