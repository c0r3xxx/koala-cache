mod db;
mod img;
mod routes;

#[tokio::main]
async fn main() {
    dotenv::dotenv().ok();

    let db_pool = db::init().await;
    println!("Database connected successfully!");

    routes::init().await;
}
