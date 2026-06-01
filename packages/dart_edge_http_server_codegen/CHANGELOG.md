## 0.3.30

- Generate streamed client methods for `ResponseSpec.sse()` routes.
- Require `dart_edge_core` 0.3.23.

## 0.3.27

- Generate optional multipart upload progress callbacks for multipart client
  routes.
- Generate optional request timeout parameters for HTTP client routes.
- Require `dart_edge_core` 0.3.22.

## 0.3.24

- Generate typed multipart form-data body models from `@FromMultipartSchema`.
- Generate multipart client body DTOs with `MultipartUploadFile` fields and
  `toMultipartFormData()` encoders.
- Map `string(format: binary)` multipart fields to `MultipartFile`.
- Require `dart_edge_core` 0.3.16.

## 0.3.20

- Generate WebSocket client query parameters from `WebSocketOptions.query`.
- Discover WebSocket query schemas from router registries for generated client
  models.
- Require `dart_edge_core` 0.3.13.

## 0.3.18

- Generate WebTransport client connection methods and support sessions with
  datagrams and reliable stream payloads.
- Require `dart_edge_core` 0.3.11.

## 0.3.17

- Generate `Uint8List` client bindings for binary response contracts.
- Require `dart_edge_core` 0.3.10.

## 0.3.16

- Preserve route-local path parameter and query parameter decoders when
  deriving effective route options.
- Require `dart_edge_core` 0.3.8.

## 0.3.8

- Update `dart_edge_http_server_runtime` constraint for rebuilt native artifacts.

## 0.3.7

- Update `dart_edge_http_server_runtime` constraint for Linux arm64 native
  artifacts.

## 0.3.6

- Update `dart_edge_http_server_runtime` constraint for prebuilt native asset
  support.

## 0.3.0

- Declare internal Dart Edge dependencies with the internal hosted registry.

## 0.2.0

- Update package constraints for the native HTTP routing and shared core API changes.

## 0.1.0

- Initial internal release.
