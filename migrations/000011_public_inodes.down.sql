
SELECT drop_public_schema();

ALTER TABLE private.inodes DROP COLUMN is_public;

SELECT create_public_schema();
