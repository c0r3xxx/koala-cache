use axum::{Json, extract::State, http::StatusCode};
use axum::{extract::Request, http::HeaderMap, middleware::Next, response::Response};
use jsonwebtoken::{DecodingKey, EncodingKey, Header, Validation, decode, encode};
use serde::{Deserialize, Serialize};
use sqlx::PgPool;
use std::env;

use crate::db::{UserError, validate_user};
use crate::types::UserCredentials;

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct Claims {
    pub sub: String,
    pub exp: usize,
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
                Err(_) => Err(StatusCode::INTERNAL_SERVER_ERROR),
            }
        }
        Err(UserError::InvalidCredentials) => Err(StatusCode::UNAUTHORIZED),
        Err(_) => Err(StatusCode::INTERNAL_SERVER_ERROR),
    }
}

/// Middleware function that validates JWT tokens
pub async fn auth_middleware(
    headers: HeaderMap,
    mut req: Request,
    next: Next,
) -> Result<Response, StatusCode> {
    // Extract the Authorization header
    let auth_header = headers
        .get("Authorization")
        .and_then(|h| h.to_str().ok())
        .ok_or(StatusCode::UNAUTHORIZED)?;

    // Check if it starts with "Bearer "
    if !auth_header.starts_with("Bearer ") {
        return Err(StatusCode::UNAUTHORIZED);
    }

    // Extract the token
    let token = auth_header.trim_start_matches("Bearer ");

    // Get JWT secret from environment
    let secret = env::var("JWT_SECRET").unwrap_or_else(|_| "secret".to_string());

    // Decode and validate the token
    let token_data = decode::<Claims>(
        token,
        &DecodingKey::from_secret(secret.as_bytes()),
        &Validation::default(),
    )
    .map_err(|_| StatusCode::UNAUTHORIZED)?;

    // Insert the claims into request extensions so handlers can access them
    req.extensions_mut().insert(token_data.claims);

    // Continue to the next middleware/handler
    Ok(next.run(req).await)
}
