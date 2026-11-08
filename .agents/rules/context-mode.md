# context-mode

This project uses context-mode for token-efficient local search and context window optimization.

Rules:
- To search project code and documentation without polluting the context window with raw files, run `context-mode search "<query>"`.
- To update the local SQLite FTS5 search index after creating or modifying major files, run `context-mode index .`.
- Combine with graphify: use graphify for structural relationships (AST/call graph) and context-mode for fast full-text keyword search across all indexed sections.
