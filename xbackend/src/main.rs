use axum::{
    Router, body::Bytes, extract::DefaultBodyLimit, extract::Path, http::StatusCode, routing::get,
    routing::post,
};
use std::collections::hash_map::DefaultHasher;
use std::env;
use std::hash::{Hash, Hasher};
use std::io::Cursor;
use std::path::PathBuf;

async fn health() -> &'static str {
    "OK"
}

fn extract_gps_coordinates(exif: &exif::Exif) -> (String, String) {
    let mut lat_str = String::from("No GPS");
    let mut lon_str = String::from("No GPS");

    // Get GPS Latitude
    if let Some(lat) = exif.get_field(exif::Tag::GPSLatitude, exif::In::PRIMARY) {
        if let exif::Value::Rational(ref vals) = lat.value {
            if vals.len() >= 3 {
                let degrees = vals[0].num as f64 / vals[0].denom as f64;
                let minutes = vals[1].num as f64 / vals[1].denom as f64;
                let seconds = vals[2].num as f64 / vals[2].denom as f64;
                let decimal = degrees + minutes / 60.0 + seconds / 3600.0;

                let lat_ref = exif
                    .get_field(exif::Tag::GPSLatitudeRef, exif::In::PRIMARY)
                    .and_then(|f| f.value.display_as(f.tag).to_string().chars().next())
                    .unwrap_or('N');

                lat_str = format!("{:.6}°{}", decimal, lat_ref);
            }
        }
    }

    // Get GPS Longitude
    if let Some(lon) = exif.get_field(exif::Tag::GPSLongitude, exif::In::PRIMARY) {
        if let exif::Value::Rational(ref vals) = lon.value {
            if vals.len() >= 3 {
                let degrees = vals[0].num as f64 / vals[0].denom as f64;
                let minutes = vals[1].num as f64 / vals[1].denom as f64;
                let seconds = vals[2].num as f64 / vals[2].denom as f64;
                let decimal = degrees + minutes / 60.0 + seconds / 3600.0;

                let lon_ref = exif
                    .get_field(exif::Tag::GPSLongitudeRef, exif::In::PRIMARY)
                    .and_then(|f| f.value.display_as(f.tag).to_string().chars().next())
                    .unwrap_or('E');

                lon_str = format!("{:.6}°{}", decimal, lon_ref);
            }
        }
    }

    (lat_str, lon_str)
}

fn compute_hash(body: &[u8]) -> u64 {
    let mut hasher = DefaultHasher::new();
    body.hash(&mut hasher);
    hasher.finish()
}

fn print_upload_info(hash: u64, image_name: &str, body: &[u8]) {
    let cursor = Cursor::new(body);
    let exif_reader = exif::Reader::new();
    match exif_reader.read_from_container(&mut cursor.clone()) {
        Ok(exif) => {
            let (lat_str, lon_str) = extract_gps_coordinates(&exif);
            println!(
                "Hash: {:x} | Lat: {} | Lon: {} | Image: {}",
                hash, lat_str, lon_str, image_name
            );
        }
        Err(_) => {
            println!("Hash: {:x} | No GPS data | Image: {}", hash, image_name);
        }
    }
}

async fn upload_image(Path(image_name): Path<String>, body: Bytes) -> Result<String, StatusCode> {
    let storage_path =
        env::var("IMAGE_STORAGE_PATH").map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

    let hash = compute_hash(body.as_ref());
    print_upload_info(hash, &image_name, body.as_ref());

    // Extract extension from image_name, return error if none
    let path = PathBuf::from(&image_name);
    let extension = path
        .extension()
        .and_then(|e| e.to_str())
        .ok_or(StatusCode::BAD_REQUEST)?;

    let file_name = format!("{:x}.{}", hash, extension);
    let file_path = PathBuf::from(&storage_path).join(&file_name);

    tokio::fs::write(&file_path, body.as_ref())
        .await
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

    Ok(format!("{:x}", hash))
}

#[tokio::main]
async fn main() {
    dotenv::dotenv().ok();

    let app = Router::new()
        .route("/health", get(health))
        .route("/img/{image_name}", post(upload_image))
        .layer(DefaultBodyLimit::max(10 * 1024 * 1024)); // 20MB

    let listener = tokio::net::TcpListener::bind("0.0.0.0:3000").await.unwrap();

    println!("Server running on http://localhost:3000");

    axum::serve(listener, app).await.unwrap();
}
