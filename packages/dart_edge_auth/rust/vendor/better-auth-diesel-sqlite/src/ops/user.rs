//! `UserOps` trait implementation for `DieselSqliteAdapter`.

use async_trait::async_trait;
use better_auth_core::adapters::UserOps;
use better_auth_core::error::AuthResult;
use better_auth_core::types::{CreateUser, ListUsersParams, UpdateUser, User};
use diesel::prelude::*;

use crate::adapter::DieselSqliteAdapter;
use crate::error::diesel_to_auth_error;
use crate::models::{NewUserRow, UpdateUserRow, UserRow};
use crate::schema::user;

#[async_trait]
impl UserOps for DieselSqliteAdapter {
    type User = User;

    async fn create_user(&self, data: CreateUser) -> AuthResult<Self::User> {
        let new_row = NewUserRow::from(data);
        let row_id = new_row.id.clone();

        self.interact(move |conn| {
            diesel::insert_into(user::table)
                .values(&new_row)
                .execute(conn)
                .map_err(diesel_to_auth_error)?;

            user::table
                .filter(user::id.eq(&row_id))
                .first::<UserRow>(conn)
                .map(User::from)
                .map_err(diesel_to_auth_error)
        })
        .await
    }

    async fn get_user_by_id(&self, id: &str) -> AuthResult<Option<Self::User>> {
        let id = id.to_string();
        self.interact(move |conn| {
            user::table
                .filter(user::id.eq(&id))
                .first::<UserRow>(conn)
                .optional()
                .map(|opt| opt.map(User::from))
                .map_err(diesel_to_auth_error)
        })
        .await
    }

    async fn get_user_by_email(&self, email: &str) -> AuthResult<Option<Self::User>> {
        let email = email.to_string();
        self.interact(move |conn| {
            user::table
                .filter(user::email.eq(&email))
                .first::<UserRow>(conn)
                .optional()
                .map(|opt| opt.map(User::from))
                .map_err(diesel_to_auth_error)
        })
        .await
    }

    async fn get_user_by_username(&self, username: &str) -> AuthResult<Option<Self::User>> {
        let username = username.to_string();
        self.interact(move |conn| {
            user::table
                .filter(user::username.eq(&username))
                .first::<UserRow>(conn)
                .optional()
                .map(|opt| opt.map(User::from))
                .map_err(diesel_to_auth_error)
        })
        .await
    }

    async fn update_user(&self, id: &str, update: UpdateUser) -> AuthResult<Self::User> {
        let id = id.to_string();
        let changeset = UpdateUserRow::from(update);

        self.interact(move |conn| {
            diesel::update(user::table.filter(user::id.eq(&id)))
                .set(&changeset)
                .execute(conn)
                .map_err(diesel_to_auth_error)?;

            user::table
                .filter(user::id.eq(&id))
                .first::<UserRow>(conn)
                .map(User::from)
                .map_err(diesel_to_auth_error)
        })
        .await
    }

    async fn delete_user(&self, id: &str) -> AuthResult<()> {
        let id = id.to_string();
        self.interact(move |conn| {
            diesel::delete(user::table.filter(user::id.eq(&id)))
                .execute(conn)
                .map_err(diesel_to_auth_error)?;
            Ok(())
        })
        .await
    }

    async fn list_users(&self, params: ListUsersParams) -> AuthResult<(Vec<Self::User>, usize)> {
        self.interact(move |conn| {
            let mut query = user::table.into_boxed::<diesel::sqlite::Sqlite>();
            let mut count_query = user::table.into_boxed::<diesel::sqlite::Sqlite>();

            // Apply search filter
            if let (Some(field), Some(value)) = (&params.search_field, &params.search_value) {
                let pattern = format!("%{value}%");
                match field.as_str() {
                    "email" => {
                        query = query.filter(user::email.like(pattern.clone()));
                        count_query = count_query.filter(user::email.like(pattern));
                    }
                    "name" => {
                        query = query.filter(user::name.like(pattern.clone()));
                        count_query = count_query.filter(user::name.like(pattern));
                    }
                    "username" => {
                        query = query.filter(user::username.like(pattern.clone()));
                        count_query = count_query.filter(user::username.like(pattern));
                    }
                    _ => {}
                }
            }

            // Apply exact filter
            if let (Some(field), Some(value)) = (&params.filter_field, &params.filter_value) {
                match field.as_str() {
                    "role" => {
                        query = query.filter(user::role.eq(value.clone()));
                        count_query = count_query.filter(user::role.eq(value.clone()));
                    }
                    "banned" => {
                        let is_banned = value == "true";
                        query = query.filter(user::banned.eq(is_banned));
                        count_query = count_query.filter(user::banned.eq(is_banned));
                    }
                    _ => {}
                }
            }

            // Get total count
            let total: i64 = count_query
                .count()
                .get_result(conn)
                .map_err(diesel_to_auth_error)?;

            // Apply sorting
            let sort_dir = params.sort_direction.as_deref().unwrap_or("asc");
            let sort_field = params.sort_by.as_deref().unwrap_or("created_at");

            query = match (sort_field, sort_dir) {
                ("email", "desc") => query.order(user::email.desc()),
                ("email", _) => query.order(user::email.asc()),
                ("name", "desc") => query.order(user::name.desc()),
                ("name", _) => query.order(user::name.asc()),
                ("created_at", "desc") => query.order(user::created_at.desc()),
                (_, _) => query.order(user::created_at.asc()),
            };

            // Apply pagination
            if let Some(limit) = params.limit {
                query = query.limit(i64::try_from(limit).unwrap_or(i64::MAX));
            }
            if let Some(offset) = params.offset {
                query = query.offset(i64::try_from(offset).unwrap_or(0));
            }

            let rows: Vec<UserRow> = query.load(conn).map_err(diesel_to_auth_error)?;
            let users_vec: Vec<User> = rows.into_iter().map(User::from).collect();

            Ok((users_vec, usize::try_from(total).unwrap_or(0)))
        })
        .await
    }
}
