use std::io::Cursor;

fn extract_gps_coordinate(
    exif: &exif::Exif,
    coord_tag: exif::Tag,
    ref_tag: exif::Tag,
    default_ref: char,
) -> Option<String> {
    if let Some(coord) = exif.get_field(coord_tag, exif::In::PRIMARY) {
        if let exif::Value::Rational(ref vals) = coord.value {
            if vals.len() >= 3 {
                let degrees = vals[0].num as f64 / vals[0].denom as f64;
                let minutes = vals[1].num as f64 / vals[1].denom as f64;
                let seconds = vals[2].num as f64 / vals[2].denom as f64;
                let decimal = degrees + minutes / 60.0 + seconds / 3600.0;

                let coord_ref = exif
                    .get_field(ref_tag, exif::In::PRIMARY)
                    .and_then(|f| f.value.display_as(f.tag).to_string().chars().next())
                    .unwrap_or(default_ref);

                return Some(format!("{:.6}°{}", decimal, coord_ref));
            }
        }
    }
    None
}

fn extract_gps_coordinates(exif: &exif::Exif) -> (String, String) {
    let lat_str =
        extract_gps_coordinate(exif, exif::Tag::GPSLatitude, exif::Tag::GPSLatitudeRef, 'N')
            .unwrap_or_else(|| String::from("No GPS"));

    let lon_str = extract_gps_coordinate(
        exif,
        exif::Tag::GPSLongitude,
        exif::Tag::GPSLongitudeRef,
        'E',
    )
    .unwrap_or_else(|| String::from("No GPS"));

    (lat_str, lon_str)
}

pub fn print_upload_info(hash: &str, image_name: &str, body: &[u8]) {
    let cursor = Cursor::new(body);
    let exif_reader = exif::Reader::new();
    match exif_reader.read_from_container(&mut cursor.clone()) {
        Ok(exif) => {
            let (lat_str, lon_str) = extract_gps_coordinates(&exif);
            println!(
                "Hash: {} | Lat: {} | Lon: {} | Image: {}",
                hash, lat_str, lon_str, image_name
            );
        }
        Err(_) => {
            println!("Hash: {} | No GPS data | Image: {}", hash, image_name);
        }
    }
}
