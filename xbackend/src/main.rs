use axum::{Router, body::Bytes, http::StatusCode, routing::post};
use std::collections::hash_map::DefaultHasher;
use std::env;
use std::hash::{Hash, Hasher};
use std::path::PathBuf;

async fn upload_image(body: Bytes) -> Result<String, StatusCode> {
    let storage_path =
        env::var("IMAGE_STORAGE_PATH").map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

    // Use standard library DefaultHasher (SipHash-1-3) on the image content
    let mut hasher = DefaultHasher::new();
    body.as_ref().hash(&mut hasher);
    let hash = hasher.finish();
    let file_name = format!("{:x}.jpg", hash);
    let file_path = PathBuf::from(&storage_path).join(&file_name);

    tokio::fs::create_dir_all(&storage_path)
        .await
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

    tokio::fs::write(&file_path, body.as_ref())
        .await
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

    Ok(format!("Image saved: {}", file_name))
}

#[tokio::main]
async fn main() {
    dotenv::dotenv().ok();

    let app = Router::new().route("/img", post(upload_image));

    let listener = tokio::net::TcpListener::bind("0.0.0.0:3000").await.unwrap();

    println!("Server running on http://localhost:3000");

    axum::serve(listener, app).await.unwrap();
}
