"""Property-based tests for the AKN health detector.

Hypothesis strategies generate synthetic Akoma Ntoso XML strings that
exercise the four-branch verdict logic across a wide range of
(body_article_count, attachment_doc_count, attachment_paragraph_count)
configurations. The strategies are calibrated to stay close to the
empirical distribution of the nine Normattiva fixtures so that
generated cases are realistic; an explicit `assume` guard rejects
configurations that fall outside the calibrated thresholds.

The properties asserted are:

* **Threshold respect** — body_article >= OK_MIN never produces
  FRAGMENTED.
* **Stub + fragmentation** — body_article <= STUB_MAX AND attachment
  doc/paragraph counts both above their thresholds always produces
  FRAGMENTED.
* **Counter accuracy** — the structural summary's counters reflect the
  synthetic input exactly, modulo whitespace text nodes which are not
  counted.
* **Non-AKN namespace** — any root in a namespace different from the
  OASIS AKN one always produces NOT_AKN.
* **Malformed XML survives** — random byte sequences never raise,
  always yield INVALID_XML.
"""

from __future__ import annotations

from pathlib import Path

import pytest
from hypothesis import HealthCheck, assume, given, settings
from hypothesis import strategies as st

from scabopdf_pipeline.xml_akn import detect_health
from scabopdf_pipeline.xml_akn.constants import (
    AKN_NS,
    ATTACHMENT_DOC_FRAGMENTED_MIN,
    ATTACHMENT_PARAGRAPH_FRAGMENTED_MIN,
    BODY_ARTICLE_OK_MIN,
    BODY_ARTICLE_STUB_MAX,
)
from scabopdf_pipeline.xml_akn.types import XmlHealthVerdict


def _build_xml(body_n: int, att_docs: int, paras_per_doc: int) -> str:
    body_articles = "".join(
        f'<article eId="art_{i}"><num>Art. {i}.</num>'
        "<paragraph><content><p>x</p></content></paragraph>"
        "</article>"
        for i in range(1, body_n + 1)
    )
    att = "".join(
        f'<attachment><doc name="X-art. {i}"><meta/><mainBody>'
        + "".join(
            f'<paragraph eId="att_{i}_{j}"><content><p>y</p></content></paragraph>'
            for j in range(paras_per_doc)
        )
        + "</mainBody></doc></attachment>"
        for i in range(1, att_docs + 1)
    )
    return (
        '<?xml version="1.0" encoding="UTF-8"?>\n'
        f'<akomaNtoso xmlns="{AKN_NS}">'
        f'<act name="monovigente"><meta/><body>{body_articles}</body>{att}'
        "</act></akomaNtoso>"
    )


def _write(tmp_path: Path, content: str) -> Path:
    p = tmp_path / "case.xml"
    p.write_text(content, encoding="utf-8")
    return p


@given(
    body_n=st.integers(min_value=BODY_ARTICLE_OK_MIN, max_value=BODY_ARTICLE_OK_MIN + 500),
    att_docs=st.integers(min_value=0, max_value=500),
    paras_per_doc=st.integers(min_value=0, max_value=5),
)
@settings(
    max_examples=200,
    deadline=None,
    suppress_health_check=[HealthCheck.function_scoped_fixture],
)
def test_substantial_body_always_ok(
    tmp_path: Path, body_n: int, att_docs: int, paras_per_doc: int
) -> None:
    """Bigger body never causes FRAGMENTED, no matter what the
    attachments look like."""
    xml = _build_xml(body_n, att_docs, paras_per_doc)
    report = detect_health(_write(tmp_path, xml))
    assert report.verdict is XmlHealthVerdict.OK


@given(
    body_n=st.integers(min_value=0, max_value=BODY_ARTICLE_STUB_MAX),
    att_docs=st.integers(
        min_value=ATTACHMENT_DOC_FRAGMENTED_MIN,
        max_value=ATTACHMENT_DOC_FRAGMENTED_MIN + 200,
    ),
    paras_per_doc=st.integers(min_value=1, max_value=10),
)
@settings(
    max_examples=200,
    deadline=None,
    suppress_health_check=[HealthCheck.function_scoped_fixture],
)
def test_stub_body_and_fragmented_attachments_always_fragmented(
    tmp_path: Path, body_n: int, att_docs: int, paras_per_doc: int
) -> None:
    """Stub body plus fragmented attachments always produces FRAGMENTED,
    provided the paragraph total clears its own threshold."""
    total_paragraphs = att_docs * paras_per_doc
    assume(total_paragraphs >= ATTACHMENT_PARAGRAPH_FRAGMENTED_MIN)
    xml = _build_xml(body_n, att_docs, paras_per_doc)
    report = detect_health(_write(tmp_path, xml))
    assert report.verdict is XmlHealthVerdict.FRAGMENTED
    assert report.suggested_alternative == "EPUB"


@given(
    body_n=st.integers(min_value=0, max_value=BODY_ARTICLE_STUB_MAX),
    att_docs=st.integers(min_value=0, max_value=ATTACHMENT_DOC_FRAGMENTED_MIN - 1),
    paras_per_doc=st.integers(min_value=0, max_value=5),
)
@settings(
    max_examples=200,
    deadline=None,
    suppress_health_check=[HealthCheck.function_scoped_fixture],
)
def test_stub_body_with_few_attachments_is_ok(
    tmp_path: Path, body_n: int, att_docs: int, paras_per_doc: int
) -> None:
    """A small body with few attachments (under the fragmented
    threshold) is well-formed minimal AKN, not fragmented."""
    xml = _build_xml(body_n, att_docs, paras_per_doc)
    report = detect_health(_write(tmp_path, xml))
    assert report.verdict is XmlHealthVerdict.OK


@given(
    body_n=st.integers(min_value=0, max_value=BODY_ARTICLE_STUB_MAX),
    att_docs=st.integers(
        min_value=ATTACHMENT_DOC_FRAGMENTED_MIN,
        max_value=ATTACHMENT_DOC_FRAGMENTED_MIN + 100,
    ),
)
@settings(
    max_examples=100,
    deadline=None,
    suppress_health_check=[HealthCheck.function_scoped_fixture],
)
def test_stub_body_with_empty_attachments_is_ok(tmp_path: Path, body_n: int, att_docs: int) -> None:
    """Many empty attachment-docs (zero paragraph) do not trigger
    FRAGMENTED — the paragraph total must clear its threshold too."""
    xml = _build_xml(body_n, att_docs, paras_per_doc=0)
    report = detect_health(_write(tmp_path, xml))
    # paragraph count is 0, below threshold → OK
    assert report.verdict is XmlHealthVerdict.OK


@given(
    other_ns=st.sampled_from(
        [
            "http://example.com/other",
            "http://www.w3.org/1999/xhtml",
            "urn:foo:bar",
        ]
    ),
)
@settings(
    max_examples=20,
    deadline=None,
    suppress_health_check=[HealthCheck.function_scoped_fixture],
)
def test_root_in_other_namespace_is_not_akn(tmp_path: Path, other_ns: str) -> None:
    xml = (
        '<?xml version="1.0" encoding="UTF-8"?>\n'
        f'<akomaNtoso xmlns="{other_ns}"><body/></akomaNtoso>\n'
    )
    report = detect_health(_write(tmp_path, xml))
    assert report.verdict is XmlHealthVerdict.NOT_AKN


@given(
    payload=st.text(
        alphabet=st.characters(
            min_codepoint=32, max_codepoint=126, blacklist_characters=["<", ">"]
        ),
        min_size=0,
        max_size=200,
    ),
)
@settings(
    max_examples=100,
    deadline=None,
    suppress_health_check=[HealthCheck.function_scoped_fixture],
)
def test_random_non_xml_yields_invalid_xml(tmp_path: Path, payload: str) -> None:
    """Random printable strings without angle brackets are never valid
    XML — the detector must classify them as INVALID_XML without
    raising."""
    # Guard against the empty-string case which is actually invalid in a
    # specific way that ElementTree distinguishes; both still classify
    # to INVALID_XML.
    p = tmp_path / "garbage.xml"
    p.write_text(payload, encoding="utf-8")
    report = detect_health(p)
    assert report.verdict is XmlHealthVerdict.INVALID_XML
    assert report.error_detail is not None


@given(
    body_n=st.integers(min_value=0, max_value=20),
    att_docs=st.integers(min_value=0, max_value=20),
    paras_per_doc=st.integers(min_value=0, max_value=5),
)
@settings(
    max_examples=200,
    deadline=None,
    suppress_health_check=[HealthCheck.function_scoped_fixture],
)
def test_structural_summary_counters_are_accurate(
    tmp_path: Path, body_n: int, att_docs: int, paras_per_doc: int
) -> None:
    """The structural summary mirrors the synthetic input exactly."""
    xml = _build_xml(body_n, att_docs, paras_per_doc)
    report = detect_health(_write(tmp_path, xml))
    assert report.structural_summary is not None
    s = report.structural_summary
    assert s.body_article_count == body_n
    assert s.body_paragraph_count == body_n  # 1 paragraph per body article
    assert s.attachment_count == att_docs
    assert s.attachment_doc_count == att_docs
    assert s.attachment_paragraph_count == att_docs * paras_per_doc


@pytest.mark.parametrize(
    "body_n,att_docs,paras_per_doc",
    [
        # boundary at OK threshold from below
        (BODY_ARTICLE_OK_MIN - 1, 0, 0),
        # boundary at OK threshold exact
        (BODY_ARTICLE_OK_MIN, 0, 0),
        # boundary at OK threshold from above
        (BODY_ARTICLE_OK_MIN + 1, 0, 0),
        # boundary at fragmented attachment doc threshold from below
        (0, ATTACHMENT_DOC_FRAGMENTED_MIN - 1, 5),
        # boundary at fragmented attachment doc threshold exact
        (0, ATTACHMENT_DOC_FRAGMENTED_MIN, 3),
        # boundary at stub body max
        (BODY_ARTICLE_STUB_MAX, ATTACHMENT_DOC_FRAGMENTED_MIN, 3),
        (BODY_ARTICLE_STUB_MAX + 1, ATTACHMENT_DOC_FRAGMENTED_MIN, 3),
    ],
)
def test_explicit_threshold_boundaries(
    tmp_path: Path, body_n: int, att_docs: int, paras_per_doc: int
) -> None:
    """A handful of explicit boundary cases to make threshold drift
    obvious in test output."""
    xml = _build_xml(body_n, att_docs, paras_per_doc)
    report = detect_health(_write(tmp_path, xml))
    if body_n >= BODY_ARTICLE_OK_MIN:
        assert report.verdict is XmlHealthVerdict.OK
    elif (
        body_n <= BODY_ARTICLE_STUB_MAX
        and att_docs >= ATTACHMENT_DOC_FRAGMENTED_MIN
        and att_docs * paras_per_doc >= ATTACHMENT_PARAGRAPH_FRAGMENTED_MIN
    ):
        assert report.verdict is XmlHealthVerdict.FRAGMENTED
    else:
        assert report.verdict is XmlHealthVerdict.OK
