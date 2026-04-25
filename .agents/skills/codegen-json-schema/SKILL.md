---
name: codegen-json-schema
description: Use when designing or editing typed route annotations, JSON Schema generation, schema registries, $ref handling, manifest generation, or build-time APIs in dart_edge_http_server_codegen.
---

# Codegen And JSON Schema

`dart_edge_http_server_codegen` is the HTTP server build-time package for the repo.

## Responsibilities

- typed route annotations
- JSON Schema generation
- schema registry generation
- `$ref` support for shared and recursive models
- manifest generation
- OpenAPI generation
- optional typed clients

## Guardrails

- Keep `$ref` support first-class.
- Prefer generated registries over runtime discovery.
- Generated output should compile down to `RouteContract` plus
  `JsonSchemaRef`-backed schema references.
- Do not split route codegen and schema codegen into separate packages unless
  the repo proves that boundary later.
- Generated examples and templates should assume the Dart 3.11 language
  baseline and may use dot shorthands, patterns, and records where they improve
  readability.

## Typical checks

- annotation shape and generated route contract agree
- schema registry ids are stable
- generated OpenAPI uses the same schema graph as runtime validation
