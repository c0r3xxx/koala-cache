use axum::{Router, extract::DefaultBodyLimit, routing::get, routing::post};

use crate::routes::{auth::login, health::health, upload::upload_image};

pub async fn init(pool: sqlx::PgPool) {
    let app = Router::new()
        .route("/health", get(health))
        .route("/login", post(login))
        .route("/img/{image_name}", post(upload_image))
        .layer(DefaultBodyLimit::max(10 * 1024 * 1024))
        .with_state(pool.clone());

    let listener = tokio::net::TcpListener::bind("0.0.0.0:3000").await.unwrap();

    println!("Server running on http://localhost:3000");

    axum::serve(listener, app).await.unwrap();
}

/* db::create_user(
    &pool,
    &UserCredentials {
        username: "aaron".to_string(),
        password: "0ekX8eIIC6Ft3P8W".to_string(),
    },
)
.await
.unwrap(); */
