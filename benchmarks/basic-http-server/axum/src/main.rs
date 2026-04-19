use std::env;
use std::net::Ipv4Addr;

use axum::Json;
use axum::Router;
use axum::body::Bytes;
use axum::extract::Path;
use axum::http::header;
use axum::response::IntoResponse;
use axum::routing::{get, post};
use serde_json::{Value, json};
use tokio::net::TcpListener;

const PLAINTEXT_BODY: &str = "Hello, World!";
const TEXT_CONTENT_TYPE: &str = "text/plain; charset=utf-8";

#[tokio::main(flavor = "multi_thread")]
async fn main() {
    let port = parse_port(env::args().skip(1)).unwrap_or(8080);

    let app = Router::new()
        .route("/plaintext", get(plaintext))
        .route("/json", get(json))
        .route("/users/{id}", get(user))
        .route("/echo", post(echo));

    let listener = TcpListener::bind((Ipv4Addr::LOCALHOST, port))
        .await
        .expect("bind axum benchmark listener");

    axum::serve(listener, app)
        .await
        .expect("serve axum benchmark");
}

fn parse_port(arguments: impl Iterator<Item = String>) -> Option<u16> {
    for argument in arguments {
        if let Some(port) = argument.strip_prefix("--port=") {
            return port.parse().ok();
        }
    }

    None
}

async fn plaintext() -> impl IntoResponse {
    ([(header::CONTENT_TYPE, TEXT_CONTENT_TYPE)], PLAINTEXT_BODY)
}

async fn json() -> Json<Value> {
    Json(json!({ "message": "Hello, World!" }))
}

async fn user(Path(id): Path<String>) -> Json<Value> {
    Json(json!({ "id": id, "name": "Benchmark User" }))
}

async fn echo(body: Bytes) -> Json<Value> {
    let payload = if body.is_empty() {
        json!({ "message": "Echo payload", "count": 1, "enabled": true })
    } else {
        serde_json::from_slice::<Value>(&body).expect("parse benchmark echo body")
    };

    Json(payload)
}
