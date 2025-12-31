use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use sqlx::FromRow;

#[derive(Debug, Serialize, Deserialize)]
pub struct UserCredentials {
    pub username: String,
    pub password: String,
}

#[derive(Debug, FromRow, Serialize)]
pub struct User {
    pub username: String,
    #[serde(skip_serializing)]
    pub password: String,
    pub created_at: Option<chrono::NaiveDateTime>,
}

#[derive(Debug, Clone)]
pub struct Image {
    pub hash: String,
    pub extension: String,
    pub owner: String,
    pub image_name: Option<String>,
    pub created_at: DateTime<Utc>,
    pub modified_at: DateTime<Utc>,
    pub longitude: Option<f64>,
    pub latitude: Option<f64>,
}
