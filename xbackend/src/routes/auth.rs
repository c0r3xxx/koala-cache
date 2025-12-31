use axum::{Json, extract::State, http::StatusCode};
use jsonwebtoken::{EncodingKey, Header, encode};
use serde::{Deserialize, Serialize};
use sqlx::PgPool;
use std::env;

use crate::db::{UserError, validate_user};
use crate::types::UserCredentials;

#[derive(Debug, Serialize, Deserialize)]
struct Claims {
    sub: String,
    exp: usize,
}

#[derive(Serialize)]
pub struct LoginResponse {
    token: String,
}

pub async fn login(
    State(pool): State<PgPool>,
    Json(credentials): Json<UserCredentials>,
) -> Result<Json<LoginResponse>, StatusCode> {
    // Validate the user credentials
    match validate_user(&pool, &credentials).await {
        Ok(user) => {
            // Create JWT claims
            let claims = Claims {
                sub: user.username,
                exp: (chrono::Utc::now() + chrono::Duration::hours(24)).timestamp() as usize,
            };

            // Get JWT secret from environment
            let secret = env::var("JWT_SECRET").unwrap_or_else(|_| "secret".to_string());

            // Encode the JWT token
            match encode(
                &Header::default(),
                &claims,
                &EncodingKey::from_secret(secret.as_bytes()),
            ) {
                Ok(token) => Ok(Json(LoginResponse { token })),
                Err(_) => {
                    tracing::error!("Failed to encode JWT token");
                    Err(StatusCode::INTERNAL_SERVER_ERROR)
                }
            }
        }
        Err(UserError::InvalidCredentials) => {
            tracing::warn!("Login failed - invalid credentials");
            Err(StatusCode::UNAUTHORIZED)
        }
        Err(e) => {
            tracing::error!("Login failed with error: {:?}", e);
            Err(StatusCode::INTERNAL_SERVER_ERROR)
        }
    }
}
