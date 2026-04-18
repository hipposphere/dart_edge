//! `Diesel` model structs for each auth table.
//!
//! Each table has model types:
//! - A `*Row` struct with `Queryable` + `Selectable` for reading
//! - A `New*Row` struct with `Insertable` for writing
//! - An `Update*Row` struct with `AsChangeset` for partial updates (where needed)
//!
//! These are `Diesel`-native types. Conversion to/from `better-auth-core`
//! entity types happens in `conversions.rs`.

use crate::schema::{
    accounts, api_keys, invitation, member, organization, passkeys, sessions, two_factor, users,
    verifications,
};
use diesel::prelude::*;

// ============ User ============

#[derive(Queryable, Selectable, Debug, Clone)]
#[diesel(table_name = users)]
#[diesel(check_for_backend(diesel::sqlite::Sqlite))]
pub struct UserRow {
    pub id: String,
    pub name: Option<String>,
    pub email: String,
    pub username: Option<String>,
    pub display_username: Option<String>,
    pub email_verified: bool,
    pub image: Option<String>,
    pub role: String,
    pub banned: bool,
    pub ban_reason: Option<String>,
    pub ban_expires: Option<String>,
    pub two_factor_enabled: bool,
    pub metadata: Option<String>,
    pub created_at: String,
    pub updated_at: String,
}

#[derive(Insertable, Debug)]
#[diesel(table_name = users)]
pub struct NewUserRow {
    pub id: String,
    pub name: Option<String>,
    pub email: String,
    pub username: Option<String>,
    pub display_username: Option<String>,
    pub email_verified: bool,
    pub image: Option<String>,
    pub role: String,
    pub banned: bool,
    pub ban_reason: Option<String>,
    pub ban_expires: Option<String>,
    pub two_factor_enabled: bool,
    pub metadata: Option<String>,
    pub created_at: String,
    pub updated_at: String,
}

#[derive(AsChangeset, Debug, Default)]
#[diesel(table_name = users)]
pub struct UpdateUserRow {
    pub name: Option<Option<String>>,
    pub email: Option<String>,
    pub username: Option<Option<String>>,
    pub display_username: Option<Option<String>>,
    pub email_verified: Option<bool>,
    pub image: Option<Option<String>>,
    pub role: Option<String>,
    pub banned: Option<bool>,
    pub ban_reason: Option<Option<String>>,
    pub ban_expires: Option<Option<String>>,
    pub two_factor_enabled: Option<bool>,
    pub metadata: Option<Option<String>>,
    pub updated_at: Option<String>,
}

// ============ Session ============

#[derive(Queryable, Selectable, Debug, Clone)]
#[diesel(table_name = sessions)]
#[diesel(check_for_backend(diesel::sqlite::Sqlite))]
pub struct SessionRow {
    pub id: String,
    pub user_id: String,
    pub token: String,
    pub ip_address: Option<String>,
    pub user_agent: Option<String>,
    pub expires_at: String,
    pub active_organization_id: Option<String>,
    pub impersonated_by: Option<String>,
    pub active: bool,
    pub created_at: String,
    pub updated_at: String,
}

#[derive(Insertable, Debug)]
#[diesel(table_name = sessions)]
pub struct NewSessionRow {
    pub id: String,
    pub user_id: String,
    pub token: String,
    pub ip_address: Option<String>,
    pub user_agent: Option<String>,
    pub expires_at: String,
    pub active_organization_id: Option<String>,
    pub impersonated_by: Option<String>,
    pub active: bool,
    pub created_at: String,
    pub updated_at: String,
}

// ============ Account ============

#[derive(Queryable, Selectable, Debug, Clone)]
#[diesel(table_name = accounts)]
#[diesel(check_for_backend(diesel::sqlite::Sqlite))]
pub struct AccountRow {
    pub id: String,
    pub user_id: String,
    pub account_id: String,
    pub provider_id: String,
    pub access_token: Option<String>,
    pub refresh_token: Option<String>,
    pub id_token: Option<String>,
    pub access_token_expires_at: Option<String>,
    pub refresh_token_expires_at: Option<String>,
    pub scope: Option<String>,
    pub password: Option<String>,
    pub created_at: String,
    pub updated_at: String,
}

#[derive(Insertable, Debug)]
#[diesel(table_name = accounts)]
pub struct NewAccountRow {
    pub id: String,
    pub user_id: String,
    pub account_id: String,
    pub provider_id: String,
    pub access_token: Option<String>,
    pub refresh_token: Option<String>,
    pub id_token: Option<String>,
    pub access_token_expires_at: Option<String>,
    pub refresh_token_expires_at: Option<String>,
    pub scope: Option<String>,
    pub password: Option<String>,
    pub created_at: String,
    pub updated_at: String,
}

#[derive(AsChangeset, Debug, Default)]
#[diesel(table_name = accounts)]
pub struct UpdateAccountRow {
    pub access_token: Option<Option<String>>,
    pub refresh_token: Option<Option<String>>,
    pub id_token: Option<Option<String>>,
    pub access_token_expires_at: Option<Option<String>>,
    pub refresh_token_expires_at: Option<Option<String>>,
    pub scope: Option<Option<String>>,
    pub password: Option<Option<String>>,
    pub updated_at: Option<String>,
}

// ============ Verification ============

#[derive(Queryable, Selectable, Debug, Clone)]
#[diesel(table_name = verifications)]
#[diesel(check_for_backend(diesel::sqlite::Sqlite))]
pub struct VerificationRow {
    pub id: String,
    pub identifier: String,
    pub value: String,
    pub expires_at: String,
    pub created_at: String,
    pub updated_at: String,
}

#[derive(Insertable, Debug)]
#[diesel(table_name = verifications)]
pub struct NewVerificationRow {
    pub id: String,
    pub identifier: String,
    pub value: String,
    pub expires_at: String,
    pub created_at: String,
    pub updated_at: String,
}

// ============ Organization ============

#[derive(Queryable, Selectable, Debug, Clone)]
#[diesel(table_name = organization)]
#[diesel(check_for_backend(diesel::sqlite::Sqlite))]
pub struct OrganizationRow {
    pub id: String,
    pub name: String,
    pub slug: String,
    pub logo: Option<String>,
    pub metadata: Option<String>,
    pub created_at: String,
    pub updated_at: String,
}

#[derive(Insertable, Debug)]
#[diesel(table_name = organization)]
pub struct NewOrganizationRow {
    pub id: String,
    pub name: String,
    pub slug: String,
    pub logo: Option<String>,
    pub metadata: Option<String>,
    pub created_at: String,
    pub updated_at: String,
}

#[derive(AsChangeset, Debug, Default)]
#[diesel(table_name = organization)]
pub struct UpdateOrganizationRow {
    pub name: Option<String>,
    pub slug: Option<String>,
    pub logo: Option<Option<String>>,
    pub metadata: Option<Option<String>>,
    pub updated_at: Option<String>,
}

// ============ Member ============

#[derive(Queryable, Selectable, Debug, Clone)]
#[diesel(table_name = member)]
#[diesel(check_for_backend(diesel::sqlite::Sqlite))]
pub struct MemberRow {
    pub id: String,
    pub user_id: String,
    pub organization_id: String,
    pub role: String,
    pub created_at: String,
}

#[derive(Insertable, Debug)]
#[diesel(table_name = member)]
pub struct NewMemberRow {
    pub id: String,
    pub user_id: String,
    pub organization_id: String,
    pub role: String,
    pub created_at: String,
}

// ============ Invitation ============

#[derive(Queryable, Selectable, Debug, Clone)]
#[diesel(table_name = invitation)]
#[diesel(check_for_backend(diesel::sqlite::Sqlite))]
pub struct InvitationRow {
    pub id: String,
    pub organization_id: String,
    pub email: String,
    pub role: String,
    pub status: String,
    pub inviter_id: String,
    pub expires_at: String,
    pub created_at: String,
}

#[derive(Insertable, Debug)]
#[diesel(table_name = invitation)]
pub struct NewInvitationRow {
    pub id: String,
    pub organization_id: String,
    pub email: String,
    pub role: String,
    pub status: String,
    pub inviter_id: String,
    pub expires_at: String,
    pub created_at: String,
}

// ============ TwoFactor ============

#[derive(Queryable, Selectable, Debug, Clone)]
#[diesel(table_name = two_factor)]
#[diesel(check_for_backend(diesel::sqlite::Sqlite))]
pub struct TwoFactorRow {
    pub id: String,
    pub user_id: String,
    pub secret: String,
    pub backup_codes: Option<String>,
    pub created_at: String,
    pub updated_at: String,
}

#[derive(Insertable, Debug)]
#[diesel(table_name = two_factor)]
pub struct NewTwoFactorRow {
    pub id: String,
    pub user_id: String,
    pub secret: String,
    pub backup_codes: Option<String>,
    pub created_at: String,
    pub updated_at: String,
}

// ============ ApiKey ============

#[derive(Queryable, Selectable, Debug, Clone)]
#[diesel(table_name = api_keys)]
#[diesel(check_for_backend(diesel::sqlite::Sqlite))]
pub struct ApiKeyRow {
    pub id: String,
    pub user_id: String,
    pub name: Option<String>,
    pub start: Option<String>,
    pub prefix: Option<String>,
    pub key: String,
    pub enabled: bool,
    pub rate_limit_enabled: bool,
    pub rate_limit_time_window: Option<i64>,
    pub rate_limit_max: Option<i64>,
    pub request_count: Option<i64>,
    pub remaining: Option<i64>,
    pub refill_interval: Option<i64>,
    pub refill_amount: Option<i64>,
    pub last_refill_at: Option<String>,
    pub last_request: Option<String>,
    pub expires_at: Option<String>,
    pub created_at: String,
    pub updated_at: String,
    pub permissions: Option<String>,
    pub metadata: Option<String>,
}

#[derive(Insertable, Debug)]
#[diesel(table_name = api_keys)]
pub struct NewApiKeyRow {
    pub id: String,
    pub user_id: String,
    pub name: Option<String>,
    pub start: Option<String>,
    pub prefix: Option<String>,
    pub key: String,
    pub enabled: bool,
    pub rate_limit_enabled: bool,
    pub rate_limit_time_window: Option<i64>,
    pub rate_limit_max: Option<i64>,
    pub request_count: Option<i64>,
    pub remaining: Option<i64>,
    pub refill_interval: Option<i64>,
    pub refill_amount: Option<i64>,
    pub last_refill_at: Option<String>,
    pub last_request: Option<String>,
    pub expires_at: Option<String>,
    pub created_at: String,
    pub updated_at: String,
    pub permissions: Option<String>,
    pub metadata: Option<String>,
}

#[derive(AsChangeset, Debug, Default)]
#[diesel(table_name = api_keys)]
pub struct UpdateApiKeyRow {
    pub name: Option<Option<String>>,
    pub enabled: Option<bool>,
    pub remaining: Option<Option<i64>>,
    pub rate_limit_enabled: Option<bool>,
    pub rate_limit_time_window: Option<Option<i64>>,
    pub rate_limit_max: Option<Option<i64>>,
    pub refill_interval: Option<Option<i64>>,
    pub refill_amount: Option<Option<i64>>,
    pub request_count: Option<Option<i64>>,
    pub last_refill_at: Option<Option<String>>,
    pub last_request: Option<Option<String>>,
    pub expires_at: Option<Option<String>>,
    pub permissions: Option<Option<String>>,
    pub metadata: Option<Option<String>>,
    pub updated_at: Option<String>,
}

// ============ Passkey ============

#[derive(Queryable, Selectable, Debug, Clone)]
#[diesel(table_name = passkeys)]
#[diesel(check_for_backend(diesel::sqlite::Sqlite))]
pub struct PasskeyRow {
    pub id: String,
    pub user_id: String,
    pub name: String,
    pub credential_id: String,
    pub public_key: String,
    pub counter: i64,
    pub device_type: String,
    pub backed_up: bool,
    pub transports: Option<String>,
    pub created_at: String,
}

#[derive(Insertable, Debug)]
#[diesel(table_name = passkeys)]
pub struct NewPasskeyRow {
    pub id: String,
    pub user_id: String,
    pub name: String,
    pub credential_id: String,
    pub public_key: String,
    pub counter: i64,
    pub device_type: String,
    pub backed_up: bool,
    pub transports: Option<String>,
    pub created_at: String,
}
