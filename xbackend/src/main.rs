mod db;
mod img;
mod routes;
mod types;

#[tokio::main]
async fn main() {
    dotenv::dotenv().ok();

    let pool = db::init().await;

    routes::init(pool).await;
}
