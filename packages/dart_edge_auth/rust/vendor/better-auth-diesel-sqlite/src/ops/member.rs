//! `MemberOps` trait implementation for `DieselSqliteAdapter`.
//!
//! Methods:
//! - `create_member` — Add user to organization with role
//! - `get_member` — Lookup by (`organization_id`, `user_id`)
//! - `get_member_by_id` — Lookup by ID
//! - `update_member_role` — Change role for a member
//! - `delete_member` — Remove membership
//! - `list_organization_members` — All members of an organization
//! - `count_organization_members` — Count members in an organization
//! - `count_organization_owners` — Count owners in an organization

use async_trait::async_trait;
use better_auth_core::adapters::MemberOps;
use better_auth_core::error::AuthResult;
use better_auth_core::types::{CreateMember, Member};
use diesel::prelude::*;

use crate::adapter::DieselSqliteAdapter;
use crate::error::diesel_to_auth_error;
use crate::models::{MemberRow, NewMemberRow};
use crate::schema::member;

#[async_trait]
impl MemberOps for DieselSqliteAdapter {
    type Member = Member;

    async fn create_member(&self, data: CreateMember) -> AuthResult<Self::Member> {
        let new_row = NewMemberRow::from(data);
        let row_id = new_row.id.clone();

        self.interact(move |conn| {
            diesel::insert_into(member::table)
                .values(&new_row)
                .execute(conn)
                .map_err(diesel_to_auth_error)?;

            member::table
                .filter(member::id.eq(&row_id))
                .first::<MemberRow>(conn)
                .map(Member::from)
                .map_err(diesel_to_auth_error)
        })
        .await
    }

    async fn get_member(
        &self,
        organization_id: &str,
        user_id: &str,
    ) -> AuthResult<Option<Self::Member>> {
        let organization_id = organization_id.to_string();
        let user_id = user_id.to_string();
        self.interact(move |conn| {
            member::table
                .filter(member::organization_id.eq(&organization_id))
                .filter(member::user_id.eq(&user_id))
                .first::<MemberRow>(conn)
                .optional()
                .map(|opt| opt.map(Member::from))
                .map_err(diesel_to_auth_error)
        })
        .await
    }

    async fn get_member_by_id(&self, id: &str) -> AuthResult<Option<Self::Member>> {
        let id = id.to_string();
        self.interact(move |conn| {
            member::table
                .filter(member::id.eq(&id))
                .first::<MemberRow>(conn)
                .optional()
                .map(|opt| opt.map(Member::from))
                .map_err(diesel_to_auth_error)
        })
        .await
    }

    async fn update_member_role(&self, member_id: &str, role: &str) -> AuthResult<Self::Member> {
        let member_id = member_id.to_string();
        let role = role.to_string();

        self.interact(move |conn| {
            diesel::update(member::table.filter(member::id.eq(&member_id)))
                .set(member::role.eq(&role))
                .execute(conn)
                .map_err(diesel_to_auth_error)?;

            member::table
                .filter(member::id.eq(&member_id))
                .first::<MemberRow>(conn)
                .map(Member::from)
                .map_err(diesel_to_auth_error)
        })
        .await
    }

    async fn delete_member(&self, member_id: &str) -> AuthResult<()> {
        let member_id = member_id.to_string();
        self.interact(move |conn| {
            diesel::delete(member::table.filter(member::id.eq(&member_id)))
                .execute(conn)
                .map_err(diesel_to_auth_error)?;
            Ok(())
        })
        .await
    }

    async fn list_organization_members(
        &self,
        organization_id: &str,
    ) -> AuthResult<Vec<Self::Member>> {
        let organization_id = organization_id.to_string();
        self.interact(move |conn| {
            member::table
                .filter(member::organization_id.eq(&organization_id))
                .order(member::created_at.asc())
                .load::<MemberRow>(conn)
                .map(|rows| rows.into_iter().map(Member::from).collect())
                .map_err(diesel_to_auth_error)
        })
        .await
    }

    async fn count_organization_members(&self, organization_id: &str) -> AuthResult<usize> {
        let organization_id = organization_id.to_string();
        self.interact(move |conn| {
            let count: i64 = member::table
                .filter(member::organization_id.eq(&organization_id))
                .count()
                .get_result(conn)
                .map_err(diesel_to_auth_error)?;

            Ok(usize::try_from(count).unwrap_or(0))
        })
        .await
    }

    async fn count_organization_owners(&self, organization_id: &str) -> AuthResult<usize> {
        let organization_id = organization_id.to_string();
        self.interact(move |conn| {
            let count: i64 = member::table
                .filter(member::organization_id.eq(&organization_id))
                .filter(member::role.eq("owner"))
                .count()
                .get_result(conn)
                .map_err(diesel_to_auth_error)?;

            Ok(usize::try_from(count).unwrap_or(0))
        })
        .await
    }
}
