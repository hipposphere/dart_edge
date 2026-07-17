## 0.3.42

- Require `json_schema` 0.1.2.

## 0.3.41

- Require `json_schema` 0.1.1 and import JSON contracts directly in generated
  schema and table libraries.

## 0.3.39

- Keep generated table columns as `static const` fields on the table class and
  stop emitting separate `*TableColumns` extensions.
- Expose key metadata as `static const sqlKeyManifest` on the generated database
  class instead of generating a separate key manifest library.

## 0.3.38

- Emit generated table `columns` metadata as `List<SqlColumnBase>` without
  erased `asObjectColumn` casts.
- Require `dart_edge_core` 0.3.31 and `dart_edge_sql` 0.3.30.

## 0.3.37

- Emit key metadata as static `manifest` constants on generated key extension
  types and aggregate those constants in generated key manifest libraries.

## 0.3.36

- Use `SqlKeyManifestEntry` from `dart_edge_core` in generated key manifests.
- Require `dart_edge_core` 0.3.30.

## 0.3.35

- Emit generated SQL key manifests for primary key extension types and
  configured external primary keys.

## 0.3.34

- Update SQL introspection queries for the typed `orderBy` API in
  `dart_edge_sql` 0.3.28.
- Require `dart_edge_sql` 0.3.28.

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
