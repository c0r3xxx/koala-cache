mod db;
mod img;
mod routes;
mod types;

#[tokio::main]
async fn main() {
    dotenv::dotenv().ok();

    // Initialize tracing subscriber for logging
    tracing_subscriber::fmt()
        .with_target(false)
        .with_thread_ids(true)
        .with_level(true)
        .init();

    let pool = db::init().await;

    routes::init(pool).await;
}
