//! `OrganizationOps` trait implementation for `DieselSqliteAdapter`.
//!
//! Methods:
//! - `create_organization` — Insert new org
//! - `get_organization_by_id` — Lookup by ID
//! - `get_organization_by_slug` — Lookup by unique slug
//! - `update_organization` — Partial update (name, slug, logo, metadata)
//! - `delete_organization` — Remove by ID (cascades to members, invitations)
//! - `list_user_organizations` — Join through members table

use async_trait::async_trait;
use better_auth_core::adapters::OrganizationOps;
use better_auth_core::error::AuthResult;
use better_auth_core::types::{CreateOrganization, Organization, UpdateOrganization};
use diesel::prelude::*;

use crate::adapter::DieselSqliteAdapter;
use crate::error::diesel_to_auth_error;
use crate::models::{NewOrganizationRow, OrganizationRow, UpdateOrganizationRow};
use crate::schema::{member, organization};

#[async_trait]
impl OrganizationOps for DieselSqliteAdapter {
    type Organization = Organization;

    async fn create_organization(&self, org: CreateOrganization) -> AuthResult<Self::Organization> {
        let new_row = NewOrganizationRow::from(org);
        let row_id = new_row.id.clone();

        self.interact(move |conn| {
            diesel::insert_into(organization::table)
                .values(&new_row)
                .execute(conn)
                .map_err(diesel_to_auth_error)?;

            organization::table
                .filter(organization::id.eq(&row_id))
                .first::<OrganizationRow>(conn)
                .map(Organization::from)
                .map_err(diesel_to_auth_error)
        })
        .await
    }

    async fn get_organization_by_id(&self, id: &str) -> AuthResult<Option<Self::Organization>> {
        let id = id.to_string();
        self.interact(move |conn| {
            organization::table
                .filter(organization::id.eq(&id))
                .first::<OrganizationRow>(conn)
                .optional()
                .map(|opt| opt.map(Organization::from))
                .map_err(diesel_to_auth_error)
        })
        .await
    }

    async fn get_organization_by_slug(&self, slug: &str) -> AuthResult<Option<Self::Organization>> {
        let slug = slug.to_string();
        self.interact(move |conn| {
            organization::table
                .filter(organization::slug.eq(&slug))
                .first::<OrganizationRow>(conn)
                .optional()
                .map(|opt| opt.map(Organization::from))
                .map_err(diesel_to_auth_error)
        })
        .await
    }

    async fn update_organization(
        &self,
        id: &str,
        update: UpdateOrganization,
    ) -> AuthResult<Self::Organization> {
        let id = id.to_string();
        let changeset = UpdateOrganizationRow::from(update);

        self.interact(move |conn| {
            diesel::update(organization::table.filter(organization::id.eq(&id)))
                .set(&changeset)
                .execute(conn)
                .map_err(diesel_to_auth_error)?;

            organization::table
                .filter(organization::id.eq(&id))
                .first::<OrganizationRow>(conn)
                .map(Organization::from)
                .map_err(diesel_to_auth_error)
        })
        .await
    }

    async fn delete_organization(&self, id: &str) -> AuthResult<()> {
        let id = id.to_string();
        self.interact(move |conn| {
            diesel::delete(organization::table.filter(organization::id.eq(&id)))
                .execute(conn)
                .map_err(diesel_to_auth_error)?;
            Ok(())
        })
        .await
    }

    async fn list_user_organizations(&self, user_id: &str) -> AuthResult<Vec<Self::Organization>> {
        let user_id = user_id.to_string();
        self.interact(move |conn| {
            organization::table
                .inner_join(member::table.on(member::organization_id.eq(organization::id)))
                .filter(member::user_id.eq(&user_id))
                .select(OrganizationRow::as_select())
                .order(organization::created_at.desc())
                .load::<OrganizationRow>(conn)
                .map(|rows| rows.into_iter().map(Organization::from).collect())
                .map_err(diesel_to_auth_error)
        })
        .await
    }
}
