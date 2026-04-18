//! `ApiKeyOps` trait implementation for `DieselSqliteAdapter`.
//!
//! Methods:
//! - `create_api_key` — Insert new API key (hash stored, not plaintext)
//! - `get_api_key_by_id` — Lookup by ID
//! - `get_api_key_by_hash` — Lookup by `key_hash` (for verification)
//! - `list_api_keys_by_user` — All API keys for a user
//! - `update_api_key` — Partial update (name, enabled, remaining, rate limits, etc.)
//! - `delete_api_key` — Remove by ID
//! - `delete_expired_api_keys` — Cleanup expired keys

use async_trait::async_trait;
use better_auth_core::adapters::ApiKeyOps;
use better_auth_core::error::AuthResult;
use better_auth_core::types::{ApiKey, CreateApiKey, UpdateApiKey};
use diesel::prelude::*;

use crate::adapter::DieselSqliteAdapter;
use crate::conversions::now_iso;
use crate::error::diesel_to_auth_error;
use crate::models::{ApiKeyRow, NewApiKeyRow, UpdateApiKeyRow};
use crate::schema::api_keys;

#[async_trait]
impl ApiKeyOps for DieselSqliteAdapter {
    type ApiKey = ApiKey;

    async fn create_api_key(&self, input: CreateApiKey) -> AuthResult<Self::ApiKey> {
        let new_row = NewApiKeyRow::from(input);
        let row_id = new_row.id.clone();

        self.interact(move |conn| {
            diesel::insert_into(api_keys::table)
                .values(&new_row)
                .execute(conn)
                .map_err(diesel_to_auth_error)?;

            api_keys::table
                .filter(api_keys::id.eq(&row_id))
                .first::<ApiKeyRow>(conn)
                .map(ApiKey::from)
                .map_err(diesel_to_auth_error)
        })
        .await
    }

    async fn get_api_key_by_id(&self, id: &str) -> AuthResult<Option<Self::ApiKey>> {
        let id = id.to_string();
        self.interact(move |conn| {
            api_keys::table
                .filter(api_keys::id.eq(&id))
                .first::<ApiKeyRow>(conn)
                .optional()
                .map(|opt| opt.map(ApiKey::from))
                .map_err(diesel_to_auth_error)
        })
        .await
    }

    async fn get_api_key_by_hash(&self, hash: &str) -> AuthResult<Option<Self::ApiKey>> {
        let hash = hash.to_string();
        self.interact(move |conn| {
            api_keys::table
                .filter(api_keys::key.eq(&hash))
                .first::<ApiKeyRow>(conn)
                .optional()
                .map(|opt| opt.map(ApiKey::from))
                .map_err(diesel_to_auth_error)
        })
        .await
    }

    async fn list_api_keys_by_user(&self, user_id: &str) -> AuthResult<Vec<Self::ApiKey>> {
        let user_id = user_id.to_string();
        self.interact(move |conn| {
            api_keys::table
                .filter(api_keys::user_id.eq(&user_id))
                .load::<ApiKeyRow>(conn)
                .map(|rows| rows.into_iter().map(ApiKey::from).collect())
                .map_err(diesel_to_auth_error)
        })
        .await
    }

    async fn update_api_key(&self, id: &str, update: UpdateApiKey) -> AuthResult<Self::ApiKey> {
        let id = id.to_string();
        let changeset = UpdateApiKeyRow::from(update);

        self.interact(move |conn| {
            diesel::update(api_keys::table.filter(api_keys::id.eq(&id)))
                .set(&changeset)
                .execute(conn)
                .map_err(diesel_to_auth_error)?;

            api_keys::table
                .filter(api_keys::id.eq(&id))
                .first::<ApiKeyRow>(conn)
                .map(ApiKey::from)
                .map_err(diesel_to_auth_error)
        })
        .await
    }

    async fn delete_api_key(&self, id: &str) -> AuthResult<()> {
        let id = id.to_string();
        self.interact(move |conn| {
            diesel::delete(api_keys::table.filter(api_keys::id.eq(&id)))
                .execute(conn)
                .map_err(diesel_to_auth_error)?;
            Ok(())
        })
        .await
    }

    async fn delete_expired_api_keys(&self) -> AuthResult<usize> {
        let now = now_iso();
        self.interact(move |conn| {
            let deleted = diesel::delete(
                api_keys::table
                    .filter(api_keys::expires_at.is_not_null())
                    .filter(api_keys::expires_at.lt(&now)),
            )
            .execute(conn)
            .map_err(diesel_to_auth_error)?;
            Ok(deleted)
        })
        .await
    }
}
