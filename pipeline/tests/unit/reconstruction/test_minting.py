"""Unit tests for the generic node-id minting helpers.

Covers :class:`NodeIdMinter`, :func:`max_existing_node_counter` and
:func:`iter_nodes_pre_order` promoted from the duplicated per-plugin
implementations.
"""

from __future__ import annotations

from scabopdf_pipeline.reconstruction.minting import (
    NodeIdMinter,
    iter_nodes_pre_order,
    max_existing_node_counter,
)
from scabopdf_pipeline.reconstruction.types import Node
from scabopdf_pipeline.schema.categories import SemanticCategory


def _node(node_id: str, children: tuple[Node, ...] = ()) -> Node:
    return Node(
        id=node_id,
        category=SemanticCategory.BODY,
        text=None,
        page_index=0,
        block_indices=(0,),
        children=children,
        apparatus_refs=(),
    )


def test_node_id_minter_emits_sequential_zero_padded_ids() -> None:
    minter = NodeIdMinter(start=42)

    ids = [minter.mint() for _ in range(3)]

    assert ids == ["node_0042", "node_0043", "node_0044"]


def test_node_id_minter_at_zero() -> None:
    minter = NodeIdMinter(start=0)
    assert minter.mint() == "node_0000"


def test_node_id_minter_above_four_digits() -> None:
    minter = NodeIdMinter(start=12345)
    assert minter.mint() == "node_12345"


def test_max_existing_node_counter_empty_forest() -> None:
    assert max_existing_node_counter(()) == -1


def test_max_existing_node_counter_walks_pre_order_picks_max() -> None:
    leaf_a = _node("node_0003")
    leaf_b = _node("node_0017")
    inner = _node("node_0005", children=(leaf_a, leaf_b))
    root = _node("node_0001", children=(inner,))
    sibling = _node("node_0010")

    assert max_existing_node_counter((root, sibling)) == 17


def test_max_existing_node_counter_ignores_non_matching_ids() -> None:
    valid = _node("node_0007")
    invalid_a = _node("node_xyz")  # non-numeric counter
    invalid_b = _node("custom_0099")  # non-canonical prefix
    forest = (_node("root", children=(valid, invalid_a, invalid_b)),)

    assert max_existing_node_counter(forest) == 7


def test_iter_nodes_pre_order_is_dfs() -> None:
    leaf_a = _node("node_0003")
    leaf_b = _node("node_0004")
    inner = _node("node_0002", children=(leaf_a, leaf_b))
    root = _node("node_0001", children=(inner,))

    sequence = [node.id for node in iter_nodes_pre_order((root,))]

    assert sequence == ["node_0001", "node_0002", "node_0003", "node_0004"]


def test_iter_nodes_pre_order_visits_every_root() -> None:
    root_a = _node("node_0001")
    root_b = _node("node_0002", children=(_node("node_0003"),))

    sequence = [node.id for node in iter_nodes_pre_order((root_a, root_b))]

    assert sequence == ["node_0001", "node_0002", "node_0003"]


def test_minter_seeded_from_existing_counter_avoids_collision() -> None:
    forest = (_node("node_0042"),)

    minter = NodeIdMinter(start=max_existing_node_counter(forest) + 1)

    assert minter.mint() == "node_0043"
