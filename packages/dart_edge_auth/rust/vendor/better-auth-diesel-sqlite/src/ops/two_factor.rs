//! `TwoFactorOps` trait implementation for `DieselSqliteAdapter`.
//!
//! Methods:
//! - `create_two_factor` — Store `TOTP` secret and backup codes
//! - `get_two_factor_by_user_id` — Lookup by `user_id` (unique constraint)
//! - `update_two_factor_backup_codes` — Update backup codes for a user
//! - `delete_two_factor` — Remove 2FA for a user

use async_trait::async_trait;
use better_auth_core::adapters::TwoFactorOps;
use better_auth_core::error::AuthResult;
use better_auth_core::types::{CreateTwoFactor, TwoFactor};
use diesel::prelude::*;

use crate::adapter::DieselSqliteAdapter;
use crate::conversions::now_iso;
use crate::error::diesel_to_auth_error;
use crate::models::{NewTwoFactorRow, TwoFactorRow};
use crate::schema::two_factor;

#[async_trait]
impl TwoFactorOps for DieselSqliteAdapter {
    type TwoFactor = TwoFactor;

    async fn create_two_factor(&self, data: CreateTwoFactor) -> AuthResult<Self::TwoFactor> {
        let new_row = NewTwoFactorRow::from(data);
        let row_id = new_row.id.clone();

        self.interact(move |conn| {
            diesel::insert_into(two_factor::table)
                .values(&new_row)
                .execute(conn)
                .map_err(diesel_to_auth_error)?;

            two_factor::table
                .filter(two_factor::id.eq(&row_id))
                .first::<TwoFactorRow>(conn)
                .map(TwoFactor::from)
                .map_err(diesel_to_auth_error)
        })
        .await
    }

    async fn get_two_factor_by_user_id(
        &self,
        user_id: &str,
    ) -> AuthResult<Option<Self::TwoFactor>> {
        let user_id = user_id.to_string();
        self.interact(move |conn| {
            two_factor::table
                .filter(two_factor::user_id.eq(&user_id))
                .first::<TwoFactorRow>(conn)
                .optional()
                .map(|opt| opt.map(TwoFactor::from))
                .map_err(diesel_to_auth_error)
        })
        .await
    }

    async fn update_two_factor_backup_codes(
        &self,
        user_id: &str,
        backup_codes: &str,
    ) -> AuthResult<Self::TwoFactor> {
        let user_id = user_id.to_string();
        let backup_codes = backup_codes.to_string();
        let now = now_iso();

        self.interact(move |conn| {
            diesel::update(two_factor::table.filter(two_factor::user_id.eq(&user_id)))
                .set((
                    two_factor::backup_codes.eq(Some(&backup_codes)),
                    two_factor::updated_at.eq(&now),
                ))
                .execute(conn)
                .map_err(diesel_to_auth_error)?;

            two_factor::table
                .filter(two_factor::user_id.eq(&user_id))
                .first::<TwoFactorRow>(conn)
                .map(TwoFactor::from)
                .map_err(diesel_to_auth_error)
        })
        .await
    }

    async fn delete_two_factor(&self, user_id: &str) -> AuthResult<()> {
        let user_id = user_id.to_string();
        self.interact(move |conn| {
            diesel::delete(two_factor::table.filter(two_factor::user_id.eq(&user_id)))
                .execute(conn)
                .map_err(diesel_to_auth_error)?;
            Ok(())
        })
        .await
    }
}
