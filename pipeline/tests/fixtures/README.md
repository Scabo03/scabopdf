# pipeline/tests/fixtures

Materiali binari per i test della pipeline Python.

## Struttura

- `private/` — **gitignored**. Ospita i PDF coperti da copyright (Codici Giuffrè, voci EdD, manuali giuridici, articoli DeJure, ecc.) che ogni sviluppatore tiene in locale e non possono essere ridistribuiti nel repo. La regola di esclusione vive nel `.gitignore` di root del progetto come `pipeline/tests/fixtures/private/`.
- `public/` — **previsto** ma non ancora creato. Ospiterà eventuali PDF sintetici o liberamente distribuibili (generati al volo con PyMuPDF, oppure documenti senza restrizioni) versionati nel repo per i test di integrazione riproducibili.

## Convenzioni

I test unit costruiscono i loro input (`ExtractionResult`, `list[ClassifiedBlock]`, ecc.) direttamente in memoria e non dipendono da questa cartella. Le fixture binarie servono ai test di integrazione round-trip dell'extraction (ARCHITECTURE.md § 3 checklist), al branch del warning Custom-encoding senza ToUnicode CMap (ARCHITECTURE.md § 3.5) e ai test profile-specific dei plugin di corpus.

I path verso i file in `private/` non vanno hard-coded nei test: i test che dipendono da una fixture privata devono fare uno `skip` esplicito se il file non è presente, così la suite resta verde anche su una clone fresca del repo senza fixture private locali.
