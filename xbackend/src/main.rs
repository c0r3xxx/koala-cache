mod img;
mod routes;

#[tokio::main]
async fn main() {
    dotenv::dotenv().ok();

    routes::init().await;
}
