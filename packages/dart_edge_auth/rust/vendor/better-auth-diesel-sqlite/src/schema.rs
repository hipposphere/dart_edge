//! `Diesel` table definitions for `better-auth` schema.
//!
//! These `table!` macros define the `SQLite` schema that the adapter operates on.
//! Table names match `Auth*Meta` trait defaults from `better-auth-core`.

diesel::table! {
    /// User account table.
    user (id) {
        id -> Text,
        name -> Nullable<Text>,
        email -> Text,
        username -> Nullable<Text>,
        #[sql_name = "displayUsername"]
        display_username -> Nullable<Text>,
        #[sql_name = "emailVerified"]
        email_verified -> Bool,
        image -> Nullable<Text>,
        role -> Text,
        banned -> Bool,
        #[sql_name = "banReason"]
        ban_reason -> Nullable<Text>,
        #[sql_name = "banExpires"]
        ban_expires -> Nullable<Text>,
        #[sql_name = "twoFactorEnabled"]
        two_factor_enabled -> Bool,
        metadata -> Nullable<Text>,
        #[sql_name = "createdAt"]
        created_at -> Text,
        #[sql_name = "updatedAt"]
        updated_at -> Text,
    }
}

diesel::table! {
    /// Active session table.
    session (id) {
        id -> Text,
        #[sql_name = "userId"]
        user_id -> Text,
        token -> Text,
        #[sql_name = "ipAddress"]
        ip_address -> Nullable<Text>,
        #[sql_name = "userAgent"]
        user_agent -> Nullable<Text>,
        #[sql_name = "expiresAt"]
        expires_at -> Text,
        #[sql_name = "activeOrganizationId"]
        active_organization_id -> Nullable<Text>,
        #[sql_name = "impersonatedBy"]
        impersonated_by -> Nullable<Text>,
        active -> Bool,
        #[sql_name = "createdAt"]
        created_at -> Text,
        #[sql_name = "updatedAt"]
        updated_at -> Text,
    }
}

diesel::table! {
    /// `OAuth` provider account links.
    account (id) {
        id -> Text,
        #[sql_name = "userId"]
        user_id -> Text,
        #[sql_name = "accountId"]
        account_id -> Text,
        #[sql_name = "providerId"]
        provider_id -> Text,
        #[sql_name = "accessToken"]
        access_token -> Nullable<Text>,
        #[sql_name = "refreshToken"]
        refresh_token -> Nullable<Text>,
        #[sql_name = "idToken"]
        id_token -> Nullable<Text>,
        #[sql_name = "accessTokenExpiresAt"]
        access_token_expires_at -> Nullable<Text>,
        #[sql_name = "refreshTokenExpiresAt"]
        refresh_token_expires_at -> Nullable<Text>,
        scope -> Nullable<Text>,
        password -> Nullable<Text>,
        #[sql_name = "createdAt"]
        created_at -> Text,
        #[sql_name = "updatedAt"]
        updated_at -> Text,
    }
}

diesel::table! {
    /// Email/reset verification tokens.
    verification (id) {
        id -> Text,
        identifier -> Text,
        value -> Text,
        #[sql_name = "expiresAt"]
        expires_at -> Text,
        #[sql_name = "createdAt"]
        created_at -> Text,
        #[sql_name = "updatedAt"]
        updated_at -> Text,
    }
}

diesel::table! {
    /// Multi-tenant organizations.
    organization (id) {
        id -> Text,
        name -> Text,
        slug -> Text,
        logo -> Nullable<Text>,
        metadata -> Nullable<Text>,
        #[sql_name = "createdAt"]
        created_at -> Text,
        #[sql_name = "updatedAt"]
        updated_at -> Text,
    }
}

diesel::table! {
    /// Organization membership.
    member (id) {
        id -> Text,
        #[sql_name = "userId"]
        user_id -> Text,
        organization_id -> Text,
        role -> Text,
        #[sql_name = "createdAt"]
        created_at -> Text,
    }
}

diesel::table! {
    /// Organization invitations.
    invitation (id) {
        id -> Text,
        organization_id -> Text,
        email -> Text,
        role -> Text,
        status -> Text,
        inviter_id -> Text,
        #[sql_name = "expiresAt"]
        expires_at -> Text,
        #[sql_name = "createdAt"]
        created_at -> Text,
    }
}

diesel::table! {
    /// Two-factor authentication secrets.
    two_factor (id) {
        id -> Text,
        #[sql_name = "userId"]
        user_id -> Text,
        secret -> Text,
        backup_codes -> Nullable<Text>,
        #[sql_name = "createdAt"]
        created_at -> Text,
        #[sql_name = "updatedAt"]
        updated_at -> Text,
    }
}

diesel::table! {
    /// API keys for programmatic access.
    api_keys (id) {
        id -> Text,
        #[sql_name = "userId"]
        user_id -> Text,
        name -> Nullable<Text>,
        start -> Nullable<Text>,
        prefix -> Nullable<Text>,
        /// Column is named `key` in SQL (quoted to avoid reserved word conflict).
        key -> Text,
        enabled -> Bool,
        rate_limit_enabled -> Bool,
        rate_limit_time_window -> Nullable<BigInt>,
        rate_limit_max -> Nullable<BigInt>,
        request_count -> Nullable<BigInt>,
        remaining -> Nullable<BigInt>,
        refill_interval -> Nullable<BigInt>,
        refill_amount -> Nullable<BigInt>,
        last_refill_at -> Nullable<Text>,
        last_request -> Nullable<Text>,
        #[sql_name = "expiresAt"]
        expires_at -> Nullable<Text>,
        #[sql_name = "createdAt"]
        created_at -> Text,
        #[sql_name = "updatedAt"]
        updated_at -> Text,
        permissions -> Nullable<Text>,
        metadata -> Nullable<Text>,
    }
}

diesel::table! {
    /// `WebAuthn` passkey credentials.
    passkeys (id) {
        id -> Text,
        #[sql_name = "userId"]
        user_id -> Text,
        name -> Text,
        credential_id -> Text,
        public_key -> Text,
        counter -> BigInt,
        device_type -> Text,
        backed_up -> Bool,
        transports -> Nullable<Text>,
        #[sql_name = "createdAt"]
        created_at -> Text,
    }
}

diesel::joinable!(session -> user (user_id));
diesel::joinable!(account -> user (user_id));
diesel::joinable!(two_factor -> user (user_id));
diesel::joinable!(api_keys -> user (user_id));
diesel::joinable!(passkeys -> user (user_id));
diesel::joinable!(member -> user (user_id));
diesel::joinable!(member -> organization (organization_id));
diesel::joinable!(invitation -> organization (organization_id));

diesel::allow_tables_to_appear_in_same_query!(
    user,
    session,
    account,
    verification,
    organization,
    member,
    invitation,
    two_factor,
    api_keys,
    passkeys,
);
