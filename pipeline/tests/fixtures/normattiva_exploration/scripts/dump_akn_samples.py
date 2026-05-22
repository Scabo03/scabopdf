"""Extract clean (no-xmlns-flood) samples from Akoma Ntoso files.

Outputs:
- one full article + authorialNote per act, captured in samples/<act>_article.xml
- one <mod> example per act, captured in samples/<act>_mod.xml
- one <eventRef> + one <passiveRef> per act
"""

from __future__ import annotations

import re
from pathlib import Path

from lxml import etree

NS = {
    "akn": "http://docs.oasis-open.org/legaldocml/ns/akn/3.0",
    "nakn": "http://normattiva.it/akn/vocabulary",
}

FIXTURES = {
    "codice_penale": Path(
        "/home/scabo/projects/ScaboPDF/pipeline/tests/fixtures/"
        "normattiva_exploration/codice_penale/codice_penale.xml"
    ),
    "legge_capitali": Path(
        "/home/scabo/projects/ScaboPDF/pipeline/tests/fixtures/"
        "normattiva_exploration/legge_capitali/legge_capitali.xml"
    ),
    "legge_finanziaria_2007": Path(
        "/home/scabo/projects/ScaboPDF/pipeline/tests/fixtures/"
        "normattiva_exploration/legge_finanziaria_2007/legge_finanziaria_2007.xml"
    ),
}

OUT = Path(
    "/home/scabo/projects/ScaboPDF/pipeline/tests/fixtures/"
    "normattiva_exploration/scripts/samples"
)


def serialize_clean(el: etree._Element) -> str:
    """Pretty-print stripping every xmlns:* declaration from output text.

    The element is re-rooted as a free-standing subtree so we drop most
    inherited xmlns declarations; remaining default xmlns survives, we
    strip it via regex post-hoc.
    """
    s = etree.tostring(el, pretty_print=True, encoding="unicode")
    # strip every xmlns:foo="..." or xmlns="..." declaration that lxml
    # injected because the subtree carries an inherited namespace chain
    s = re.sub(r'\s+xmlns(:\w+)?="[^"]+"', "", s)
    return s


def main() -> int:
    OUT.mkdir(exist_ok=True, parents=True)

    for name, p in FIXTURES.items():
        tree = etree.parse(str(p))
        root = tree.getroot()

        # ARTICLE SAMPLE
        if name == "codice_penale":
            # take art 575 attachment
            atts = root.findall(".//akn:attachment", NS)
            target = next(
                a for a in atts
                if (d := a.find("akn:doc", NS)) is not None
                and d.get("name") == "Codice Penale-art. 575"
            )
        elif name == "legge_capitali":
            target = root.find('.//akn:article[@eId="art_3"]', NS)
        else:  # finanziaria
            # take a small comma with abrogazione + ref, e.g. para_5 (abrogated)
            target = root.find('.//akn:paragraph[@eId="art_1__para_1"]', NS)

        (OUT / f"{name}_article.xml").write_text(serialize_clean(target))

        # MOD SAMPLE (only Capitali has mods)
        mods = root.findall(".//akn:mod", NS)
        if mods:
            (OUT / f"{name}_mod_first.xml").write_text(serialize_clean(mods[0]))
            (OUT / f"{name}_mod_second.xml").write_text(serialize_clean(mods[1]))

        # eventRef (top-level lifecycle)
        act = root.find("akn:act", NS)
        life = act.find("akn:meta/akn:lifecycle", NS)
        if life is not None and len(life):
            (OUT / f"{name}_eventref_first.xml").write_text(serialize_clean(life[0]))
            (OUT / f"{name}_eventref_last.xml").write_text(serialize_clean(life[-1]))

        # passiveRef
        refs = act.find("akn:meta/akn:references", NS)
        if refs is not None:
            pr = refs.find("akn:passiveRef", NS)
            orig = refs.find("akn:original", NS)
            if pr is not None:
                (OUT / f"{name}_passiveref.xml").write_text(serialize_clean(pr))
            if orig is not None:
                (OUT / f"{name}_original.xml").write_text(serialize_clean(orig))

        # textualMod (analysis block)
        ana_amod = act.find("akn:meta/akn:analysis/akn:activeModifications/akn:textualMod", NS)
        ana_pmod = act.find("akn:meta/akn:analysis/akn:passiveModifications/akn:textualMod", NS)
        if ana_amod is not None:
            (OUT / f"{name}_active_textualmod.xml").write_text(serialize_clean(ana_amod))
        if ana_pmod is not None:
            (OUT / f"{name}_passive_textualmod.xml").write_text(serialize_clean(ana_pmod))

        # preface
        pref = act.find("akn:preface", NS)
        if pref is not None:
            (OUT / f"{name}_preface.xml").write_text(serialize_clean(pref))

        # preamble
        preamb = act.find("akn:preamble", NS)
        if preamb is not None:
            (OUT / f"{name}_preamble.xml").write_text(serialize_clean(preamb))

        # FRBR triplet
        ident = act.find("akn:meta/akn:identification", NS)
        if ident is not None:
            (OUT / f"{name}_identification.xml").write_text(serialize_clean(ident))

    print(f"wrote samples to {OUT}")
    return 0


if __name__ == "__main__":
    main()
