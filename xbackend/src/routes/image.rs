use crate::db::{get_image_hashes_by_owner, insert_image};
use crate::img::{compute_hash, extract_gps_numeric};
use crate::routes::auth::Claims;
use crate::types::Image;
use axum::{Extension, Json, extract::State, http::StatusCode};
use base64::{Engine as _, engine::general_purpose};
use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use sqlx::PgPool;
use std::{env, path::PathBuf};

#[derive(Deserialize)]
pub struct UploadImageRequest {
    pub content: String, // base64 encoded image
    pub extension: String,
    pub image_name: String,
    pub created_at: DateTime<Utc>,
    pub modified_at: DateTime<Utc>,
}

#[derive(Serialize)]
pub struct UploadImageResponse {
    pub hash: String,
}

pub async fn upload_image(
    State(pool): State<PgPool>,
    Extension(claims): Extension<Claims>,
    Json(request): Json<UploadImageRequest>,
) -> Result<(StatusCode, Json<UploadImageResponse>), StatusCode> {
    let storage_path =
        env::var("IMAGE_STORAGE_PATH").map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

    // Decode base64 content
    let body = general_purpose::STANDARD
        .decode(&request.content)
        .map_err(|_| StatusCode::BAD_REQUEST)?;

    let hash = compute_hash(&body);

    let file_name = format!("{}.{}", hash, request.extension);
    let file_path = PathBuf::from(&storage_path).join(&file_name);

    tokio::fs::write(&file_path, &body)
        .await
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

    // Extract GPS coordinates from EXIF data
    let (latitude, longitude) = extract_gps_numeric(&body);

    // Create image record
    let image = Image {
        hash: hash.clone(),
        extension: request.extension,
        owner: claims.sub,
        image_name: Some(request.image_name),
        created_at: request.created_at,
        modified_at: request.modified_at,
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

    Ok((StatusCode::CREATED, Json(UploadImageResponse { hash })))
}

#[derive(Serialize)]
pub struct GetImageHashesResponse {
    pub hashes: Vec<String>,
}

pub async fn get_user_image_hashes(
    State(pool): State<PgPool>,
    Extension(claims): Extension<Claims>,
) -> Result<Json<GetImageHashesResponse>, StatusCode> {
    let hashes = get_image_hashes_by_owner(&pool, &claims.sub)
        .await
        .map_err(|e| {
            eprintln!("Database error: {:?}", e);
            StatusCode::INTERNAL_SERVER_ERROR
        })?;

    Ok(Json(GetImageHashesResponse { hashes }))
}
