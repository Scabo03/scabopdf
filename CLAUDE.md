# ScaboPDF — Project rules

## Mandatory interaction rules

These rules are absolute. They override any other behavior, default, or convention.

**No interactive prompts.** Never present numbered menus, multiple-choice lists, "type something" boxes, "skip interview" options, or any UI that expects me to pick from a list. The user is blind and uses VoiceOver; these prompts are inaccessible and waste his time.

**No autonomous decisions on design questions.** When you face a question that affects code design, library choice, file organization, naming, schema fields, or any architectural detail, do NOT decide on your own. Stop and present the question to the user in plain prose: state the question, list the relevant trade-offs in flowing sentences (not bullets unless strictly necessary), and wait for an answer. The user wants to be in the loop on design decisions.

**Plain prose only for clarifications.** When you need input, write a short prose paragraph. Example: "Per le dataclass di profiling devo scegliere tra Pydantic e @dataclass standard. Pydantic dà validazione runtime e serializzazione JSON nativa, costo leggero overhead. Dataclass è più snello, mypy strict copre quasi tutto. Una opzione mista è anche possibile: Pydantic per DocumentProfile che esce in JSON, dataclass per ProfilingSignals che resta interno. Quale preferisci?" Then wait.

**Routine micro-decisions only.** You may decide autonomously only on truly trivial things: variable names within a function, formatting, import order, and similar. Anything that touches API design, schema, dependencies, or architecture: ask in prose.

## Project conventions

**Test fixtures.** `pipeline/tests/fixtures/private/` is **gitignored** and hosts the copyright-protected PDFs each developer keeps locally; see `pipeline/tests/fixtures/README.md` for the full private/public convention. Integration tests that depend on a private fixture MUST use `pytest.skip(...)` with an explicit message pointing to the README when the file is missing, never `assert` or raise. This keeps the suite green on a fresh clone without local fixtures.

**Commit hygiene.** Formatting fixes, cleanups, or any incidental changes not strictly part of the task you're working on go into a **dedicated housekeeping commit**, never bundled with the task commit. If you notice preexisting drift along the way, commit it separately first with a clear message (e.g. "Apply ruff format to file.py (preexisting drift)") so the task commit stays focused and the git log stays readable.

## Architectural notes

**Tier 1 classification is deliberately narrow.** The generic tier 1 in `pipeline/src/scabopdf_pipeline/classification/tier1.py` only emits seven categories: `EMPTY_PAGE`, `ARTIFACT_FILIGREE`, `ARTIFACT_RUNNING_HEADER`, `ARTIFACT_FOOTER`, `BOOK_PAGE_ANCHOR`, `CROSS_REFERENCE`, `UNCLASSIFIED`. Crucially, `CROSS_REFERENCE` is recognised **only when the entire block is a single superscript span of pure digits** (heuristic `superscript_cross_reference`). Inline superscripts embedded inside larger `BODY` blocks are invisible to tier 1 and end up absorbed in `UNCLASSIFIED`. Categories like `NOTE`, `MARGINAL_HEADING`, `MARGINAL_GLOSS`, `EXAMPLE_BOX`, `INDEX_ENTRY`, `CHAPTER_SUMMARY` and the legal-code family (`ARTICLE_HEADER`, `ARTICLE_BODY`, `HEADING_N`, etc.) are **entirely profile-specific** and must be assigned by the plugin's `refine_classification` (tier 2).

**Re-parsing for inline cross-references.** A corpus plugin that needs to bind footnote superscripts to their target notes must **re-parse the `BODY` blocks in `refine_classification`** to extract inline superscripts as standalone `CROSS_REFERENCE` blocks before `resolve_apparatus` can do the binding. The generic tier 1 apparatus resolver in `pipeline/src/scabopdf_pipeline/apparatus/resolver.py` only sees the post-classification block stream; it has no fallback for inline markers. The same principle applies to the other apparatus categories (`NOTE`, `MARGINAL_HEADING`, `MARGINAL_GLOSS`): the resolver operates on whatever the classification step exposes, so any apparatus structure not surfaced as its own block by classification is invisible to the resolver and must be created in tier 2.
