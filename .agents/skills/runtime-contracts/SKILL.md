---
name: runtime-contracts
description: Use when changing dart_edge_core contracts, dart_edge_http_server_runtime transport/runtime APIs, helper-vs-runtime boundaries, or the app-facing HTTP server surface.
---

# Runtime And Core Contracts

`dart_edge_core` owns the transport-agnostic contract surface. The HTTP runtime
package consumes those contracts and owns the concrete native server bridge.

## Keep in `dart_edge_core`

- `HttpRouteDefinition`
- `HttpRouteMount`
- `WebSocketRouteDefinition`
- `WebSocketRouteMount`
- `RouteOptions`
- `RequestContext`
- `JsonSchemaRef`
- `JsonSchemaRegistry`
- shared request/response contracts
- transport-agnostic router contracts
- app-facing schema annotations

## Keep in `dart_edge_http_server_runtime`

- `DartEdge`
- route compilation and native manifests
- Rust/native transport bridge
- runtime codec registry integration
- OpenAPI document generation from compiled routes
- transport middleware descriptors
- native request and multipart bridges

## Keep in `dart_edge_http_server`

- Swagger UI serving
- helper-only mounting APIs
- default app-facing exports

## Keep out of runtime

- app-specific auth helpers
- convenience wrappers that do not define core contracts
- lower-level service APIs such as SQL, S3, audio, SIP, Bluetooth, and Wi-Fi

## Design rules

- Prefer one explicit contract object over scattered route metadata.
- JSON Schema references should be explicit and stable.
- Generated code should target normalized public contracts from `dart_edge_core`
  and the public runtime surface, not runtime type reflection or private `src`
  internals.
- Preserve clean umbrella-package ergonomics through
  `dart_edge_http_server`.
- Use modern Dart features where they sharpen the API:
  class modifiers for boundary control, patterns for internal matching, and dot
  shorthands where the surrounding context keeps the call obvious.
