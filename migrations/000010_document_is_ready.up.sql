

ALTER TABLE private.documents 
ADD COLUMN is_ready boolean GENERATED ALWAYS AS (is_ingested AND is_indexed AND is_embedded) STORED;

CREATE OR REPLACE VIEW documents WITH ( security_invoker=true ) AS
SELECT
    id,
    file_id,
    path,
    from_page,
    to_page,
    name,
    is_ingested,
    is_indexed,
    is_embedded,
    is_deleted,
    is_ready
FROM
    private.documents
WHERE
    private.documents.is_deleted = FALSE;
