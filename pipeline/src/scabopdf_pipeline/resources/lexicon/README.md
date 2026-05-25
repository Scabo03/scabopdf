# Italian lexicon resource

This directory bundles a pre-computed Italian wordlist used by post-processing
steps that need to validate whether a candidate string is a real Italian word
(e.g. de-hyphenation, OCR glyph normalisation on `enciclopedia_storica`).

## File

- `italian_wordlist.txt.gz` — gzipped UTF-8 plain text, one lowercase word per
  line, **~898 000 entries** (was ~280 000 before the v2.32 bump that closed
  debt (xi) "Lexicon coverage gap unaccented-only"). The richer wordlist
  includes Italian accented forms (`città`, `perché`, `così`, `libertà`,
  `qualità`, `università`, `più`, `già`, `caffè`, …, ~9 700 accented entries
  total, ~1.1 % of the wordlist), proper names, surnames (Mandrioli, Torrente,
  Patriarca, Pomponio, Gaio, …) and compound words from across the
  paroleitaliane corpus.

## Source and licence

Curated MIT-only union of eleven files from the
[`napolux/paroleitaliane`](https://github.com/napolux/paroleitaliane)
repository, MIT licence (© 2016 Francesco Napoletano):

- `1000_parole_italiane_comuni.txt`
- `60000_parole_italiane.txt`
- `95000_parole_italiane_con_nomi_propri.txt`
- `110000_parole_italiane_con_nomi_propri.txt`
- `280000_parole_italiane.txt`
- `660000_parole_italiane.txt`
- `400_parole_composte.txt`
- `9000_nomi_propri.txt`
- `lista_38000_cognomi.txt`
- `lista_cognomi.txt` (~175 000 Italian and foreign surnames)
- `lista_badwords.txt`

The file `coniugazione_verbi.txt` (~335 000 conjugated verb forms) of the
upstream repository is **deliberately excluded**: it is derived from
[`ian-hamlin/verb-data`](https://github.com/ian-hamlin/verb-data) which is
distributed under [CC BY-SA 3.0](https://creativecommons.org/licenses/by-sa/3.0/),
and bundling it inside our MIT wheel would require either ScaboPDF to adopt
CC BY-SA 3.0 (incompatible with the project's MIT licence) or to ship a
secondary licence file and attribution. The conservative choice is to leave
the conjugated forms out and rely on the lexicon-validated substitution
pipeline to recognise the present-indicative / infinitive form that lives in
the other MIT files. The empirical impact on the ScaboPDF OCR-normalisation
pipeline is negligible: the four EdD storica calibrating fixtures regenerate
byte-equivalently on the dehyphenation step, and `dehyphenate_ocr_aggressive`
catches the same joins it caught before.

A copy of the MIT licence is included by reference here; redistribution
under the MIT terms is preserved.

The choice of a bundled wordlist over a system Hunspell installation is
deliberate. `libhunspell-dev` plus the `hunspell-it` dictionary package require
`sudo apt install` on Debian/Ubuntu, which does not work in CI containers or
read-only deployment environments. A bundled, gzipped wordlist is portable,
reproducible, and roughly 2.2 MB on disk — small enough to ship in the wheel.

If a future session needs Hunspell-grade affix expansion the
`ItalianLexicon` wrapper in `pipeline/src/scabopdf_pipeline/postprocessing/lexicon.py`
exposes a `hunspell()` classmethod hook documented as the path to take.

## Regeneration

```bash
pipeline/.venv/bin/python pipeline/scripts/regenerate_italian_wordlist.py
```

The script downloads the eleven MIT-licensed files from the upstream repo,
deduplicates the union, lowercases every entry, writes the result to
`italian_wordlist.txt.gz`. The file is checked into Git so consumers do not
need network access at install time. Re-generation is a manual, intentional
act; never automate it inside the test suite.
