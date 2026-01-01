use axum::{
    Router, extract::DefaultBodyLimit, middleware, routing::delete, routing::get, routing::post,
};

use crate::routes::{
    auth::login, auth_middleware, get_image, get_user_image_hashes, health::health,
    image::delete_image_endpoint, image::upload_image,
};

pub async fn init(pool: sqlx::PgPool) {
    let app = Router::new()
        // Public routes - no authentication required
        .route("/health", get(health))
        .route("/login", post(login))
        // Protected routes - require authentication
        .merge(
            Router::new()
                .route("/img", post(upload_image))
                .route("/img/hashes", get(get_user_image_hashes))
                .route("/img/{hash}", get(get_image))
                .route("/img/{hash}", delete(delete_image_endpoint))
                .route("/health-auth", get(health))
                .layer(middleware::from_fn(auth_middleware))
                .layer(DefaultBodyLimit::max(10 * 1024 * 1024)),
        )
        .with_state(pool.clone());

    let listener = tokio::net::TcpListener::bind("0.0.0.0:3000").await.unwrap();

    println!("Server running on http://localhost:3000");

    axum::serve(listener, app).await.unwrap();
}
