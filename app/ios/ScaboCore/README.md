# ScaboCore

Libreria SwiftPM con la logica deterministica della **banda OGGI** del piano di
migrazione (`docs/SWIFT_MIGRATION_PLAN.md` § 0.2): taxonomy, plugin Generic,
consumo JSON Layer 1, rendering/segments, theme, storage, measurement. Blindata
da **126 XCTest**.

## Eseguire i test

Comando canonico, dalla cartella del package:

```sh
cd app/ios/ScaboCore
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
```

Esito atteso: `Executed 126 tests, with 0 failures`.

### Perché l'override `DEVELOPER_DIR`

Su una macchina con **Command Line Tools** come developer directory attiva
(`xcode-select -p` → `/Library/Developer/CommandLineTools`), `swift test` nudo
fallisce in build con `no such module 'XCTest'`: la toolchain dei CLT non include
il framework `XCTest`, che vive solo dentro `Xcode.app`. L'override
`DEVELOPER_DIR` indirizza l'invocazione alla toolchain di Xcode senza modificare
lo stato globale né richiedere privilegi, e funziona indipendentemente da dove
punti `xcode-select`. È il modo ripetibile e auto-contenuto per girare i test.

### Alternativa permanente (opzionale, richiede sudo)

Se si preferisce che `swift test` nudo funzioni senza prefisso, puntare una volta
la developer directory a Xcode:

```sh
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
```

Dopodiché `swift test` (senza `DEVELOPER_DIR`) usa la toolchain di Xcode e i 126
test passano. Il comando canonico con `DEVELOPER_DIR` resta valido in entrambi i
casi.
