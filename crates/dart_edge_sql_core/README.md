# dart_edge_sql_core

Shared SQL JSON wire payload types for Dart Edge native crates.

The `dart_edge_sql` native asset and other native crates, such as
`dart_edge_auth`, exchange SQL statements and result rows through JSON payloads.
This crate owns that schema so those crates do not drift independently.

The types are not C ABI structs. They are serializable payload contracts used
inside Dart Edge native libraries and callback bridges.

Included contracts:

- SQL statement, value, row, column, and result payloads
- stable SQL dialect codes and placeholder helpers
- structured SQL error payloads
- an explicit wire version constant
