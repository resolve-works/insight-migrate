
SELECT drop_public_schema();

ALTER TABLE private.inodes ADD COLUMN is_public boolean DEFAULT false NOT NULL;

SELECT create_public_schema();
