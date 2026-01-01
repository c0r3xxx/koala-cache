use crate::types::Image;
use sqlx::PgPool;

pub async fn insert_image(pool: &PgPool, image: &Image) -> Result<(), sqlx::Error> {
    sqlx::query!(
        r#"
        INSERT INTO images (hash, extension, owner, image_name, longitude, latitude, created_at, modified_at)
        VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
        "#,
        image.hash,
        image.extension,
        image.owner,
        image.image_name,
        image.longitude,
        image.latitude,
        image.created_at.naive_utc(),
        image.modified_at.naive_utc()
    )
    .execute(pool)
    .await?;

    Ok(())
}

pub async fn get_image_hashes_by_owner(
    pool: &PgPool,
    owner: &str,
) -> Result<Vec<String>, sqlx::Error> {
    let records = sqlx::query!(
        r#"
        SELECT hash
        FROM images
        WHERE owner = $1
        ORDER BY created_at DESC
        "#,
        owner
    )
    .fetch_all(pool)
    .await?;

    Ok(records.into_iter().map(|r| r.hash).collect())
}

pub async fn get_image_by_hash(
    pool: &PgPool,
    hash: &str,
    owner: &str,
) -> Result<Option<Image>, sqlx::Error> {
    let record = sqlx::query!(
        r#"
        SELECT hash, extension, owner, image_name, longitude, latitude, created_at, modified_at
        FROM images
        WHERE hash = $1 AND owner = $2
        "#,
        hash,
        owner
    )
    .fetch_optional(pool)
    .await?;

    Ok(record.map(|r| Image {
        hash: r.hash,
        extension: r.extension.unwrap_or_else(|| "jpg".to_string()),
        owner: r.owner.unwrap_or_default(),
        image_name: r.image_name,
        longitude: r.longitude,
        latitude: r.latitude,
        created_at: chrono::DateTime::from_naive_utc_and_offset(
            r.created_at
                .unwrap_or_else(|| chrono::Utc::now().naive_utc()),
            chrono::Utc,
        ),
        modified_at: chrono::DateTime::from_naive_utc_and_offset(
            r.modified_at
                .unwrap_or_else(|| chrono::Utc::now().naive_utc()),
            chrono::Utc,
        ),
    }))
}

pub async fn delete_image(pool: &PgPool, hash: &str, owner: &str) -> Result<bool, sqlx::Error> {
    let result = sqlx::query!(
        r#"
        DELETE FROM images
        WHERE hash = $1 AND owner = $2
        "#,
        hash,
        owner
    )
    .execute(pool)
    .await?;

    Ok(result.rows_affected() > 0)
}
