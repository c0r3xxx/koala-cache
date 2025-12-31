use crate::db::insert_image;
use crate::img::{compute_hash, extract_gps_numeric};
use crate::routes::auth::Claims;
use crate::types::Image;
use axum::{
    Extension,
    body::Bytes,
    extract::{Path, State},
    http::StatusCode,
};
use chrono::Utc;
use sqlx::PgPool;
use std::{env, path::PathBuf};

pub async fn upload_image(
    State(pool): State<PgPool>,
    Extension(claims): Extension<Claims>,
    Path(image_name): Path<String>,
    body: Bytes,
) -> Result<(StatusCode, String), StatusCode> {
    let storage_path =
        env::var("IMAGE_STORAGE_PATH").map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

    let hash = compute_hash(body.as_ref());

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

    // Extract GPS coordinates from EXIF data
    let (latitude, longitude) = extract_gps_numeric(body.as_ref());

    // Create image record
    let image = Image {
        hash: hash.clone(),
        extension: extension.to_string(),
        owner: claims.sub,
        image_name: Some(image_name),
        created_at: Utc::now(),
        modified_at: Utc::now(),
        longitude,
        latitude,
    };

    // Insert into database
    insert_image(&pool, &image)
        .await
        .map_err(|e: sqlx::Error| {
            // Check for duplicate key constraint violation
            if let sqlx::Error::Database(db_err) = &e {
                if db_err.code().as_deref() == Some("23505") {
                    return StatusCode::CONFLICT;
                }
            }

            eprintln!("Database error: {:?}", e);

            StatusCode::INTERNAL_SERVER_ERROR
        })?;

    Ok((StatusCode::CREATED, hash))
}
