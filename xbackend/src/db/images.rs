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
