## 0.3.23

- Add generated-client streamed response contracts for SSE and other long-lived
  HTTP response streams.

## 0.3.22

- Add streamed generated-client request body contracts.
- Add generated-client request timeout contracts that compose with abort
  triggers.
- Stream generated-client multipart form-data uploads without buffering file
  contents into memory.
- Add generated-client multipart upload progress contracts.
- Preserve multipart request content length when every upload file length is
  known.

## 0.3.19

- Add a reusable long-lived isolate request worker for native-backed services.

## 0.3.17

- Add first-class HTTP request observer contracts for route-level
  instrumentation.

## 0.3.16

- Add multipart form-data body contracts and `@FromMultipartSchema`.
- Add schema-backed multipart request body decoder support.
- Add generated-client multipart upload file and byte request body contracts.

## 0.3.13

- Add WebSocket route query schema and query decoder options.

## 0.3.11

- Add WebTransport core route, context, generated-client, datagram, and
  reliable stream payload contracts.

## 0.3.10

- Add binary response contracts with `RawResponse.binary`,
  `ResponseSpec.binary`, generated-client response bytes, and response-builder
  binary helpers.

## 0.3.9

- Add optional database type metadata to SQL column descriptors.

## 0.3.8

- Add route-local decoders for path parameters and query parameters.

## 0.2.0

- Update package constraints for the native HTTP routing and shared core API changes.

## 0.1.0

- Initial internal release.
