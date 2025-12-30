use axum::{Router, extract::DefaultBodyLimit, routing::get, routing::post};

mod img;

async fn health() -> &'static str {
    "OK"
}

#[tokio::main]
async fn main() {
    dotenv::dotenv().ok();

    let app = Router::new()
        .route("/health", get(health))
        .route("/img/{image_name}", post(img::upload_image))
        .layer(DefaultBodyLimit::max(10 * 1024 * 1024)); // 20MB

    let listener = tokio::net::TcpListener::bind("0.0.0.0:3000").await.unwrap();

    println!("Server running on http://localhost:3000");

    axum::serve(listener, app).await.unwrap();
}
