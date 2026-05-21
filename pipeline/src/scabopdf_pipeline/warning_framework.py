"""Warning framework — canonical placeholder vocabulary and template→regex parser.

This module is the single source of truth for the closed warning vocabulary
shared by tier 1 generic emitters (reconstruction, apparatus) and tier 2
corpus plugins. It defines the canonical placeholder vocabulary, exposes a
deterministic ``template_to_regex`` converter, and ships an optional
:class:`WarningEmitter` helper for plugins that want explicit validation at
emission time.

The convention. Every warning string emitted on ``Document.warnings``
matches a template declared either in :data:`TIER1_RECONSTRUCTION_TEMPLATES`,
:data:`TIER1_APPARATUS_TEMPLATES`, or in a per-plugin ``WARNING_TEMPLATES``
tuple advertised by the plugin's ``get_warning_templates`` classmethod.
Templates use ``<placeholder>`` syntax (lowercase snake_case inside angle
brackets); each placeholder maps to a regex class via :data:`PLACEHOLDER_REGEX`.
A template is converted to a compiled anchored regex through
:func:`template_to_regex`, and the test infrastructure derives the full
closed-vocabulary whitelist automatically from the union of all templates.

See ``docs/PLUGIN_DEVELOPMENT.md`` § 8 for the plugin-author perspective
and ``CLAUDE.md`` for the architectural rationale.
"""

from __future__ import annotations

import re
from collections.abc import Iterable, Mapping
from dataclasses import dataclass
from types import MappingProxyType

PLACEHOLDER_REGEX: Mapping[str, str] = MappingProxyType(
    {
        "id": r"\S+",
        "p": r"\d+",
        "idx": r"-?\d+",
        "n": r"\d+",
        "marker": r"\S+",
        "name": r"\S+",
        "value": r"\S+",
        "roman": r"\S+",
        "v": r"\S+",
        "type": r"\S+",
        "m": r"\d+",
        "level": r"[1-4]",
        "lang": r"\S+",
    }
)
"""Canonical placeholder vocabulary used by warning templates.

Each entry maps a placeholder name (the ``<name>`` token inside a template)
to the regex class it matches at validation time. Adding a new placeholder
to a plugin's ``WARNING_TEMPLATES`` requires adding the corresponding entry
here first; the resolution of unknown placeholders is a fail-loud error
(see :func:`template_to_regex`). The mapping is exposed as a
``MappingProxyType`` to prevent accidental mutation at import time.
"""

_PLACEHOLDER_PATTERN = re.compile(r"<([a-z][a-z0-9_]*)>")


def template_to_regex(template: str) -> re.Pattern[str]:
    """Convert a warning template string into a compiled anchored regex.

    The template uses ``<placeholder>`` markers (e.g. ``"plugin:bic:
    note_section_split_minted_node_<id>_page_<p>_marker_<n>"``). Each
    placeholder is replaced with the corresponding regex class from
    :data:`PLACEHOLDER_REGEX`; the surrounding literal text is escaped
    via :func:`re.escape` before substitution. The result is anchored
    with ``^...$``.

    Raises
    ------
    KeyError
        If the template contains a placeholder absent from
        :data:`PLACEHOLDER_REGEX`. The error message names the unknown
        placeholder; callers should treat this as a definition-time bug,
        not a recoverable condition.
    """
    fragments: list[str] = []
    cursor = 0
    for match in _PLACEHOLDER_PATTERN.finditer(template):
        literal = template[cursor : match.start()]
        if literal:
            fragments.append(re.escape(literal))
        placeholder = match.group(1)
        if placeholder not in PLACEHOLDER_REGEX:
            raise KeyError(
                f"unknown warning placeholder {placeholder!r} in template "
                f"{template!r}; declare it in PLACEHOLDER_REGEX first"
            )
        fragments.append(PLACEHOLDER_REGEX[placeholder])
        cursor = match.end()
    tail = template[cursor:]
    if tail:
        fragments.append(re.escape(tail))
    return re.compile(r"^" + "".join(fragments) + r"$")


def templates_to_regexes(templates: Iterable[str]) -> tuple[re.Pattern[str], ...]:
    """Convert an iterable of templates into a tuple of compiled regexes.

    Convenience wrapper over :func:`template_to_regex`. Preserves input
    order, deduplicates identical patterns (the same template string may
    legitimately appear in both tier 1 and a plugin if the plugin
    re-emits a tier 1 warning verbatim — extremely rare but possible).
    """
    seen: dict[str, re.Pattern[str]] = {}
    for tpl in templates:
        if tpl not in seen:
            seen[tpl] = template_to_regex(tpl)
    return tuple(seen.values())


def _extract_placeholders(template: str) -> tuple[str, ...]:
    """Return the ordered tuple of placeholder names referenced by ``template``."""
    return tuple(match.group(1) for match in _PLACEHOLDER_PATTERN.finditer(template))


@dataclass(frozen=True)
class WarningEmitter:
    """Validated builder of warning strings for a single plugin's vocabulary.

    Instances are immutable and bound to a closed vocabulary at
    construction time. The :meth:`format` method generates a warning
    string from a template selected by its slug (the suffix after the
    plugin prefix), substituting placeholder values from keyword
    arguments. The :meth:`validate` method checks whether an arbitrary
    string matches any template in the vocabulary.

    Construction validates that every template starts with ``prefix:``
    so a misspelled prefix surfaces at import time, not at emission
    time. Construction also validates that every placeholder used in
    every template is declared in :data:`PLACEHOLDER_REGEX`.

    The helper is opt-in. Plugins may continue to use direct f-string
    emission as long as the final string matches a template in their
    declared vocabulary (the integration test asserts this).
    """

    prefix: str
    templates: tuple[str, ...]

    def __post_init__(self) -> None:
        if not self.prefix:
            raise ValueError("WarningEmitter requires a non-empty prefix")
        for tpl in self.templates:
            if not tpl.startswith(self.prefix + ":") and tpl != self.prefix:
                raise ValueError(
                    f"warning template {tpl!r} does not start with prefix {self.prefix + ':'!r}"
                )
            template_to_regex(tpl)

    def format(self, slug: str, **values: object) -> str:
        """Build the warning string for the template identified by ``slug``.

        ``slug`` is the literal suffix after ``prefix:`` and before the
        first placeholder. The method finds the unique template whose
        text starts with ``f"{prefix}:{slug}"`` and at that boundary
        either ends or continues with an underscore; it substitutes the
        placeholder values from ``values`` and returns the formatted
        string. Missing or extra placeholder values are a definition
        bug and raise :class:`KeyError` / :class:`ValueError`
        respectively.
        """
        candidates = [
            tpl
            for tpl in self.templates
            if tpl == f"{self.prefix}:{slug}"
            or tpl.startswith(f"{self.prefix}:{slug}_")
            or tpl.startswith(f"{self.prefix}:{slug}<")
        ]
        if not candidates:
            raise KeyError(f"no warning template for slug {slug!r} under prefix {self.prefix!r}")
        if len(candidates) > 1:
            raise KeyError(
                f"ambiguous warning slug {slug!r} under prefix {self.prefix!r}: "
                f"matches {len(candidates)} templates"
            )
        template = candidates[0]
        placeholders = _extract_placeholders(template)
        missing = [p for p in placeholders if p not in values]
        if missing:
            raise KeyError(f"missing placeholder values {missing!r} for template {template!r}")
        extra = [k for k in values if k not in placeholders]
        if extra:
            raise ValueError(f"unexpected placeholder values {extra!r} for template {template!r}")
        result = template
        for name in placeholders:
            result = result.replace(f"<{name}>", str(values[name]), 1)
        return result

    def validate(self, warning_string: str) -> bool:
        """Return ``True`` iff ``warning_string`` matches one of the templates."""
        return any(template_to_regex(tpl).match(warning_string) for tpl in self.templates)
