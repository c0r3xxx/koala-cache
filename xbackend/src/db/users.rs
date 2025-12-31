use crate::types::{User, UserCredentials};
use argon2::{
    Algorithm, Argon2, Params, PasswordHash, PasswordHasher, PasswordVerifier, Version,
    password_hash::{SaltString, rand_core::OsRng},
};
use sqlx::PgPool;
use std::time::Instant;

#[derive(Debug)]
pub enum UserError {
    UsernameExists,
    InvalidCredentials,
    DatabaseError(sqlx::Error),
    HashError(argon2::password_hash::Error),
    ParamError(String),
}

impl From<sqlx::Error> for UserError {
    fn from(err: sqlx::Error) -> Self {
        UserError::DatabaseError(err)
    }
}

impl From<argon2::password_hash::Error> for UserError {
    fn from(err: argon2::password_hash::Error) -> Self {
        UserError::HashError(err)
    }
}

/// Create a new user with a hashed password
pub async fn create_user(pool: &PgPool, credentials: &UserCredentials) -> Result<User, UserError> {
    let start = Instant::now();
    tracing::info!("Creating user: {}", credentials.username);

    // Hash the password using Argon2id with custom parameters
    let hash_start = Instant::now();
    let salt = SaltString::generate(&mut OsRng);

    let params =
        Params::new(65536, 2, 2, None).map_err(|e| UserError::ParamError(e.to_string()))?;

    let argon2 = Argon2::new(
        Algorithm::Argon2id, // Use Argon2id variant (recommended)
        Version::V0x13,      // Use version 1.3
        params,
    );

    let password_hash = argon2
        .hash_password(credentials.password.as_bytes(), &salt)?
        .to_string();

    let hash_duration = hash_start.elapsed();
    tracing::debug!("Password hashing took: {:?}", hash_duration);

    // Insert user into database and return the created user
    let db_start = Instant::now();
    let result = sqlx::query_as::<_, User>(
        "INSERT INTO users (username, password) VALUES ($1, $2) RETURNING username, password, created_at"
    )
    .bind(&credentials.username)
    .bind(&password_hash)
    .fetch_one(pool)
    .await;

    let db_duration = db_start.elapsed();
    tracing::debug!("Database insert took: {:?}", db_duration);

    let total_duration = start.elapsed();

    match result {
        Ok(user) => {
            tracing::info!(
                "User created successfully: {} (total time: {:?})",
                credentials.username,
                total_duration
            );
            Ok(user)
        }
        Err(sqlx::Error::Database(db_err)) if db_err.is_unique_violation() => {
            tracing::warn!(
                "User creation failed - username already exists: {} (total time: {:?})",
                credentials.username,
                total_duration
            );
            Err(UserError::UsernameExists)
        }
        Err(e) => {
            tracing::error!(
                "User creation failed with database error: {} (total time: {:?})",
                e,
                total_duration
            );
            Err(UserError::DatabaseError(e))
        }
    }
}

/// Validate a user's credentials
pub async fn validate_user(
    pool: &PgPool,
    credentials: &UserCredentials,
) -> Result<User, UserError> {
    let start = Instant::now();
    tracing::info!("Validating user: {}", credentials.username);

    // Retrieve the user from database
    let db_start = Instant::now();
    let user: Option<User> =
        sqlx::query_as("SELECT username, password, created_at FROM users WHERE username = $1")
            .bind(&credentials.username)
            .fetch_optional(pool)
            .await?;

    let db_duration = db_start.elapsed();
    tracing::debug!("Database query took: {:?}", db_duration);

    match user {
        Some(user) => {
            // Verify the password against the Argon2id hash
            let verify_start = Instant::now();
            let parsed_hash = PasswordHash::new(&user.password)?;

            // Configure Argon2 with the same parameters for verification
            let params =
                Params::new(19456, 2, 1, None).map_err(|e| UserError::ParamError(e.to_string()))?;

            let argon2 = Argon2::new(Algorithm::Argon2id, Version::V0x13, params);

            let result = argon2.verify_password(credentials.password.as_bytes(), &parsed_hash);
            let verify_duration = verify_start.elapsed();
            tracing::debug!("Password verification took: {:?}", verify_duration);

            let total_duration = start.elapsed();

            match result {
                Ok(_) => {
                    tracing::info!(
                        "User validation successful: {} (total time: {:?})",
                        credentials.username,
                        total_duration
                    );
                    Ok(user)
                }
                Err(_) => {
                    tracing::warn!(
                        "User validation failed - invalid password: {} (total time: {:?})",
                        credentials.username,
                        total_duration
                    );
                    Err(UserError::InvalidCredentials)
                }
            }
        }
        None => {
            let total_duration = start.elapsed();
            tracing::warn!(
                "User validation failed - user not found: {} (total time: {:?})",
                credentials.username,
                total_duration
            );
            Err(UserError::InvalidCredentials)
        }
    }
}
