
DROP VIEW files;

ALTER TABLE private.files 
DROP COLUMN status;

DROP TYPE file_status;

CREATE OR REPLACE VIEW files WITH ( security_invoker=true ) AS
SELECT
    id,
    owner_id,
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

DROP FUNCTION document(pages);
DROP VIEW documents;

ALTER TABLE private.documents 
DROP COLUMN status;

ALTER TABLE private.documents 
ADD COLUMN is_ingested boolean NOT NULL DEFAULT FALSE;

ALTER TABLE private.documents 
ADD COLUMN is_indexed boolean NOT NULL DEFAULT FALSE;

ALTER TABLE private.documents 
ADD COLUMN is_embedded boolean NOT NULL DEFAULT FALSE;

UPDATE private.documents SET is_ingested=TRUE, is_indexed=TRUE, is_embedded=TRUE;

DROP TYPE document_status;

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
    is_deleted
FROM
    private.documents
WHERE
    private.documents.is_deleted = FALSE;

GRANT ALL ON TABLE documents TO insight_worker;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE documents TO external_user;

CREATE OR REPLACE FUNCTION document (pages)
    RETURNS SETOF documents ROWS 1
    AS $$
    SELECT
        *
    FROM
        documents
    WHERE
        file_id = $1.file_id
        AND from_page <= $1.INDEX
        AND to_page > $1.INDEX
$$
LANGUAGE SQL;

GRANT ALL ON FUNCTION document(pages) TO external_user;

DROP VIEW prompts;

ALTER TABLE private.prompts
DROP COLUMN status;

DROP TYPE prompt_status;

CREATE OR REPLACE VIEW prompts WITH ( security_invoker=true ) AS
SELECT
    *
FROM
    private.prompts;

GRANT SELECT,INSERT ON TABLE prompts TO external_user;

