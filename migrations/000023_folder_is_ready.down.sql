
SELECT drop_public_schema();

ALTER TABLE private.inodes DROP COLUMN is_ready;
ALTER TABLE private.inodes ADD COLUMN is_ready boolean GENERATED ALWAYS AS (
    (is_indexed AND is_uploaded AND is_ingested AND is_embedded)
) STORED;

SELECT create_public_schema();
