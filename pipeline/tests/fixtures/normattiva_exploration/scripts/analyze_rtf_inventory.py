"""Count RTF structural markers in the three Normattiva fixtures.

Reports occurrences of every RTF control word that carries structural
information: tables (\trowd), lists (\listtable, \pn), sections (\sectd),
headers/footers (\header, \footer), footnotes (\footnote), images (\pict),
bookmarks (\*\bkmkstart), hyperlinks (HYPERLINK), styles (\sN), etc.

Outputs a Markdown-friendly table to stdout.
"""

from __future__ import annotations

import re
from pathlib import Path

FIXTURES_DIR = Path(__file__).resolve().parent.parent
FILES = {
    "codice_penale": FIXTURES_DIR / "codice_penale" / "codice_penale.rtf",
    "legge_capitali": FIXTURES_DIR / "legge_capitali" / "legge_capitali.rtf",
    "legge_finanziaria_2007": FIXTURES_DIR / "legge_finanziaria_2007" / "legge_finanziaria_2007.rtf",
}


MARKERS: dict[str, str] = {
    # paragraph + structure
    "par_break_par": r"\\par\b",
    "paragraph_default_pard": r"\\pard\b",
    "style_apply_sN": r"\\s\d+\b",
    "section_sectd": r"\\sectd\b",
    "section_break_sect": r"\\sect\b",
    # tables
    "table_row_trowd": r"\\trowd\b",
    "table_row_end_row": r"\\row\b",
    "table_cell_cell": r"\\cell\b",
    # lists
    "list_pn_legacy": r"\\pn\b",
    "list_listoverride": r"\\listoverride\b",
    "list_ls_apply": r"\\ls\d+\b",
    # page metadata
    "header_decl": r"\\header\b",
    "footer_decl": r"\\footer\b",
    # footnotes / notes
    "footnote_footnote": r"\\footnote\b",
    "annotation_atnref": r"\\atnref\b",
    # images / embeds
    "pict_image": r"\\pict\b",
    "object_embed": r"\\object\b",
    # bookmarks
    "bookmark_start": r"\{\\\*\\bkmkstart\b",
    "bookmark_end": r"\\bkmkend\b",
    # hyperlinks
    "hyperlink_field": r"HYPERLINK\b",
    "field_fldinst": r"\\fldinst\b",
    "field_result_fldrslt": r"\\fldrslt\b",
    # bold / italic / underline (typographic)
    "bold_b": r"\\b\b",
    "italic_i": r"\\i\b",
    "underline_ul": r"\\ul\b",
    # font size apply
    "font_size_fs": r"\\fs\d+\b",
    "font_apply_fN": r"\\f\d+\b",
    # unicode escape
    "unicode_u": r"\\u-?\d+\?",
    # specific text patterns (case-sensitive)
    "literal_Art_dot": r"\bArt\.\s*\d",
    "literal_Capo_roman": r"\bCapo\s+[IVXLC]+\b",
    "literal_Titolo_roman": r"\bTitolo\s+[IVXLC]+\b",
    "literal_Articolo": r"\bArticolo\s+\d",
    "literal_comma_number": r"^\s*\d+\.\s",  # multiline below
}


def count_markers(text: str) -> dict[str, int]:
    out: dict[str, int] = {}
    for name, pat in MARKERS.items():
        flags = re.MULTILINE if name == "literal_comma_number" else 0
        out[name] = len(re.findall(pat, text, flags=flags))
    return out


def main() -> None:
    results: dict[str, dict[str, int]] = {}
    sizes: dict[str, int] = {}
    for label, path in FILES.items():
        raw = path.read_bytes()
        sizes[label] = len(raw)
        text = raw.decode("latin-1", errors="replace")
        results[label] = count_markers(text)

    names = list(MARKERS.keys())
    print(f"{'marker':<28}{'codice_penale':>16}{'legge_capitali':>18}{'legge_fin_2007':>18}")
    print("-" * 80)
    for n in names:
        cp = results["codice_penale"][n]
        lc = results["legge_capitali"][n]
        lf = results["legge_finanziaria_2007"][n]
        print(f"{n:<28}{cp:>16}{lc:>18}{lf:>18}")

    print()
    print(f"{'file_size_bytes':<28}", end="")
    for label in ("codice_penale", "legge_capitali", "legge_finanziaria_2007"):
        width = 18 if label != "codice_penale" else 16
        print(f"{sizes[label]:>{width}}", end="")
    print()


if __name__ == "__main__":
    main()
