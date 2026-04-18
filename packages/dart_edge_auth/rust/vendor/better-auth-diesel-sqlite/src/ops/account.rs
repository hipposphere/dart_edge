//! `AccountOps` trait implementation for `DieselSqliteAdapter`.
//!
//! Methods:
//! - `create_account` — Insert `OAuth` provider link
//! - `get_account` — Lookup by (`provider`, `provider_account_id`)
//! - `get_user_accounts` — All accounts for a user
//! - `update_account` — Partial update (tokens, expiry, scope)
//! - `delete_account` — Remove by ID

use async_trait::async_trait;
use better_auth_core::adapters::AccountOps;
use better_auth_core::error::AuthResult;
use better_auth_core::types::{Account, CreateAccount, UpdateAccount};
use diesel::prelude::*;

use crate::adapter::DieselSqliteAdapter;
use crate::error::diesel_to_auth_error;
use crate::models::{AccountRow, NewAccountRow, UpdateAccountRow};
use crate::schema::accounts;

#[async_trait]
impl AccountOps for DieselSqliteAdapter {
    type Account = Account;

    async fn create_account(&self, account: CreateAccount) -> AuthResult<Self::Account> {
        let new_row = NewAccountRow::from(account);
        let row_id = new_row.id.clone();

        self.interact(move |conn| {
            diesel::insert_into(accounts::table)
                .values(&new_row)
                .execute(conn)
                .map_err(diesel_to_auth_error)?;

            accounts::table
                .filter(accounts::id.eq(&row_id))
                .first::<AccountRow>(conn)
                .map(Account::from)
                .map_err(diesel_to_auth_error)
        })
        .await
    }

    async fn get_account(
        &self,
        provider: &str,
        provider_account_id: &str,
    ) -> AuthResult<Option<Self::Account>> {
        let provider = provider.to_string();
        let provider_account_id = provider_account_id.to_string();
        self.interact(move |conn| {
            accounts::table
                .filter(accounts::provider_id.eq(&provider))
                .filter(accounts::account_id.eq(&provider_account_id))
                .first::<AccountRow>(conn)
                .optional()
                .map(|opt| opt.map(Account::from))
                .map_err(diesel_to_auth_error)
        })
        .await
    }

    async fn get_user_accounts(&self, user_id: &str) -> AuthResult<Vec<Self::Account>> {
        let user_id = user_id.to_string();
        self.interact(move |conn| {
            accounts::table
                .filter(accounts::user_id.eq(&user_id))
                .load::<AccountRow>(conn)
                .map(|rows| rows.into_iter().map(Account::from).collect())
                .map_err(diesel_to_auth_error)
        })
        .await
    }

    async fn update_account(&self, id: &str, update: UpdateAccount) -> AuthResult<Self::Account> {
        let id = id.to_string();
        let changeset = UpdateAccountRow::from(update);

        self.interact(move |conn| {
            diesel::update(accounts::table.filter(accounts::id.eq(&id)))
                .set(&changeset)
                .execute(conn)
                .map_err(diesel_to_auth_error)?;

            accounts::table
                .filter(accounts::id.eq(&id))
                .first::<AccountRow>(conn)
                .map(Account::from)
                .map_err(diesel_to_auth_error)
        })
        .await
    }

    async fn delete_account(&self, id: &str) -> AuthResult<()> {
        let id = id.to_string();
        self.interact(move |conn| {
            diesel::delete(accounts::table.filter(accounts::id.eq(&id)))
                .execute(conn)
                .map_err(diesel_to_auth_error)?;
            Ok(())
        })
        .await
    }
}
