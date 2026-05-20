"""Generic helpers for minting synthetic ``Node`` instances in tier 2.

The tier 1 reconstructor assigns ``node_NNNN`` ids monotonically, zero
padded to four digits, conforming to the JSON schema's
``NodeDict.id`` pattern ``^node_\\d+$``. Tier 2 plugins that materialise
synthetic Nodes (Mosconi inline cross-references, Mandrioli body+note
splitter, BIC multi-block splitter and continuation rescuer, NS / DT
multi-sibling notes consolidator, codici intra-block article splitter,
EM / ES dual-subtype cross-references, Torrente three-subtype rinvii)
must respect the same convention so the downstream apparatus resolver
and emission converter see a uniform id space.

Before this module landed every plugin shipped its own copy of the
:class:`NodeIdMinter` class and the :func:`max_existing_node_counter`
walker. Promotion to Layer 1 (Stage 1 of the Promotion Analysis
Fase 1, P-001 + P-002 + P-003) eliminates roughly nine identical copies
in favour of a single canonical implementation imported by every plugin
that mints synthetic Nodes.

Three entry points are exposed:

- :class:`NodeIdMinter` is the stateful id factory. Seed it with
  ``start=max_existing_node_counter(roots) + 1`` and call
  :meth:`NodeIdMinter.mint` for each synthetic Node.
- :func:`max_existing_node_counter` walks a ``Document.root`` forest
  pre-order and returns the highest counter already assigned. Returns
  ``-1`` if no node id matches the pattern, so the caller can seed the
  minter at ``0``.
- :func:`iter_nodes_pre_order` is the canonical DFS walk over a forest
  of Node roots; previously duplicated in every plugin under the name
  ``_iter_nodes``.

Sibling-insertion convention (P-008 of the Promotion Analysis Fase 1).
Every plugin that mints synthetic Nodes inserts them as siblings
immediately after their host Node, following an intentional convention
the project has converged on across nine plugins:

1. The plugin walks the children of a parent left-to-right with a
   ``result: list[Node] = []`` accumulator.
2. For each child the walker first appends the (possibly transformed)
   child to ``result``, then evaluates the per-plugin trigger (a regex
   on the child's text, a typographic span match, a position predicate,
   etc.) and mints zero or more synthetic Nodes via :class:`NodeIdMinter`.
3. Each synthetic Node is ``result.append``-ed immediately after the
   host child, in match order.
4. The walker recurses into ``child.children`` and replaces the host's
   ``children`` field with the recursive result (using
   :func:`dataclasses.replace` or an equivalent immutable rebuild).
5. The top-level ``Document`` is rebuilt with the new ``root`` tuple via
   :class:`Document` constructor.

The convention preserves the JSON schema's ``Node`` immutability,
respects the ``node_NNNN`` id pattern, and produces a tree whose
synthetic Nodes are positionally adjacent to their source — a property
that the apparatus resolver and the emission converter rely on. No
helper function abstracts the walker because the trigger and the
transformation are plugin-specific; only the minting primitive and the
DFS walker are shared (see above). New plugins materialising synthetic
Nodes should replicate this convention literally.

The pattern (mmm) of CLAUDE.md ("length-category emission framework
for NOTE Nodes") relies on synthetic Nodes minted by these helpers; the
five-call-site propagation convention documented there is now anchored
in this module.
"""

from __future__ import annotations

import re
from collections.abc import Iterable

from scabopdf_pipeline.reconstruction.types import Node

_NODE_ID_PATTERN = re.compile(r"^node_(\d+)$")
"""Pattern that decodes a tier 1 node id into its numeric counter.

The pattern matches the canonical ``node_NNNN`` form emitted by the
tier 1 reconstructor and validated by the Pydantic ``NodeDict.id``
field; any non-matching id contributes nothing to
:func:`max_existing_node_counter`.
"""


class NodeIdMinter:
    """Stateful node-id factory following the tier 1 ``node_NNNN`` convention.

    The minter starts at the ``start`` counter supplied at construction
    time and emits monotonically increasing ids zero-padded to four
    digits. Typical seeding pattern::

        minter = NodeIdMinter(start=max_existing_node_counter(document.root) + 1)
        synthetic = Node(id=minter.mint(), ...)
    """

    __slots__ = ("_counter",)

    def __init__(self, *, start: int) -> None:
        self._counter = start

    def mint(self) -> str:
        node_id = f"node_{self._counter:04d}"
        self._counter += 1
        return node_id


def max_existing_node_counter(roots: Iterable[Node]) -> int:
    """Return the highest numeric counter already used by a tier 1 node id.

    Walks the forest pre-order, decodes every id with
    :data:`_NODE_ID_PATTERN`, and returns the maximum counter
    encountered. A forest with no matching ids returns ``-1`` so the
    caller can seed :class:`NodeIdMinter` at ``0``.
    """
    best = -1
    for node in iter_nodes_pre_order(roots):
        match = _NODE_ID_PATTERN.match(node.id)
        if match is not None:
            value = int(match.group(1))
            if value > best:
                best = value
    return best


def iter_nodes_pre_order(roots: Iterable[Node]) -> list[Node]:
    """Pre-order DFS walk over a forest of ``Node`` roots.

    Returns a materialised list so callers can iterate the result
    multiple times — matching the convention established by the
    duplicated per-plugin ``_iter_nodes`` helpers this function
    replaces. The memory cost is linear in the document size and
    negligible relative to the rest of the pipeline.
    """
    out: list[Node] = []

    def _visit(node: Node) -> None:
        out.append(node)
        for child in node.children:
            _visit(child)

    for root in roots:
        _visit(root)
    return out


__all__ = [
    "NodeIdMinter",
    "iter_nodes_pre_order",
    "max_existing_node_counter",
]
