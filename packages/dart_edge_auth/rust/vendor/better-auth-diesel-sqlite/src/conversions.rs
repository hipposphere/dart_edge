//! Bidirectional conversions between `Diesel` model structs and `better-auth-core` entity types.
//!
//! Handles type mapping differences between `SQLite`/`Diesel` and `better-auth`:
//! - `String` (ISO 8601) <-> `DateTime<Utc>`
//! - `String` (JSON) <-> `serde_json::Value`

use better_auth_core::types::{
    Account, ApiKey, CreateAccount, CreateApiKey, CreateInvitation, CreateMember,
    CreateOrganization, CreatePasskey, CreateSession, CreateTwoFactor, CreateUser,
    CreateVerification, Invitation, InvitationStatus, Member, Organization, Passkey, Session,
    TwoFactor, UpdateAccount, UpdateApiKey, UpdateOrganization, User, Verification,
};
use chrono::{DateTime, Utc};
use uuid::Uuid;

use crate::models::{
    AccountRow, ApiKeyRow, InvitationRow, MemberRow, NewAccountRow, NewApiKeyRow, NewInvitationRow,
    NewMemberRow, NewOrganizationRow, NewPasskeyRow, NewSessionRow, NewTwoFactorRow, NewUserRow,
    NewVerificationRow, OrganizationRow, PasskeyRow, SessionRow, TwoFactorRow, UpdateAccountRow,
    UpdateApiKeyRow, UpdateOrganizationRow, UpdateUserRow, UserRow, VerificationRow,
};

// ── Timestamp helpers ──────────────────────────────────────────────────────

/// Parse a timestamp string into `DateTime<Utc>`.
///
/// Handles both ISO 8601 / RFC 3339 text (e.g. `"2026-03-24T01:00:00+00:00"`)
/// and unix epoch integers stored as text (e.g. `"1711234567"`). This allows
/// the adapter to share a database with ORMs that store timestamps as integers
/// (e.g. sqlx with `INTEGER NOT NULL` columns).
pub(crate) fn parse_datetime(s: &str) -> DateTime<Utc> {
    // Try ISO 8601 first (the format we write).
    if let Ok(dt) = DateTime::parse_from_rfc3339(s) {
        return dt.with_timezone(&Utc);
    }
    // Fall back to unix epoch integer (for shared-DB compat with sqlx).
    if let Ok(ts) = s.parse::<i64>()
        && let Some(dt) = DateTime::from_timestamp(ts, 0)
    {
        return dt.with_timezone(&Utc);
    }
    DateTime::default()
}

/// Format a `DateTime<Utc>` as an ISO 8601 / RFC 3339 string.
pub(crate) fn format_datetime(dt: &DateTime<Utc>) -> String {
    dt.to_rfc3339()
}

/// Get the current UTC time as an ISO 8601 string.
pub(crate) fn now_iso() -> String {
    format_datetime(&Utc::now())
}

// ── User conversions ───────────────────────────────────────────────────────

impl From<UserRow> for User {
    fn from(row: UserRow) -> Self {
        let metadata = row
            .metadata
            .as_deref()
            .and_then(|s| serde_json::from_str(s).ok())
            .unwrap_or(serde_json::Value::Object(serde_json::Map::new()));

        User {
            id: row.id,
            name: row.name,
            email: Some(row.email),
            email_verified: row.email_verified,
            image: row.image,
            created_at: parse_datetime(&row.created_at),
            updated_at: parse_datetime(&row.updated_at),
            username: row.username,
            display_username: row.display_username,
            two_factor_enabled: row.two_factor_enabled,
            role: Some(row.role),
            banned: row.banned,
            ban_reason: row.ban_reason,
            ban_expires: row.ban_expires.as_deref().map(parse_datetime),
            metadata,
        }
    }
}

impl From<CreateUser> for NewUserRow {
    fn from(data: CreateUser) -> Self {
        let now = now_iso();
        let id = data.id.unwrap_or_else(|| Uuid::new_v4().to_string());
        let metadata_json = data
            .metadata
            .as_ref()
            .and_then(|v| serde_json::to_string(v).ok());

        NewUserRow {
            id,
            name: data.name,
            email: data.email.unwrap_or_default(),
            username: data.username,
            display_username: data.display_username,
            email_verified: data.email_verified.unwrap_or(false),
            image: data.image,
            role: data.role.unwrap_or_else(|| "user".to_string()),
            banned: false,
            ban_reason: None,
            ban_expires: None,
            two_factor_enabled: false,
            metadata: metadata_json,
            created_at: now.clone(),
            updated_at: now,
        }
    }
}

impl From<better_auth_core::types::UpdateUser> for UpdateUserRow {
    fn from(data: better_auth_core::types::UpdateUser) -> Self {
        let metadata_json = data
            .metadata
            .as_ref()
            .and_then(|v| serde_json::to_string(v).ok());

        let mut row = UpdateUserRow {
            name: data.name.map(Some),
            email: data.email,
            username: data.username.map(Some),
            display_username: data.display_username.map(Some),
            email_verified: data.email_verified,
            image: data.image.map(Some),
            role: data.role,
            banned: data.banned,
            ban_reason: None,
            ban_expires: None,
            two_factor_enabled: data.two_factor_enabled,
            metadata: metadata_json.map(Some),
            updated_at: Some(now_iso()),
        };

        // Handle ban fields: when unbanning, clear reason and expiry
        if let Some(ban_reason) = data.ban_reason {
            row.ban_reason = Some(Some(ban_reason));
        } else if data.banned == Some(false) {
            row.ban_reason = Some(None);
        }

        if let Some(ban_expires) = data.ban_expires {
            row.ban_expires = Some(Some(format_datetime(&ban_expires)));
        } else if data.banned == Some(false) {
            row.ban_expires = Some(None);
        }

        row
    }
}

// ── Session conversions ────────────────────────────────────────────────────

impl From<SessionRow> for Session {
    fn from(row: SessionRow) -> Self {
        Session {
            id: row.id,
            expires_at: parse_datetime(&row.expires_at),
            token: row.token,
            created_at: parse_datetime(&row.created_at),
            updated_at: parse_datetime(&row.updated_at),
            ip_address: row.ip_address,
            user_agent: row.user_agent,
            user_id: row.user_id,
            impersonated_by: row.impersonated_by,
            active_organization_id: row.active_organization_id,
            active: row.active,
        }
    }
}

impl From<CreateSession> for NewSessionRow {
    fn from(data: CreateSession) -> Self {
        let now = now_iso();
        let id = Uuid::new_v4().to_string();
        let token = format!("session_{}", Uuid::new_v4());

        NewSessionRow {
            id,
            user_id: data.user_id,
            token,
            ip_address: data.ip_address,
            user_agent: data.user_agent,
            expires_at: format_datetime(&data.expires_at),
            active_organization_id: data.active_organization_id,
            impersonated_by: data.impersonated_by,
            active: true,
            created_at: now.clone(),
            updated_at: now,
        }
    }
}

// ── Account conversions ──────────────────────────────────────────────────

impl From<AccountRow> for Account {
    fn from(row: AccountRow) -> Self {
        Account {
            id: row.id,
            user_id: row.user_id,
            account_id: row.account_id,
            provider_id: row.provider_id,
            access_token: row.access_token,
            refresh_token: row.refresh_token,
            id_token: row.id_token,
            access_token_expires_at: row.access_token_expires_at.as_deref().map(parse_datetime),
            refresh_token_expires_at: row.refresh_token_expires_at.as_deref().map(parse_datetime),
            scope: row.scope,
            password: row.password,
            created_at: parse_datetime(&row.created_at),
            updated_at: parse_datetime(&row.updated_at),
        }
    }
}

impl From<CreateAccount> for NewAccountRow {
    fn from(data: CreateAccount) -> Self {
        let now = now_iso();
        NewAccountRow {
            id: Uuid::new_v4().to_string(),
            user_id: data.user_id,
            account_id: data.account_id,
            provider_id: data.provider_id,
            access_token: data.access_token,
            refresh_token: data.refresh_token,
            id_token: data.id_token,
            access_token_expires_at: data.access_token_expires_at.as_ref().map(format_datetime),
            refresh_token_expires_at: data.refresh_token_expires_at.as_ref().map(format_datetime),
            scope: data.scope,
            password: data.password,
            created_at: now.clone(),
            updated_at: now,
        }
    }
}

impl From<UpdateAccount> for UpdateAccountRow {
    fn from(data: UpdateAccount) -> Self {
        UpdateAccountRow {
            access_token: data.access_token.map(Some),
            refresh_token: data.refresh_token.map(Some),
            id_token: data.id_token.map(Some),
            access_token_expires_at: data
                .access_token_expires_at
                .map(|dt| Some(format_datetime(&dt))),
            refresh_token_expires_at: data
                .refresh_token_expires_at
                .map(|dt| Some(format_datetime(&dt))),
            scope: data.scope.map(Some),
            password: data.password.map(Some),
            updated_at: Some(now_iso()),
        }
    }
}

// ── Verification conversions ─────────────────────────────────────────────

impl From<VerificationRow> for Verification {
    fn from(row: VerificationRow) -> Self {
        Verification {
            id: row.id,
            identifier: row.identifier,
            value: row.value,
            expires_at: parse_datetime(&row.expires_at),
            created_at: parse_datetime(&row.created_at),
            updated_at: parse_datetime(&row.updated_at),
        }
    }
}

impl From<CreateVerification> for NewVerificationRow {
    fn from(data: CreateVerification) -> Self {
        let now = now_iso();
        NewVerificationRow {
            id: Uuid::new_v4().to_string(),
            identifier: data.identifier,
            value: data.value,
            expires_at: format_datetime(&data.expires_at),
            created_at: now.clone(),
            updated_at: now,
        }
    }
}

// ── Organization conversions ─────────────────────────────────────────────

impl From<OrganizationRow> for Organization {
    fn from(row: OrganizationRow) -> Self {
        let metadata = row
            .metadata
            .as_deref()
            .and_then(|s| serde_json::from_str(s).ok());

        Organization {
            id: row.id,
            name: row.name,
            slug: row.slug,
            logo: row.logo,
            metadata,
            created_at: parse_datetime(&row.created_at),
            updated_at: parse_datetime(&row.updated_at),
        }
    }
}

impl From<CreateOrganization> for NewOrganizationRow {
    fn from(data: CreateOrganization) -> Self {
        let now = now_iso();
        let metadata_json = data
            .metadata
            .as_ref()
            .and_then(|v| serde_json::to_string(v).ok());

        NewOrganizationRow {
            id: data.id.unwrap_or_else(|| Uuid::new_v4().to_string()),
            name: data.name,
            slug: data.slug,
            logo: data.logo,
            metadata: metadata_json,
            created_at: now.clone(),
            updated_at: now,
        }
    }
}

impl From<UpdateOrganization> for UpdateOrganizationRow {
    fn from(data: UpdateOrganization) -> Self {
        let metadata_json = data
            .metadata
            .as_ref()
            .and_then(|v| serde_json::to_string(v).ok());

        UpdateOrganizationRow {
            name: data.name,
            slug: data.slug,
            logo: data.logo.map(Some),
            metadata: metadata_json.map(Some),
            updated_at: Some(now_iso()),
        }
    }
}

// ── Member conversions ───────────────────────────────────────────────────

impl From<MemberRow> for Member {
    fn from(row: MemberRow) -> Self {
        Member {
            id: row.id,
            organization_id: row.organization_id,
            user_id: row.user_id,
            role: row.role,
            created_at: parse_datetime(&row.created_at),
        }
    }
}

impl From<CreateMember> for NewMemberRow {
    fn from(data: CreateMember) -> Self {
        NewMemberRow {
            id: Uuid::new_v4().to_string(),
            organization_id: data.organization_id,
            user_id: data.user_id,
            role: data.role,
            created_at: now_iso(),
        }
    }
}

// ── Invitation conversions ───────────────────────────────────────────────

impl From<InvitationRow> for Invitation {
    fn from(row: InvitationRow) -> Self {
        let status = match row.status.as_str() {
            "accepted" => InvitationStatus::Accepted,
            "rejected" => InvitationStatus::Rejected,
            "canceled" => InvitationStatus::Canceled,
            _ => InvitationStatus::Pending,
        };

        Invitation {
            id: row.id,
            organization_id: row.organization_id,
            email: row.email,
            role: row.role,
            status,
            inviter_id: row.inviter_id,
            expires_at: parse_datetime(&row.expires_at),
            created_at: parse_datetime(&row.created_at),
        }
    }
}

impl From<CreateInvitation> for NewInvitationRow {
    fn from(data: CreateInvitation) -> Self {
        NewInvitationRow {
            id: Uuid::new_v4().to_string(),
            organization_id: data.organization_id,
            email: data.email,
            role: data.role,
            status: "pending".to_string(),
            inviter_id: data.inviter_id,
            expires_at: format_datetime(&data.expires_at),
            created_at: now_iso(),
        }
    }
}

/// Convert an `InvitationStatus` enum to its lowercase string representation.
pub(crate) fn invitation_status_to_string(status: &InvitationStatus) -> String {
    match status {
        InvitationStatus::Pending => "pending".to_string(),
        InvitationStatus::Accepted => "accepted".to_string(),
        InvitationStatus::Rejected => "rejected".to_string(),
        InvitationStatus::Canceled => "canceled".to_string(),
    }
}

// ── TwoFactor conversions ────────────────────────────────────────────────

impl From<TwoFactorRow> for TwoFactor {
    fn from(row: TwoFactorRow) -> Self {
        TwoFactor {
            id: row.id,
            user_id: row.user_id,
            secret: row.secret,
            backup_codes: row.backup_codes,
            created_at: parse_datetime(&row.created_at),
            updated_at: parse_datetime(&row.updated_at),
        }
    }
}

impl From<CreateTwoFactor> for NewTwoFactorRow {
    fn from(data: CreateTwoFactor) -> Self {
        let now = now_iso();
        NewTwoFactorRow {
            id: Uuid::new_v4().to_string(),
            user_id: data.user_id,
            secret: data.secret,
            backup_codes: data.backup_codes,
            created_at: now.clone(),
            updated_at: now,
        }
    }
}

// ── ApiKey conversions ───────────────────────────────────────────────────

impl From<ApiKeyRow> for ApiKey {
    fn from(row: ApiKeyRow) -> Self {
        ApiKey {
            id: row.id,
            user_id: row.user_id,
            name: row.name,
            start: row.start,
            prefix: row.prefix,
            key_hash: row.key,
            enabled: row.enabled,
            rate_limit_enabled: row.rate_limit_enabled,
            rate_limit_time_window: row.rate_limit_time_window,
            rate_limit_max: row.rate_limit_max,
            request_count: row.request_count,
            remaining: row.remaining,
            refill_interval: row.refill_interval,
            refill_amount: row.refill_amount,
            last_refill_at: row.last_refill_at,
            last_request: row.last_request,
            expires_at: row.expires_at,
            created_at: row.created_at,
            updated_at: row.updated_at,
            permissions: row.permissions,
            metadata: row.metadata,
        }
    }
}

impl From<CreateApiKey> for NewApiKeyRow {
    fn from(data: CreateApiKey) -> Self {
        let now = now_iso();
        NewApiKeyRow {
            id: Uuid::new_v4().to_string(),
            user_id: data.user_id,
            name: data.name,
            start: data.start,
            prefix: data.prefix,
            key: data.key_hash,
            enabled: data.enabled,
            rate_limit_enabled: data.rate_limit_enabled,
            rate_limit_time_window: data.rate_limit_time_window,
            rate_limit_max: data.rate_limit_max,
            request_count: Some(0),
            remaining: data.remaining,
            refill_interval: data.refill_interval,
            refill_amount: data.refill_amount,
            last_refill_at: None,
            last_request: None,
            expires_at: data.expires_at,
            created_at: now.clone(),
            updated_at: now,
            permissions: data.permissions,
            metadata: data.metadata,
        }
    }
}

impl From<UpdateApiKey> for UpdateApiKeyRow {
    fn from(data: UpdateApiKey) -> Self {
        UpdateApiKeyRow {
            name: data.name.map(Some),
            enabled: data.enabled,
            remaining: data.remaining.map(Some),
            rate_limit_enabled: data.rate_limit_enabled,
            rate_limit_time_window: data.rate_limit_time_window.map(Some),
            rate_limit_max: data.rate_limit_max.map(Some),
            refill_interval: data.refill_interval.map(Some),
            refill_amount: data.refill_amount.map(Some),
            request_count: data.request_count.map(Some),
            last_refill_at: data.last_refill_at,
            last_request: data.last_request,
            expires_at: data.expires_at,
            permissions: data.permissions.map(Some),
            metadata: data.metadata.map(Some),
            updated_at: Some(now_iso()),
        }
    }
}

// ── Passkey conversions ──────────────────────────────────────────────────

impl From<PasskeyRow> for Passkey {
    fn from(row: PasskeyRow) -> Self {
        #[allow(clippy::cast_sign_loss)]
        let counter = row.counter as u64;

        Passkey {
            id: row.id,
            user_id: row.user_id,
            name: row.name,
            credential_id: row.credential_id,
            public_key: row.public_key,
            counter,
            device_type: row.device_type,
            backed_up: row.backed_up,
            transports: row.transports,
            created_at: parse_datetime(&row.created_at),
        }
    }
}

impl From<CreatePasskey> for NewPasskeyRow {
    fn from(data: CreatePasskey) -> Self {
        #[allow(clippy::cast_possible_wrap)]
        let counter = data.counter as i64;

        NewPasskeyRow {
            id: Uuid::new_v4().to_string(),
            user_id: data.user_id,
            name: data.name,
            credential_id: data.credential_id,
            public_key: data.public_key,
            counter,
            device_type: data.device_type,
            backed_up: data.backed_up,
            transports: data.transports,
            created_at: now_iso(),
        }
    }
}
