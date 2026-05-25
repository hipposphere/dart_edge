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
use crate::schema::session;

#[async_trait]
impl SessionOps for DieselSqliteAdapter {
    type Session = Session;

    async fn create_session(&self, data: CreateSession) -> AuthResult<Self::Session> {
        let new_row = NewSessionRow::from(data);
        let token = new_row.token.clone();

        self.interact(move |conn| {
            diesel::insert_into(session::table)
                .values(&new_row)
                .execute(conn)
                .map_err(diesel_to_auth_error)?;

            session::table
                .filter(session::token.eq(&token))
                .first::<SessionRow>(conn)
                .map(Session::from)
                .map_err(diesel_to_auth_error)
        })
        .await
    }

    async fn get_session(&self, token: &str) -> AuthResult<Option<Self::Session>> {
        let token = token.to_string();
        self.interact(move |conn| {
            session::table
                .filter(session::token.eq(&token))
                .filter(session::active.eq(true))
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
            session::table
                .filter(session::user_id.eq(&user_id))
                .filter(session::active.eq(true))
                .order(session::created_at.desc())
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
                session::table
                    .filter(session::token.eq(&token))
                    .filter(session::active.eq(true)),
            )
            .set((
                session::expires_at.eq(&expires_str),
                session::updated_at.eq(&now),
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
            diesel::delete(session::table.filter(session::token.eq(&token)))
                .execute(conn)
                .map_err(diesel_to_auth_error)?;
            Ok(())
        })
        .await
    }

    async fn delete_user_sessions(&self, user_id: &str) -> AuthResult<()> {
        let user_id = user_id.to_string();
        self.interact(move |conn| {
            diesel::delete(session::table.filter(session::user_id.eq(&user_id)))
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
                session::table
                    .filter(session::expires_at.lt(&now).or(session::active.eq(false))),
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
                session::table
                    .filter(session::token.eq(&token))
                    .filter(session::active.eq(true)),
            )
            .set((
                session::active_organization_id.eq(&org_id),
                session::updated_at.eq(&now),
            ))
            .execute(conn)
            .map_err(diesel_to_auth_error)?;

            session::table
                .filter(session::token.eq(&token))
                .first::<SessionRow>(conn)
                .map(Session::from)
                .map_err(diesel_to_auth_error)
        })
        .await
    }
}
