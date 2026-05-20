"""Measure the empirical impact of OCR Pass 0 contextual rewrites + the
expanded structural-marker dictionary + the ``1→r`` substitution on the
four EdD storica calibrating fixtures.

Runs the full Layer 1 pipeline on each fixture and reports:
- Total Transformations produced by ``normalize_ocr_with_dictionary``
- Breakdown by category: structural-marker, contextual-rewrite, per-token
- Examples of each category (first three occurrences)

Not part of production code, not exercised by tests.
"""

from __future__ import annotations

import sys
import time
from collections import Counter
from pathlib import Path

from scabopdf_pipeline.apparatus import resolve_apparatus
from scabopdf_pipeline.classification import classify
from scabopdf_pipeline.emission import convert_document
from scabopdf_pipeline.extraction import extract
from scabopdf_pipeline.postprocessing import apply_post_processing
from scabopdf_pipeline.postprocessing.ocr_substitutions import (
    get_contextual_rewrites,
    get_structural_marker_dictionary,
)
from scabopdf_pipeline.profiles.enciclopedia_storica import EnciclopediaStoricaProfile
from scabopdf_pipeline.profiling.profile import DocumentProfile
from scabopdf_pipeline.reconstruction import reconstruct

FIXTURES_DIR = (
    Path(__file__).resolve().parents[1] / "tests" / "fixtures" / "private"
)

FIXTURES = [
    "edd_eccesso_potere.pdf",
    "edd_lavoro.pdf",
    "edd_pagamento.pdf",
    "edd_azienda.pdf",
]


def _make_profile(plugin: EnciclopediaStoricaProfile) -> DocumentProfile:
    return DocumentProfile(
        profile_id=plugin.profile_id,
        editorial_family=plugin.editorial_family,
        genre=plugin.genre,
        layouts_available=["L1", "L2", "L3", "L4"],
        layouts_disabled=plugin.get_layouts_disabled(),
        post_processing=plugin.get_post_processing(),
        categories_emitted=plugin.get_categories(),
        confidence=0.90,
        warnings=[],
    )


def _categorise_transformation(trans, marker_dict, contextual_originals) -> str:
    if trans.step_id == "normalize_ocr_with_dictionary":
        if (trans.original, trans.normalized) in marker_dict:
            return "structural_marker"
        for original, _replaced, _description in contextual_originals:
            if trans.original == original:
                return "contextual_rewrite"
        return "per_token"
    return trans.step_id


def main() -> int:
    plugin = EnciclopediaStoricaProfile()
    profile = _make_profile(plugin)
    marker_dict = dict(get_structural_marker_dictionary())
    rewrites = get_contextual_rewrites()

    print("=" * 100)
    print("OCR Pass 0 + structural-marker dict expansion empirical impact")
    print("=" * 100)
    for fname in FIXTURES:
        path = FIXTURES_DIR / fname
        if not path.exists():
            print(f"--> SKIP {fname} (missing)")
            continue
        t0 = time.monotonic()
        extraction = extract(path)
        classified = classify(extraction, profile, plugin)
        document = reconstruct(extraction, classified, profile, plugin)
        document = resolve_apparatus(document, extraction, classified, plugin)
        document = apply_post_processing(document, extraction, classified, plugin)
        convert_document(document, extraction, profile, path)

        by_step: Counter[str] = Counter()
        normalize_examples: dict[str, list[tuple[str, str]]] = {}
        for trans in document.transformations:
            by_step[trans.step_id] += 1
            if trans.step_id != "normalize_ocr_with_dictionary":
                continue
            if (trans.original, trans.normalized) in marker_dict.items() or (
                trans.original in marker_dict and marker_dict[trans.original] == trans.normalized
            ):
                cat = "structural_marker"
            else:
                cat = "contextual_or_token"
                # Verify if it matches a contextual rewrite description.
                for pattern, _repl, description in rewrites:
                    if pattern.fullmatch(trans.original):
                        cat = f"contextual:{description}"
                        break
            normalize_examples.setdefault(cat, []).append(
                (trans.original, trans.normalized)
            )

        elapsed = time.monotonic() - t0
        print(
            f"\n--- {fname} ({extraction.page_count}pp, {elapsed:.1f}s, "
            f"{len(document.transformations)} total Transformations) ---"
        )
        for step_id, count in by_step.most_common():
            print(f"  {step_id:>40}: {count}")
        if "normalize_ocr_with_dictionary" in by_step:
            print(
                f"  normalize_ocr breakdown by category (first 3 examples each):"
            )
            for cat, examples in sorted(normalize_examples.items()):
                print(f"    {cat}: {len(examples)} occurrences")
                for orig, norm in examples[:3]:
                    print(f"      {orig!r} -> {norm!r}")

    return 0


if __name__ == "__main__":
    sys.exit(main())
