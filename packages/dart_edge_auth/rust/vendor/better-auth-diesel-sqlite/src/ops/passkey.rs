//! `PasskeyOps` trait implementation for `DieselSqliteAdapter`.
//!
//! Methods:
//! - `create_passkey` — Store `WebAuthn` credential
//! - `get_passkey_by_id` — Lookup by ID
//! - `get_passkey_by_credential_id` — Lookup by `credential_id` (unique)
//! - `list_passkeys_by_user` — All passkeys for a user
//! - `update_passkey_counter` — Update counter after authentication
//! - `update_passkey_name` — Rename a passkey
//! - `delete_passkey` — Remove credential

use async_trait::async_trait;
use better_auth_core::adapters::PasskeyOps;
use better_auth_core::error::AuthResult;
use better_auth_core::types::{CreatePasskey, Passkey};
use diesel::prelude::*;

use crate::adapter::DieselSqliteAdapter;
use crate::error::diesel_to_auth_error;
use crate::models::{NewPasskeyRow, PasskeyRow};
use crate::schema::passkeys;

#[async_trait]
impl PasskeyOps for DieselSqliteAdapter {
    type Passkey = Passkey;

    async fn create_passkey(&self, input: CreatePasskey) -> AuthResult<Self::Passkey> {
        let new_row = NewPasskeyRow::from(input);
        let row_id = new_row.id.clone();

        self.interact(move |conn| {
            diesel::insert_into(passkeys::table)
                .values(&new_row)
                .execute(conn)
                .map_err(diesel_to_auth_error)?;

            passkeys::table
                .filter(passkeys::id.eq(&row_id))
                .first::<PasskeyRow>(conn)
                .map(Passkey::from)
                .map_err(diesel_to_auth_error)
        })
        .await
    }

    async fn get_passkey_by_id(&self, id: &str) -> AuthResult<Option<Self::Passkey>> {
        let id = id.to_string();
        self.interact(move |conn| {
            passkeys::table
                .filter(passkeys::id.eq(&id))
                .first::<PasskeyRow>(conn)
                .optional()
                .map(|opt| opt.map(Passkey::from))
                .map_err(diesel_to_auth_error)
        })
        .await
    }

    async fn get_passkey_by_credential_id(
        &self,
        credential_id: &str,
    ) -> AuthResult<Option<Self::Passkey>> {
        let credential_id = credential_id.to_string();
        self.interact(move |conn| {
            passkeys::table
                .filter(passkeys::credential_id.eq(&credential_id))
                .first::<PasskeyRow>(conn)
                .optional()
                .map(|opt| opt.map(Passkey::from))
                .map_err(diesel_to_auth_error)
        })
        .await
    }

    async fn list_passkeys_by_user(&self, user_id: &str) -> AuthResult<Vec<Self::Passkey>> {
        let user_id = user_id.to_string();
        self.interact(move |conn| {
            passkeys::table
                .filter(passkeys::user_id.eq(&user_id))
                .load::<PasskeyRow>(conn)
                .map(|rows| rows.into_iter().map(Passkey::from).collect())
                .map_err(diesel_to_auth_error)
        })
        .await
    }

    async fn update_passkey_counter(&self, id: &str, counter: u64) -> AuthResult<Self::Passkey> {
        let id = id.to_string();
        #[allow(clippy::cast_possible_wrap)]
        let counter_i64 = counter as i64;

        self.interact(move |conn| {
            diesel::update(passkeys::table.filter(passkeys::id.eq(&id)))
                .set(passkeys::counter.eq(counter_i64))
                .execute(conn)
                .map_err(diesel_to_auth_error)?;

            passkeys::table
                .filter(passkeys::id.eq(&id))
                .first::<PasskeyRow>(conn)
                .map(Passkey::from)
                .map_err(diesel_to_auth_error)
        })
        .await
    }

    async fn update_passkey_name(&self, id: &str, name: &str) -> AuthResult<Self::Passkey> {
        let id = id.to_string();
        let name = name.to_string();

        self.interact(move |conn| {
            diesel::update(passkeys::table.filter(passkeys::id.eq(&id)))
                .set(passkeys::name.eq(&name))
                .execute(conn)
                .map_err(diesel_to_auth_error)?;

            passkeys::table
                .filter(passkeys::id.eq(&id))
                .first::<PasskeyRow>(conn)
                .map(Passkey::from)
                .map_err(diesel_to_auth_error)
        })
        .await
    }

    async fn delete_passkey(&self, id: &str) -> AuthResult<()> {
        let id = id.to_string();
        self.interact(move |conn| {
            diesel::delete(passkeys::table.filter(passkeys::id.eq(&id)))
                .execute(conn)
                .map_err(diesel_to_auth_error)?;
            Ok(())
        })
        .await
    }
}
