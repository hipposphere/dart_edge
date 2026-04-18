//! Trait implementations for each `*Ops` sub-trait of `DatabaseAdapter`.
//!
//! Each module implements one trait for `DieselSqliteAdapter`:
//!
//! | Module | Trait | Methods |
//! |--------|-------|---------|
//! | `user` | `UserOps` | 7 methods |
//! | `session` | `SessionOps` | 8 methods |
//! | `account` | `AccountOps` | 5 methods |
//! | `verification` | `VerificationOps` | 7 methods |
//! | `organization` | `OrganizationOps` | 6 methods |
//! | `member` | `MemberOps` | 8 methods |
//! | `invitation` | `InvitationOps` | 6 methods |
//! | `two_factor` | `TwoFactorOps` | 4 methods |
//! | `api_key` | `ApiKeyOps` | 7 methods |
//! | `passkey` | `PasskeyOps` | 7 methods |

pub mod account;
pub mod api_key;
pub mod invitation;
pub mod member;
pub mod organization;
pub mod passkey;
pub mod session;
pub mod two_factor;
pub mod user;
pub mod verification;
