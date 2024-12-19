
SELECT drop_public_schema();

ALTER TABLE private.inodes DROP COLUMN is_ready;
ALTER TABLE private.inodes ADD COLUMN is_ready boolean GENERATED ALWAYS AS (
    CASE 
        WHEN type = 'folder' THEN is_indexed
        ELSE (is_indexed AND is_uploaded AND is_ingested AND is_embedded)
    END
) STORED;

SELECT create_public_schema();
