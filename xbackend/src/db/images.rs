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
