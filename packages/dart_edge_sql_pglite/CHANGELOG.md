## 0.1.19

- Preload `pg_textsearch` whenever `PgliteExtension.pgTextSearch` is selected,
  preserving implicit BM25 queries after reopening persistent databases.
- Bump the native artifact version to 0.1.10 for the preload configuration.

## 0.1.18

- Release PGlite endpoints through native finalizers when a Flutter hot restart
  shuts down their Dart isolate group.
- Bump the native artifact version to 0.1.9 for the finalizer ABI.

## 0.1.17

- Add process-wide PGlite endpoint cleanup for Flutter hot-restart recovery.
- Bump the native artifact version to 0.1.7 for the cleanup ABI and pin the
  tested PGlite dependency graph for reproducible native builds.
- Require `dart_edge_sql` 0.3.36 for native pool cleanup.

## 0.1.14

- Add `PgliteExtension.pgTextSearch` for bundled BM25 full-text search.
- Use the PostgreSQL full-text search helpers exported by `dart_edge_sql`.
- Require `dart_edge_sql` 0.3.31.

## 0.1.13

- Require `dart_edge_sql` 0.3.30.

## 0.1.12

- Add bundled PGlite extension support, including pgvector via
  `PgliteExtension.vector`.
- Bump the native artifact version to 0.1.5 for the extension-aware ABI.

## 0.1.10

- Bump the native artifact version to 0.1.4 for Rust 1.95 and dependency
  updates.

## 0.1.7

- Bump the native artifact version to 0.1.2 for rebuilt prebuilts.
- Require `dart_edge_native_assets` 0.1.2 and `dart_edge_sql` 0.3.8.

## 0.1.5

- Publish Linux arm64 native artifacts.
- Update `dart_edge_sql` constraint.

## 0.1.4

- Use prebuilt Linux and macOS native assets when available, with Rust source
  build fallback.
- Update `dart_edge_sql` constraint.

# 0.1.0

- Add PGlite endpoint package for `PostgresPool.pglite`.
