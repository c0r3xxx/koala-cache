use std::io::Cursor;

fn extract_gps_coordinate_numeric(
    exif: &exif::Exif,
    coord_tag: exif::Tag,
    ref_tag: exif::Tag,
    negative_ref: char,
) -> Option<f64> {
    if let Some(coord) = exif.get_field(coord_tag, exif::In::PRIMARY) {
        if let exif::Value::Rational(ref vals) = coord.value {
            if vals.len() >= 3 {
                let degrees = vals[0].num as f64 / vals[0].denom as f64;
                let minutes = vals[1].num as f64 / vals[1].denom as f64;
                let seconds = vals[2].num as f64 / vals[2].denom as f64;
                let mut decimal = degrees + minutes / 60.0 + seconds / 3600.0;

                let coord_ref = exif
                    .get_field(ref_tag, exif::In::PRIMARY)
                    .and_then(|f| f.value.display_as(f.tag).to_string().chars().next())
                    .unwrap_or(' ');

                if coord_ref == negative_ref {
                    decimal = -decimal;
                }

                return Some(decimal);
            }
        }
    }
    None
}

pub fn extract_gps_numeric(body: &[u8]) -> (Option<f64>, Option<f64>) {
    let cursor = Cursor::new(body);
    let exif_reader = exif::Reader::new();
    match exif_reader.read_from_container(&mut cursor.clone()) {
        Ok(exif) => {
            let latitude = extract_gps_coordinate_numeric(
                &exif,
                exif::Tag::GPSLatitude,
                exif::Tag::GPSLatitudeRef,
                'S',
            );
            let longitude = extract_gps_coordinate_numeric(
                &exif,
                exif::Tag::GPSLongitude,
                exif::Tag::GPSLongitudeRef,
                'W',
            );
            (latitude, longitude)
        }
        Err(_) => (None, None),
    }
}
