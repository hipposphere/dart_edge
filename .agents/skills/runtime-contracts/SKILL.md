---
name: runtime-contracts
description: Use when changing RouteDefinition, RouteContract, RequestContext, WebSocket contracts, helper-vs-runtime boundaries, or the public runtime API in dart_edge_runtime.
---

# Runtime Contracts

The runtime package owns both the shared contract surface and the concrete
server runtime.

## Keep together

- `RouteDefinition`
- `JsonRouteDefinition`
- `WebSocketRouteDefinition`
- `RouteContract`
- `RequestContext`
- `JsonSchemaRef`
- runtime-facing manifest and schema model types

## Keep out of runtime

- Swagger UI serving
- helper-only mounting APIs
- app-specific auth helpers
- convenience wrappers that do not define core contracts

## Design rules

- Prefer one explicit contract object over scattered route metadata.
- JSON Schema references should be explicit and stable.
- Generated code should target normalized runtime contracts, not runtime type
  reflection.
- Preserve clean umbrella-package ergonomics through `dart_edge`.
- Use modern Dart features where they sharpen the API:
  class modifiers for boundary control, patterns for internal matching, and dot
  shorthands where the surrounding context keeps the call obvious.
