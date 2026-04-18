//! `SessionOps` trait implementation for `DieselSqliteAdapter`.

use async_trait::async_trait;
use better_auth_core::adapters::SessionOps;
use better_auth_core::error::AuthResult;
use better_auth_core::types::{CreateSession, Session};
use chrono::{DateTime, Utc};
use diesel::prelude::*;

use crate::adapter::DieselSqliteAdapter;
use crate::conversions::{format_datetime, now_iso};
use crate::error::diesel_to_auth_error;
use crate::models::{NewSessionRow, SessionRow};
use crate::schema::sessions;

#[async_trait]
impl SessionOps for DieselSqliteAdapter {
    type Session = Session;

    async fn create_session(&self, data: CreateSession) -> AuthResult<Self::Session> {
        let new_row = NewSessionRow::from(data);
        let token = new_row.token.clone();

        self.interact(move |conn| {
            diesel::insert_into(sessions::table)
                .values(&new_row)
                .execute(conn)
                .map_err(diesel_to_auth_error)?;

            sessions::table
                .filter(sessions::token.eq(&token))
                .first::<SessionRow>(conn)
                .map(Session::from)
                .map_err(diesel_to_auth_error)
        })
        .await
    }

    async fn get_session(&self, token: &str) -> AuthResult<Option<Self::Session>> {
        let token = token.to_string();
        self.interact(move |conn| {
            sessions::table
                .filter(sessions::token.eq(&token))
                .filter(sessions::active.eq(true))
                .first::<SessionRow>(conn)
                .optional()
                .map(|opt| opt.map(Session::from))
                .map_err(diesel_to_auth_error)
        })
        .await
    }

    async fn get_user_sessions(&self, user_id: &str) -> AuthResult<Vec<Self::Session>> {
        let user_id = user_id.to_string();
        self.interact(move |conn| {
            sessions::table
                .filter(sessions::user_id.eq(&user_id))
                .filter(sessions::active.eq(true))
                .order(sessions::created_at.desc())
                .load::<SessionRow>(conn)
                .map(|rows| rows.into_iter().map(Session::from).collect())
                .map_err(diesel_to_auth_error)
        })
        .await
    }

    async fn update_session_expiry(
        &self,
        token: &str,
        expires_at: DateTime<Utc>,
    ) -> AuthResult<()> {
        let token = token.to_string();
        let expires_str = format_datetime(&expires_at);
        let now = now_iso();

        self.interact(move |conn| {
            diesel::update(
                sessions::table
                    .filter(sessions::token.eq(&token))
                    .filter(sessions::active.eq(true)),
            )
            .set((
                sessions::expires_at.eq(&expires_str),
                sessions::updated_at.eq(&now),
            ))
            .execute(conn)
            .map_err(diesel_to_auth_error)?;
            Ok(())
        })
        .await
    }

    async fn delete_session(&self, token: &str) -> AuthResult<()> {
        let token = token.to_string();
        self.interact(move |conn| {
            diesel::delete(sessions::table.filter(sessions::token.eq(&token)))
                .execute(conn)
                .map_err(diesel_to_auth_error)?;
            Ok(())
        })
        .await
    }

    async fn delete_user_sessions(&self, user_id: &str) -> AuthResult<()> {
        let user_id = user_id.to_string();
        self.interact(move |conn| {
            diesel::delete(sessions::table.filter(sessions::user_id.eq(&user_id)))
                .execute(conn)
                .map_err(diesel_to_auth_error)?;
            Ok(())
        })
        .await
    }

    async fn delete_expired_sessions(&self) -> AuthResult<usize> {
        let now = now_iso();
        self.interact(move |conn| {
            let deleted = diesel::delete(
                sessions::table
                    .filter(sessions::expires_at.lt(&now).or(sessions::active.eq(false))),
            )
            .execute(conn)
            .map_err(diesel_to_auth_error)?;
            Ok(deleted)
        })
        .await
    }

    async fn update_session_active_organization(
        &self,
        token: &str,
        organization_id: Option<&str>,
    ) -> AuthResult<Self::Session> {
        let token = token.to_string();
        let org_id = organization_id.map(String::from);
        let now = now_iso();

        self.interact(move |conn| {
            diesel::update(
                sessions::table
                    .filter(sessions::token.eq(&token))
                    .filter(sessions::active.eq(true)),
            )
            .set((
                sessions::active_organization_id.eq(&org_id),
                sessions::updated_at.eq(&now),
            ))
            .execute(conn)
            .map_err(diesel_to_auth_error)?;

            sessions::table
                .filter(sessions::token.eq(&token))
                .first::<SessionRow>(conn)
                .map(Session::from)
                .map_err(diesel_to_auth_error)
        })
        .await
    }
}
