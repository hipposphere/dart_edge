//! Basic Axum application using DieselSqliteAdapter.
//!
//! Run with: `cargo run --example axum_basic`

// TODO: Uncomment once all trait implementations are complete.
//
// use axum::{Router, Json, response::IntoResponse, routing::get};
// use better_auth::{AuthBuilder, AuthConfig};
// use better_auth::handlers::{AxumIntegration, CurrentSession, OptionalSession};
// use better_auth::plugins::{
//     EmailPasswordPlugin,
//     SessionManagementPlugin,
//     ApiKeyPlugin,
// };
// use better_auth_diesel_sqlite::DieselSqliteAdapter;
// use std::sync::Arc;
//
// #[tokio::main]
// async fn main() -> Result<(), Box<dyn std::error::Error>> {
//     tracing_subscriber::init();
//
//     let adapter = DieselSqliteAdapter::new("sqlite://example.db").await?;
//
//     let config = AuthConfig::new("example-secret-key-change-in-production!!")
//         .base_url("http://localhost:8080");
//
//     let auth = Arc::new(
//         AuthBuilder::new(config)
//             .database(adapter)
//             .plugin(EmailPasswordPlugin::new().enable_signup(true))
//             .plugin(SessionManagementPlugin::new())
//             .plugin(ApiKeyPlugin::new().prefix("sk_").key_length(32))
//             .build()
//             .await?
//     );
//
//     let auth_router = auth.clone().axum_router();
//
//     let app = Router::new()
//         .route("/api/profile", get(get_profile))
//         .route("/api/public", get(public_route))
//         .nest("/auth", auth_router)
//         .with_state(auth);
//
//     println!("Server running at http://localhost:8080");
//     let listener = tokio::net::TcpListener::bind("0.0.0.0:8080").await?;
//     axum::serve(listener, app).await?;
//
//     Ok(())
// }
//
// async fn get_profile(
//     session: CurrentSession<DieselSqliteAdapter>,
// ) -> impl IntoResponse {
//     Json(serde_json::json!({
//         "id": session.user.id(),
//         "email": session.user.email(),
//         "name": session.user.name(),
//     }))
// }
//
// async fn public_route(
//     session: OptionalSession<DieselSqliteAdapter>,
// ) -> impl IntoResponse {
//     let user = session.0.map(|s| s.user.id().to_string());
//     Json(serde_json::json!({
//         "authenticated": user.is_some(),
//         "user_id": user,
//     }))
// }

fn main() {
    println!("Example placeholder — uncomment when trait implementations are complete.");
}
