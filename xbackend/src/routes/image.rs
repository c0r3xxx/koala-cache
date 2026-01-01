use crate::db::{delete_image, get_image_by_hash, get_image_hashes_by_owner, insert_image};
use crate::img::{compute_hash, extract_gps_numeric};
use crate::routes::auth::Claims;
use crate::types::Image;
use axum::{Extension, Json, extract::Path, extract::State, http::StatusCode};
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
    pub extension: String,
    pub owner: String,
    pub image_name: Option<String>,
    pub longitude: Option<f64>,
    pub latitude: Option<f64>,
    pub created_at: DateTime<Utc>,
    pub modified_at: DateTime<Utc>,
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
    let result = insert_image(&pool, &image).await;

    let response = UploadImageResponse {
        hash: image.hash.clone(),
        extension: image.extension.clone(),
        owner: image.owner.clone(),
        image_name: image.image_name.clone(),
        longitude: image.longitude,
        latitude: image.latitude,
        created_at: image.created_at,
        modified_at: image.modified_at,
    };

    match result {
        Ok(_) => Ok((StatusCode::CREATED, Json(response))),
        Err(e) => {
            // Check for duplicate key constraint violation
            if let sqlx::Error::Database(db_err) = &e {
                if db_err.code().as_deref() == Some("23505") {
                    // Return conflict status but still include the metadata
                    return Ok((StatusCode::CONFLICT, Json(response)));
                }
            }

            eprintln!("Database error: {:?}", e);
            Err(StatusCode::INTERNAL_SERVER_ERROR)
        }
    }
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

#[derive(Serialize)]
pub struct GetImageResponse {
    pub hash: String,
    pub extension: String,
    pub owner: String,
    pub image_name: Option<String>,
    pub longitude: Option<f64>,
    pub latitude: Option<f64>,
    pub created_at: DateTime<Utc>,
    pub modified_at: DateTime<Utc>,
    pub content: String, // base64 encoded image
}

pub async fn get_image(
    State(pool): State<PgPool>,
    Extension(claims): Extension<Claims>,
    Path(hash): Path<String>,
) -> Result<Json<GetImageResponse>, StatusCode> {
    // Get image record from database
    let image = get_image_by_hash(&pool, &hash, &claims.sub)
        .await
        .map_err(|e| {
            eprintln!("Database error: {:?}", e);
            StatusCode::INTERNAL_SERVER_ERROR
        })?
        .ok_or(StatusCode::NOT_FOUND)?;

    // Build file path
    let storage_path =
        env::var("IMAGE_STORAGE_PATH").map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;
    let file_name = format!("{}.{}", image.hash, image.extension);
    let file_path = PathBuf::from(&storage_path).join(&file_name);

    // Read file
    let file_contents = tokio::fs::read(&file_path)
        .await
        .map_err(|_| StatusCode::NOT_FOUND)?;

    // Encode to base64
    let content_base64 = general_purpose::STANDARD.encode(&file_contents);

    Ok(Json(GetImageResponse {
        hash: image.hash,
        extension: image.extension,
        owner: image.owner,
        image_name: image.image_name,
        longitude: image.longitude,
        latitude: image.latitude,
        created_at: image.created_at,
        modified_at: image.modified_at,
        content: content_base64,
    }))
}

#[derive(Serialize)]
pub struct DeleteImageResponse {
    pub success: bool,
    pub message: String,
}

pub async fn delete_image_endpoint(
    State(pool): State<PgPool>,
    Extension(claims): Extension<Claims>,
    Path(hash): Path<String>,
) -> Result<Json<DeleteImageResponse>, StatusCode> {
    // First check if the image exists and belongs to the user
    let image = get_image_by_hash(&pool, &hash, &claims.sub)
        .await
        .map_err(|e| {
            eprintln!("Database error: {:?}", e);
            StatusCode::INTERNAL_SERVER_ERROR
        })?;

    if image.is_none() {
        return Err(StatusCode::NOT_FOUND);
    }

    let image = image.unwrap();

    // Delete from database
    let deleted = delete_image(&pool, &hash, &claims.sub).await.map_err(|e| {
        eprintln!("Database error: {:?}", e);
        StatusCode::INTERNAL_SERVER_ERROR
    })?;

    if !deleted {
        return Err(StatusCode::NOT_FOUND);
    }

    // Delete physical file
    let storage_path =
        env::var("IMAGE_STORAGE_PATH").map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;
    let file_name = format!("{}.{}", image.hash, image.extension);
    let file_path = PathBuf::from(&storage_path).join(&file_name);

    // Attempt to delete the file, but don't fail if it doesn't exist
    if let Err(e) = tokio::fs::remove_file(&file_path).await {
        eprintln!(
            "Warning: Could not delete file {}: {:?}",
            file_path.display(),
            e
        );
    }

    Ok(Json(DeleteImageResponse {
        success: true,
        message: format!("Image {} deleted successfully", hash),
    }))
}
