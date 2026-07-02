## 0.3.31

- Fix nullable JSON encoding for `SqlDecimal` and `SqlVector` values in
  generated update models.

## 0.3.30

- Map PostgreSQL `vector(...)` columns to `SqlVector` in generated table
  models.
- Map PostgreSQL `numeric`, `decimal`, and `money` columns, and SQLite
  `NUMERIC`/`DECIMAL` columns, to `SqlDecimal` in generated table models.
- Require `dart_edge_core` 0.3.26 and `dart_edge_sql` 0.3.26.

## 0.3.28

- Support formatter options for emitted Dart schema libraries and schema
  builder outputs.

## 0.3.16

- Reuse `dart_edge_sql` PostgreSQL type-name normalization when mapping
  introspected database types to Dart model field types.
- Require `dart_edge_sql` 0.3.12.

## 0.3.15

- Emit database type metadata on generated SQL columns for PostgreSQL casts.
- Require `dart_edge_sql` 0.3.11.

## 0.3.9

- Update `dart_edge_sql` constraint for rebuilt native artifacts.

## 0.3.8

- Update `dart_edge_sql` constraint for Linux arm64 native artifacts.

## 0.3.7

- Update `dart_edge_sql` constraint for prebuilt native asset support.

## 0.3.0

- Declare internal Dart Edge dependencies with the internal hosted registry.

## 0.2.0

- Update package constraints for the native HTTP routing and shared core API changes.

## 0.1.0

- Initial internal release.
