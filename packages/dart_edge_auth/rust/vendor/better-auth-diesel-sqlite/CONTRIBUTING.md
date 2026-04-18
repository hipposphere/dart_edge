# Contributing to better-auth-diesel-sqlite

Thank you for your interest in contributing! This project follows [Ferrous Forge](https://github.com/kryptobaseddev/ferrous-forge) development standards.

## Getting Started

```bash
git clone https://github.com/kryptobaseddev/better-auth-diesel-sqlite
cd better-auth-diesel-sqlite
cargo build
cargo test
```

### Prerequisites

- Rust 1.88+ (edition 2024)
- SQLite development headers (or use `--features bundled-sqlite`)
- [Ferrous Forge](https://crates.io/crates/ferrous-forge) (`cargo install ferrous-forge`)

## Development Workflow

1. **Fork and branch** from `main`
2. **Write code** following existing patterns in `src/ops/`
3. **Run checks** before committing:
   ```bash
   cargo fmt
   cargo clippy
   cargo test
   ferrous-forge validate
   ```
4. **Commit** with clear, conventional messages
5. **Open a PR** against `main`

## Code Standards

This project enforces strict standards via Ferrous Forge:

- `#![forbid(unsafe_code)]` — no unsafe code allowed
- `clippy::unwrap_used = deny` — use proper error handling
- `clippy::expect_used = deny` — no panicking in library code
- Pre-commit hooks run `cargo fmt` and `cargo clippy` automatically

## Architecture

Each database operation trait follows the same pattern:

```rust
self.interact(move |conn| {
    // Synchronous Diesel queries run inside spawn_blocking
    diesel::insert_into(table::table)
        .values(&new_row)
        .execute(conn)
        .map_err(diesel_to_auth_error)?;
    // ...
})
.await
```

See [ARCHITECTURE.md](ARCHITECTURE.md) for full details.

## Adding a New Operation

1. Add the Diesel model to `src/models.rs`
2. Add `From` conversions in `src/conversions.rs`
3. Implement the trait in `src/ops/`
4. Add integration tests in `tests/integration/`

## Reporting Issues

- Check existing issues first
- Include: OS, Rust version, SQLite version, error messages
- Minimal reproduction is appreciated

## License

By contributing, you agree that your contributions will be licensed under the MIT License.
