//! `InvitationOps` trait implementation for `DieselSqliteAdapter`.
//!
//! Methods:
//! - `create_invitation` — Create org invitation
//! - `get_invitation_by_id` — Lookup by ID
//! - `get_pending_invitation` — Lookup by (email, `org_id`, status = `pending`)
//! - `update_invitation_status` — Change status (`pending` -> `accepted`/`rejected`/`canceled`)
//! - `list_organization_invitations` — All invitations for an organization
//! - `list_user_invitations` — All invitations for an email address

use async_trait::async_trait;
use better_auth_core::adapters::InvitationOps;
use better_auth_core::error::AuthResult;
use better_auth_core::types::{CreateInvitation, Invitation, InvitationStatus};
use diesel::prelude::*;

use crate::adapter::DieselSqliteAdapter;
use crate::conversions::invitation_status_to_string;
use crate::error::diesel_to_auth_error;
use crate::models::{InvitationRow, NewInvitationRow};
use crate::schema::invitation;

#[async_trait]
impl InvitationOps for DieselSqliteAdapter {
    type Invitation = Invitation;

    async fn create_invitation(&self, data: CreateInvitation) -> AuthResult<Self::Invitation> {
        let new_row = NewInvitationRow::from(data);
        let row_id = new_row.id.clone();

        self.interact(move |conn| {
            diesel::insert_into(invitation::table)
                .values(&new_row)
                .execute(conn)
                .map_err(diesel_to_auth_error)?;

            invitation::table
                .filter(invitation::id.eq(&row_id))
                .first::<InvitationRow>(conn)
                .map(Invitation::from)
                .map_err(diesel_to_auth_error)
        })
        .await
    }

    async fn get_invitation_by_id(&self, id: &str) -> AuthResult<Option<Self::Invitation>> {
        let id = id.to_string();
        self.interact(move |conn| {
            invitation::table
                .filter(invitation::id.eq(&id))
                .first::<InvitationRow>(conn)
                .optional()
                .map(|opt| opt.map(Invitation::from))
                .map_err(diesel_to_auth_error)
        })
        .await
    }

    async fn get_pending_invitation(
        &self,
        organization_id: &str,
        email: &str,
    ) -> AuthResult<Option<Self::Invitation>> {
        let organization_id = organization_id.to_string();
        let email = email.to_string();
        self.interact(move |conn| {
            invitation::table
                .filter(invitation::organization_id.eq(&organization_id))
                .filter(invitation::email.eq(&email))
                .filter(invitation::status.eq("pending"))
                .first::<InvitationRow>(conn)
                .optional()
                .map(|opt| opt.map(Invitation::from))
                .map_err(diesel_to_auth_error)
        })
        .await
    }

    async fn update_invitation_status(
        &self,
        id: &str,
        status: InvitationStatus,
    ) -> AuthResult<Self::Invitation> {
        let id = id.to_string();
        let status_str = invitation_status_to_string(&status);

        self.interact(move |conn| {
            diesel::update(invitation::table.filter(invitation::id.eq(&id)))
                .set(invitation::status.eq(&status_str))
                .execute(conn)
                .map_err(diesel_to_auth_error)?;

            invitation::table
                .filter(invitation::id.eq(&id))
                .first::<InvitationRow>(conn)
                .map(Invitation::from)
                .map_err(diesel_to_auth_error)
        })
        .await
    }

    async fn list_organization_invitations(
        &self,
        organization_id: &str,
    ) -> AuthResult<Vec<Self::Invitation>> {
        let organization_id = organization_id.to_string();
        self.interact(move |conn| {
            invitation::table
                .filter(invitation::organization_id.eq(&organization_id))
                .order(invitation::created_at.desc())
                .load::<InvitationRow>(conn)
                .map(|rows| rows.into_iter().map(Invitation::from).collect())
                .map_err(diesel_to_auth_error)
        })
        .await
    }

    async fn list_user_invitations(&self, email: &str) -> AuthResult<Vec<Self::Invitation>> {
        let email = email.to_string();
        self.interact(move |conn| {
            invitation::table
                .filter(invitation::email.eq(&email))
                .order(invitation::created_at.desc())
                .load::<InvitationRow>(conn)
                .map(|rows| rows.into_iter().map(Invitation::from).collect())
                .map_err(diesel_to_auth_error)
        })
        .await
    }
}
