## 0.3.29

- Add `SqlParam` and `SqlParameter` for explicitly typed PostgreSQL raw query
  parameters.
- Add typed SQL expression helpers for scalar values, casts, text functions,
  arithmetic, boolean expressions, comparisons, aggregates, JSONB operations,
  and date/time expressions.
- Preserve nested expression parameters when composing generated SQL fragments.

## 0.3.28

- Make typed select `orderBy` accept `SqlOrderBy` values from `.asc()` and
  `.desc()`, and add `orderByColumn` for column-based ordering.

## 0.3.27

- Re-export `SqlRow` typed-column read helpers from `dart_edge_core`.
- Require `dart_edge_core` 0.3.29.

## 0.3.26

- Add pgvector parameter encoding and result decoding through `SqlVector`.
- Add lossless decimal parameter encoding and result decoding through
  `SqlDecimal`.
- Bump the native artifact version to 0.1.8 for vector and decimal result
  decoding.
- Require `dart_edge_core` 0.3.26.

## 0.3.25

- Add PostgreSQL row-locking select helpers, including `FOR UPDATE`,
  `FOR NO KEY UPDATE`, `FOR SHARE`, `FOR KEY SHARE`, `NOWAIT`, `SKIP LOCKED`,
  and optional `OF` lock targets.

## 0.3.18

- Bump the native artifact version to 0.1.6 for Rust 1.95 and dependency
  updates.

## 0.3.12

- Centralize PostgreSQL type-name normalization and parameter cast helpers.
- Cast PostgreSQL integer aliases such as `integer`, `smallint`, and `bigint`
  for generated table inserts and updates.
- Export `PostgresTypeMapping` for SQL codegen and package integrations.

## 0.3.11

- Bind PostgreSQL `dateTime` parameters as native timestamps so generated table
  updates can set `timestamptz` columns.
- Cast PostgreSQL generated-table parameters for special database types such as
  `uuid`, `time`, and user-defined enum columns.
- Decode PostgreSQL `date` and `timestamp` result columns as `DateTime` values.
- Bump the native artifact version to 0.1.3 for rebuilt prebuilts.
- Require `dart_edge_core` 0.3.9.

## 0.3.8

- Bump the native artifact version to 0.1.2 for rebuilt prebuilts.
- Require `dart_edge_native_assets` 0.1.2.

## 0.3.6

- Publish Linux arm64 native artifacts.

## 0.3.5

- Use prebuilt Linux and macOS native assets when available, with Rust source
  build fallback.

## 0.3.0

- Add PGlite endpoint support for `PostgresPool.pglite`.
- Allow configuring PostgreSQL pool max sessions.

## 0.2.0

- Update package constraints for the native HTTP routing and shared core API changes.

## 0.1.0

- Initial internal release.
