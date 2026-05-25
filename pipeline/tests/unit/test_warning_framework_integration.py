"""Cross-plugin invariants on the warning framework integration.

These tests verify the **collective** properties of the per-plugin
``get_warning_templates`` overrides plus the tier 1 generic templates:
that every template is well-formed (no unknown placeholder), that every
plugin template carries its declared prefix, and that the tier 1
templates use the canonical lowercase placeholder syntax.
"""

from __future__ import annotations

import pytest

from scabopdf_pipeline.apparatus.resolver import (
    TIER1_WARNING_TEMPLATES as TIER1_APPARATUS_TEMPLATES,
)
from scabopdf_pipeline.profiles.compendio_utet import CompendioUtetProfile
from scabopdf_pipeline.profiles.dejure_dottrina import DejureDottrinaProfile
from scabopdf_pipeline.profiles.dejure_massime import DejureMassimeProfile
from scabopdf_pipeline.profiles.dejure_nota_sentenza import DejureNotaSentenzaProfile
from scabopdf_pipeline.profiles.enciclopedia_moderna import EnciclopediaModernaProfile
from scabopdf_pipeline.profiles.enciclopedia_storica import EnciclopediaStoricaProfile
from scabopdf_pipeline.profiles.giuffre_codici import GiuffreCodiciProfile
from scabopdf_pipeline.profiles.manuale_bic import ManualeBicProfile
from scabopdf_pipeline.profiles.manuale_giappichelli import ManualeGiappichelliProfile
from scabopdf_pipeline.profiles.manuale_giuffre_diretto import ManualeGiuffreDirectoProfile
from scabopdf_pipeline.profiles.manuale_utet_wolterskluwer import (
    ManualeUtetWolterskluwerProfile,
)
from scabopdf_pipeline.profiles.manuale_zanichelli_giuridica import (
    ManualeZanichelliGiuridicaProfile,
)
from scabopdf_pipeline.profiles.materiali_studio import MaterialiStudioProfile
from scabopdf_pipeline.profiles.unknown_generic import UnknownGenericProfile
from scabopdf_pipeline.profiling.plugin import ProfilePlugin
from scabopdf_pipeline.reconstruction.tier1 import (
    TIER1_WARNING_TEMPLATES as TIER1_RECONSTRUCTION_TEMPLATES,
)
from scabopdf_pipeline.warning_framework import template_to_regex

ALL_PROFILE_PLUGINS: tuple[tuple[str, type[ProfilePlugin], str], ...] = (
    ("compendio_utet", CompendioUtetProfile, "plugin:tesauro"),
    ("dejure_dottrina", DejureDottrinaProfile, "plugin:dejure_dottrina"),
    ("dejure_massime", DejureMassimeProfile, "plugin:dejure_massime"),
    ("dejure_nota_sentenza", DejureNotaSentenzaProfile, "plugin:dejure_nota_sentenza"),
    ("enciclopedia_moderna", EnciclopediaModernaProfile, "plugin:enciclopedia_moderna"),
    ("enciclopedia_storica", EnciclopediaStoricaProfile, "plugin:enciclopedia_storica"),
    ("giuffre_codici", GiuffreCodiciProfile, "plugin:giuffre_codici"),
    ("manuale_bic", ManualeBicProfile, "plugin:bic"),
    ("manuale_giappichelli", ManualeGiappichelliProfile, "plugin:giappichelli"),
    ("manuale_giuffre_diretto", ManualeGiuffreDirectoProfile, "plugin:giuffre_diretto"),
    ("manuale_utet_wolterskluwer", ManualeUtetWolterskluwerProfile, "plugin:utet_wolterskluwer"),
    (
        "manuale_zanichelli_giuridica",
        ManualeZanichelliGiuridicaProfile,
        "plugin:zanichelli",
    ),
    ("materiali_studio", MaterialiStudioProfile, "plugin:materiali_studio"),
)


@pytest.mark.parametrize(("name", "profile_cls", "prefix"), ALL_PROFILE_PLUGINS)
def test_plugin_warning_templates_compile(
    name: str, profile_cls: type[ProfilePlugin], prefix: str
) -> None:
    """Every template in every plugin must convert to a regex without raising."""
    templates = profile_cls.get_warning_templates()
    assert len(templates) > 0, f"plugin {name!r} declares no warning templates"
    for tpl in templates:
        # Raises KeyError if a placeholder is unknown.
        regex = template_to_regex(tpl)
        assert regex.pattern.startswith("^")
        assert regex.pattern.endswith("$")


@pytest.mark.parametrize(("name", "profile_cls", "prefix"), ALL_PROFILE_PLUGINS)
def test_plugin_warning_templates_share_prefix(
    name: str, profile_cls: type[ProfilePlugin], prefix: str
) -> None:
    """Every template in every plugin must start with the declared prefix."""
    templates = profile_cls.get_warning_templates()
    for tpl in templates:
        assert tpl.startswith(prefix + ":"), (
            f"plugin {name!r} template {tpl!r} does not carry prefix {prefix + ':'!r}"
        )


def test_unknown_generic_has_no_warning_templates() -> None:
    """The fallback plugin emits no warnings; the default ABC value applies."""
    assert UnknownGenericProfile.get_warning_templates() == ()


def test_abc_default_returns_empty_tuple() -> None:
    """The ABC default is the empty tuple; non-overriding plugins inherit it."""
    assert ProfilePlugin.get_warning_templates() == ()


def test_tier1_reconstruction_templates_compile() -> None:
    """Tier 1 reconstruction templates use the canonical placeholder syntax."""
    for tpl in TIER1_RECONSTRUCTION_TEMPLATES:
        regex = template_to_regex(tpl)
        assert regex.pattern.startswith("^")


def test_tier1_apparatus_templates_compile() -> None:
    """Tier 1 apparatus templates use the canonical placeholder syntax."""
    for tpl in TIER1_APPARATUS_TEMPLATES:
        regex = template_to_regex(tpl)
        assert regex.pattern.startswith("^")


def test_aggregate_template_count() -> None:
    """The aggregate of plugin + tier 1 templates matches the empirical count.

    Sanity check that protects against accidental template deletion in
    one of the plugin files. The expected total is the count observed at
    Fase 2 landing time (Fase 2 P-007).
    """
    plugin_total = sum(
        len(profile_cls.get_warning_templates()) for _, profile_cls, _ in ALL_PROFILE_PLUGINS
    )
    tier1_total = len(TIER1_RECONSTRUCTION_TEMPLATES) + len(TIER1_APPARATUS_TEMPLATES)
    # Empirical baseline at v2.33 (debt-(v) closure): 112 plugin templates + 6 tier 1.
    # Was 108 at Fase 2; +4 added by the materiali_studio Word-ToC closure
    # (heading_1_toc_header, heading_1_capitolo_full, toc_entry_dotted_leader,
    # toc_entry_unparseable_node — see pattern (eeee) of CLAUDE.md).
    assert plugin_total == 112, f"plugin template count drift: {plugin_total} != 112"
    assert tier1_total == 6, f"tier 1 template count drift: {tier1_total} != 6"
