"""Module-level constants for § 5 reconstruction.

See ARCHITECTURE.md § 5 for the canonical specification.
"""

from __future__ import annotations

CROSS_PAGE_TOP_FRACTION = 0.12
"""Maximum ``bbox.y0`` as a fraction of page height for a BODY/ARTICLE_BODY
block to be a candidate continuation of the previous page's paragraph
(ARCHITECTURE.md § 5.5).
"""
