//! `Diesel` table definitions for `better-auth` schema.
//!
//! These `table!` macros define the `SQLite` schema that the adapter operates on.
//! Table names match `Auth*Meta` trait defaults from `better-auth-core`.

diesel::table! {
    /// User accounts table.
    users (id) {
        id -> Text,
        name -> Nullable<Text>,
        email -> Text,
        username -> Nullable<Text>,
        display_username -> Nullable<Text>,
        email_verified -> Bool,
        image -> Nullable<Text>,
        role -> Text,
        banned -> Bool,
        ban_reason -> Nullable<Text>,
        ban_expires -> Nullable<Text>,
        two_factor_enabled -> Bool,
        metadata -> Nullable<Text>,
        created_at -> Text,
        updated_at -> Text,
    }
}

diesel::table! {
    /// Active sessions table.
    sessions (id) {
        id -> Text,
        user_id -> Text,
        token -> Text,
        ip_address -> Nullable<Text>,
        user_agent -> Nullable<Text>,
        expires_at -> Text,
        active_organization_id -> Nullable<Text>,
        impersonated_by -> Nullable<Text>,
        active -> Bool,
        created_at -> Text,
        updated_at -> Text,
    }
}

diesel::table! {
    /// `OAuth` provider account links.
    accounts (id) {
        id -> Text,
        user_id -> Text,
        account_id -> Text,
        provider_id -> Text,
        access_token -> Nullable<Text>,
        refresh_token -> Nullable<Text>,
        id_token -> Nullable<Text>,
        access_token_expires_at -> Nullable<Text>,
        refresh_token_expires_at -> Nullable<Text>,
        scope -> Nullable<Text>,
        password -> Nullable<Text>,
        created_at -> Text,
        updated_at -> Text,
    }
}

diesel::table! {
    /// Email/reset verification tokens.
    verifications (id) {
        id -> Text,
        identifier -> Text,
        value -> Text,
        expires_at -> Text,
        created_at -> Text,
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
        created_at -> Text,
        updated_at -> Text,
    }
}

diesel::table! {
    /// Organization membership.
    member (id) {
        id -> Text,
        user_id -> Text,
        organization_id -> Text,
        role -> Text,
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
        expires_at -> Text,
        created_at -> Text,
    }
}

diesel::table! {
    /// Two-factor authentication secrets.
    two_factor (id) {
        id -> Text,
        user_id -> Text,
        secret -> Text,
        backup_codes -> Nullable<Text>,
        created_at -> Text,
        updated_at -> Text,
    }
}

diesel::table! {
    /// API keys for programmatic access.
    api_keys (id) {
        id -> Text,
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
        expires_at -> Nullable<Text>,
        created_at -> Text,
        updated_at -> Text,
        permissions -> Nullable<Text>,
        metadata -> Nullable<Text>,
    }
}

diesel::table! {
    /// `WebAuthn` passkey credentials.
    passkeys (id) {
        id -> Text,
        user_id -> Text,
        name -> Text,
        credential_id -> Text,
        public_key -> Text,
        counter -> BigInt,
        device_type -> Text,
        backed_up -> Bool,
        transports -> Nullable<Text>,
        created_at -> Text,
    }
}

diesel::joinable!(sessions -> users (user_id));
diesel::joinable!(accounts -> users (user_id));
diesel::joinable!(two_factor -> users (user_id));
diesel::joinable!(api_keys -> users (user_id));
diesel::joinable!(passkeys -> users (user_id));
diesel::joinable!(member -> users (user_id));
diesel::joinable!(member -> organization (organization_id));
diesel::joinable!(invitation -> organization (organization_id));

diesel::allow_tables_to_appear_in_same_query!(
    users,
    sessions,
    accounts,
    verifications,
    organization,
    member,
    invitation,
    two_factor,
    api_keys,
    passkeys,
);
