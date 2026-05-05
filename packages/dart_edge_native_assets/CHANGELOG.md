## 0.1.2

- Stop declaring downloaded prebuilt cache files as hook dependencies so clean
  Docker builds do not report `File modified during build`.

## 0.1.0

- Add shared Rust native asset hook helper with Linux/macOS prebuilt download
  support and Rust source-build fallback.
- Key native artifact lookup by Rust crate version instead of Dart package
  version.
