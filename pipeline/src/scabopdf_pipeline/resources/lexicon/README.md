# Italian lexicon resource

This directory bundles a pre-computed Italian wordlist used by post-processing
steps that need to validate whether a candidate string is a real Italian word
(e.g. de-hyphenation, OCR glyph normalisation on `enciclopedia_storica`).

## File

- `italian_wordlist.txt.gz` — gzipped UTF-8 plain text, one lowercase word per
  line, ~280 000 entries. Includes inflected forms (verbs, plurals, gendered
  adjectives) so the lexicon recognises common surface forms directly without
  the affix expansion that a full Hunspell installation would otherwise perform.

## Source and licence

Extracted from the [`napolux/paroleitaliane`](https://github.com/napolux/paroleitaliane)
repository, file `paroleitaliane/280000_parole_italiane.txt`, MIT licence
(© 2016 Francesco Napoletano). A copy of the MIT licence is included by
reference here; redistribution under the MIT terms is preserved.

The choice of a bundled wordlist over a system Hunspell installation is
deliberate. `libhunspell-dev` plus the `hunspell-it` dictionary package require
`sudo apt install` on Debian/Ubuntu, which does not work in CI containers or
read-only deployment environments. A bundled, gzipped wordlist is portable,
reproducible, and roughly 700 KB on disk — small enough to ship in the wheel.

If a future session needs Hunspell-grade affix expansion the
`ItalianLexicon` wrapper in `pipeline/src/scabopdf_pipeline/postprocessing/lexicon.py`
exposes a `hunspell()` classmethod hook documented as the path to take.

## Regeneration

```bash
curl -sL https://raw.githubusercontent.com/napolux/paroleitaliane/master/paroleitaliane/280000_parole_italiane.txt -o /tmp/parole_italiane.txt
gzip -9 -c /tmp/parole_italiane.txt > pipeline/src/scabopdf_pipeline/resources/lexicon/italian_wordlist.txt.gz
```

The file is checked into Git so consumers do not need network access at install
time. Re-generation is a manual, intentional act; never automate it inside the
test suite.
