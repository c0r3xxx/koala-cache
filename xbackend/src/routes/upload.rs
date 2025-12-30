use crate::img::{compute_hash, print_upload_info};
use axum::{body::Bytes, extract::Path, http::StatusCode};
use std::{env, path::PathBuf};

pub async fn upload_image(
    Path(image_name): Path<String>,
    body: Bytes,
) -> Result<String, StatusCode> {
    let storage_path =
        env::var("IMAGE_STORAGE_PATH").map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

    let hash = compute_hash(body.as_ref());
    print_upload_info(&hash, &image_name, body.as_ref());

    // Extract extension from image_name, return error if none
    let path = PathBuf::from(&image_name);
    let extension = path
        .extension()
        .and_then(|e| e.to_str())
        .ok_or(StatusCode::BAD_REQUEST)?;

    let file_name = format!("{}.{}", hash, extension);
    let file_path = PathBuf::from(&storage_path).join(&file_name);

    tokio::fs::write(&file_path, body.as_ref())
        .await
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

    Ok(hash)
}
