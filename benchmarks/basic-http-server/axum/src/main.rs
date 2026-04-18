use std::env;
use std::net::Ipv4Addr;

use axum::Router;
use axum::extract::Path;
use axum::http::header;
use axum::response::IntoResponse;
use axum::routing::{get, post};
use tokio::net::TcpListener;

const PLAINTEXT_BODY: &str = "Hello, World!";
const JSON_BODY: &str = r#"{"message":"Hello, World!"}"#;
const JSON_CONTENT_TYPE: &str = "application/json; charset=utf-8";
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
    response(TEXT_CONTENT_TYPE, PLAINTEXT_BODY)
}

async fn json() -> impl IntoResponse {
    response(JSON_CONTENT_TYPE, JSON_BODY)
}

async fn user(Path(id): Path<String>) -> impl IntoResponse {
    response(
        JSON_CONTENT_TYPE,
        format!(r#"{{"id":"{id}","name":"Benchmark User"}}"#),
    )
}

async fn echo(body: String) -> impl IntoResponse {
    response(JSON_CONTENT_TYPE, body)
}

fn response(content_type: &'static str, body: impl Into<String>) -> impl IntoResponse {
    ([(header::CONTENT_TYPE, content_type)], body.into())
}
