//! `VerificationOps` trait implementation for `DieselSqliteAdapter`.
//!
//! Methods:
//! - `create_verification` — Insert verification token
//! - `get_verification` — Lookup by identifier and value
//! - `get_verification_by_value` — Lookup by token value
//! - `get_verification_by_identifier` — Lookup by identifier string (default impl returns `Ok(None)`)
//! - `consume_verification` — Atomic: select + delete in one `interact` call (prevents replay)
//! - `delete_verification` — Remove by ID
//! - `delete_expired_verifications` — Cleanup expired tokens

use async_trait::async_trait;
use better_auth_core::adapters::VerificationOps;
use better_auth_core::error::AuthResult;
use better_auth_core::types::{CreateVerification, Verification};
use diesel::prelude::*;

use crate::adapter::DieselSqliteAdapter;
use crate::conversions::now_iso;
use crate::error::diesel_to_auth_error;
use crate::models::{NewVerificationRow, VerificationRow};
use crate::schema::verifications;

#[async_trait]
impl VerificationOps for DieselSqliteAdapter {
    type Verification = Verification;

    async fn create_verification(
        &self,
        verification: CreateVerification,
    ) -> AuthResult<Self::Verification> {
        let new_row = NewVerificationRow::from(verification);
        let row_id = new_row.id.clone();

        self.interact(move |conn| {
            diesel::insert_into(verifications::table)
                .values(&new_row)
                .execute(conn)
                .map_err(diesel_to_auth_error)?;

            verifications::table
                .filter(verifications::id.eq(&row_id))
                .first::<VerificationRow>(conn)
                .map(Verification::from)
                .map_err(diesel_to_auth_error)
        })
        .await
    }

    async fn get_verification(
        &self,
        identifier: &str,
        value: &str,
    ) -> AuthResult<Option<Self::Verification>> {
        let identifier = identifier.to_string();
        let value = value.to_string();
        self.interact(move |conn| {
            verifications::table
                .filter(verifications::identifier.eq(&identifier))
                .filter(verifications::value.eq(&value))
                .first::<VerificationRow>(conn)
                .optional()
                .map(|opt| opt.map(Verification::from))
                .map_err(diesel_to_auth_error)
        })
        .await
    }

    async fn get_verification_by_value(
        &self,
        value: &str,
    ) -> AuthResult<Option<Self::Verification>> {
        let value = value.to_string();
        self.interact(move |conn| {
            verifications::table
                .filter(verifications::value.eq(&value))
                .first::<VerificationRow>(conn)
                .optional()
                .map(|opt| opt.map(Verification::from))
                .map_err(diesel_to_auth_error)
        })
        .await
    }

    async fn get_verification_by_identifier(
        &self,
        identifier: &str,
    ) -> AuthResult<Option<Self::Verification>> {
        let identifier = identifier.to_string();
        self.interact(move |conn| {
            verifications::table
                .filter(verifications::identifier.eq(&identifier))
                .first::<VerificationRow>(conn)
                .optional()
                .map(|opt| opt.map(Verification::from))
                .map_err(diesel_to_auth_error)
        })
        .await
    }

    async fn consume_verification(
        &self,
        identifier: &str,
        value: &str,
    ) -> AuthResult<Option<Self::Verification>> {
        let identifier = identifier.to_string();
        let value = value.to_string();
        self.interact(move |conn| {
            // Atomic select + delete: find the row first, then delete it
            let row = verifications::table
                .filter(verifications::identifier.eq(&identifier))
                .filter(verifications::value.eq(&value))
                .first::<VerificationRow>(conn)
                .optional()
                .map_err(diesel_to_auth_error)?;

            match row {
                Some(row) => {
                    diesel::delete(verifications::table.filter(verifications::id.eq(&row.id)))
                        .execute(conn)
                        .map_err(diesel_to_auth_error)?;

                    Ok(Some(Verification::from(row)))
                }
                None => Ok(None),
            }
        })
        .await
    }

    async fn delete_verification(&self, id: &str) -> AuthResult<()> {
        let id = id.to_string();
        self.interact(move |conn| {
            diesel::delete(verifications::table.filter(verifications::id.eq(&id)))
                .execute(conn)
                .map_err(diesel_to_auth_error)?;
            Ok(())
        })
        .await
    }

    async fn delete_expired_verifications(&self) -> AuthResult<usize> {
        let now = now_iso();
        self.interact(move |conn| {
            let deleted =
                diesel::delete(verifications::table.filter(verifications::expires_at.lt(&now)))
                    .execute(conn)
                    .map_err(diesel_to_auth_error)?;
            Ok(deleted)
        })
        .await
    }
}
