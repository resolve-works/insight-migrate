
ALTER TABLE private.files 
ADD COLUMN folder_id uuid;

ALTER TABLE private.files
ADD CONSTRAINT files_folder_id_fkey
FOREIGN KEY (folder_id) REFERENCES private.folders(id) ON DELETE CASCADE;

DROP VIEW files;

CREATE OR REPLACE VIEW files WITH ( security_invoker=true ) AS
SELECT
    id,
    owner_id,
    folder_id,
    name,
    path,
    number_of_pages,
    is_uploaded,
    created_at,
    updated_at,
    is_deleted
FROM
    private.files
WHERE
    private.files.is_deleted = FALSE;

GRANT ALL ON TABLE files TO insight_worker;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE files TO external_user;
