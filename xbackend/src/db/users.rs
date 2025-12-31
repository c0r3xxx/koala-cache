use crate::types::{User, UserCredentials};
use argon2::{
    Algorithm, Argon2, Params, PasswordHash, PasswordHasher, PasswordVerifier, Version,
    password_hash::{SaltString, rand_core::OsRng},
};
use sqlx::PgPool;

#[derive(Debug)]
pub enum UserError {
    #[allow(dead_code)]
    UsernameExists,
    InvalidCredentials,
    #[allow(dead_code)]
    DatabaseError(sqlx::Error),
    #[allow(dead_code)]
    HashError(argon2::password_hash::Error),
    #[allow(dead_code)]
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
#[allow(dead_code)]
pub async fn create_user(pool: &PgPool, credentials: &UserCredentials) -> Result<User, UserError> {
    // Hash the password using Argon2id with custom parameters
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

    // Insert user into database and return the created use
    let result = sqlx::query_as::<_, User>(
        "INSERT INTO users (username, password) VALUES ($1, $2) RETURNING username, password, created_at"
    )
    .bind(&credentials.username)
    .bind(&password_hash)
    .fetch_one(pool)
    .await;

    match result {
        Ok(user) => Ok(user),
        Err(sqlx::Error::Database(db_err)) if db_err.is_unique_violation() => {
            Err(UserError::UsernameExists)
        }
        Err(e) => Err(UserError::DatabaseError(e)),
    }
}

/// Validate a user's credentials
pub async fn validate_user(
    pool: &PgPool,
    credentials: &UserCredentials,
) -> Result<User, UserError> {
    // Retrieve the user from database
    let user: Option<User> =
        sqlx::query_as("SELECT username, password, created_at FROM users WHERE username = $1")
            .bind(&credentials.username)
            .fetch_optional(pool)
            .await?;

    match user {
        Some(user) => {
            // Verify the password against the Argon2id hash
            let parsed_hash = PasswordHash::new(&user.password)?;

            // Configure Argon2 with the same parameters for verification
            let params =
                Params::new(19456, 2, 1, None).map_err(|e| UserError::ParamError(e.to_string()))?;

            let argon2 = Argon2::new(Algorithm::Argon2id, Version::V0x13, params);

            let result = argon2.verify_password(credentials.password.as_bytes(), &parsed_hash);

            match result {
                Ok(_) => Ok(user),
                Err(_) => Err(UserError::InvalidCredentials),
            }
        }
        None => Err(UserError::InvalidCredentials),
    }
}
