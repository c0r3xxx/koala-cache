use sqlx::{PgPool, postgres::PgPoolOptions};
use std::env;

pub async fn init() -> PgPool {
    let database_url = env::var("DSN").expect("DSN must be set in .env file");

    let pool = PgPoolOptions::new()
        .max_connections(5)
        .connect(&database_url)
        .await
        .expect("Failed to connect to Postgres");

    println!("Database connected successfully!");

    pool
}
