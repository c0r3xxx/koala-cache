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
