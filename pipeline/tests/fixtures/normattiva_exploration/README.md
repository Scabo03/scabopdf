# Normattiva — Esplorazione formati di export

Cartella di esplorazione per valutare i formati di export di Normattiva come potenziale ingresso parallelo per ScaboPDF (PDF-native oggi → eventuale XML-native domani).

## Atti scaricati

### Codice Penale
- Riferimento: Regio Decreto 19 ottobre 1930, n. 1398
- URL Normattiva: https://www.normattiva.it/uri-res/N2Ls?urn:nir:stato:regio.decreto:1930-10-19;1398
- Data download: 21-22 maggio 2026
- Modalità export: pulsante "Esporta in Akoma Ntoso" per XML, pulsanti separati per PDF/EPUB/RTF
- **Note**: XML troncato a 3 articoli (probabilmente Normattiva esporta solo la sezione corrente visualizzata, non l'atto intero). PDF/EPUB/RTF risultano completi.

### Legge Capitali
- Riferimento: Legge 5 marzo 2024, n. 21 (interventi a sostegno della competitività dei capitali + delega riforma TUF)
- URL Normattiva: https://www.normattiva.it/uri-res/N2Ls?urn:nir:stato:legge:2024-03-05;21
- Data download: 22 maggio 2026
- Modalità export: pulsante "Esporta in Akoma Ntoso" per XML, pulsanti separati per PDF/EPUB/RTF
- **Note**: 28 articoli, atto recente con modifiche esplicite ad altri atti (TUF, codice civile). Tutti e 4 i formati completi.

### Legge Finanziaria 2007
- Riferimento: Legge 27 dicembre 2006, n. 296 (legge finanziaria 2007)
- URL Normattiva: https://www.normattiva.it/uri-res/N2Ls?urn:nir:stato:legge:2006-12-27;296
- Data download: 22 maggio 2026
- Modalità export: pulsante "Esporta in Akoma Ntoso" per XML, pulsanti separati per PDF/EPUB/RTF
- **Note**: articolo unico con 1307 commi (multivigenza ha abrogato alcuni commi originari, ne sopravvivono 1307 vigenti). Patologia editoriale tipica delle leggi finanziarie italiane. Tutti e 4 i formati completi.

## Formati Akoma Ntoso

L'XML scaricato via "Esporta in Akoma Ntoso" è conforme allo standard OASIS LegalDocML 1.0 con namespace `http://docs.oasis-open.org/legaldocml/ns/akn/3.0`, esteso con vocabolari ELI europei e Normattiva italiani (`gu`, `na`, `nakn`, `nrdfa`).
