
-- Add inode table for files tree
CREATE TABLE IF NOT EXISTS private.inodes (
    id uuid DEFAULT gen_random_uuid (),
    parent_id uuid,
    owner_id uuid NOT NULL,
    name text NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    is_deleted boolean NOT NULL DEFAULT FALSE,
    file_id uuid,
    PRIMARY KEY (id),
    FOREIGN KEY (file_id) REFERENCES private.files (id) ON DELETE CASCADE,
    FOREIGN KEY (parent_id) REFERENCES private.inodes (id) ON DELETE CASCADE
);

CREATE OR REPLACE VIEW inodes WITH ( security_invoker=true ) AS
    SELECT * FROM private.inodes WHERE is_deleted = FALSE;

-- Merge document and file tables
ALTER TABLE private.files ADD COLUMN is_ingested boolean NOT NULL DEFAULT FALSE;
ALTER TABLE private.files ADD COLUMN is_indexed boolean NOT NULL DEFAULT FALSE;
ALTER TABLE private.files ADD COLUMN is_embedded boolean NOT NULL DEFAULT FALSE;
ALTER TABLE private.files ADD COLUMN is_ready boolean GENERATED ALWAYS 
    AS (is_uploaded AND is_ingested AND is_indexed AND is_embedded) STORED;

ALTER TABLE private.files ADD COLUMN from_page integer NOT NULL DEFAULT 0;
ALTER TABLE private.files ADD COLUMN to_page integer;

-- Move document table functions to files
CREATE OR REPLACE FUNCTION mark_file_reingest ()
    RETURNS TRIGGER
    AS $$
BEGIN
    IF NEW.from_page != OLD.from_page OR (NEW.to_page != OLD.to_page AND OLD.to_page != NULL) THEN
        NEW.is_ingested = false;
        NEW.is_indexed = false;
        NEW.is_embedded = false;
    END IF;

    RETURN NEW;
END;
$$
LANGUAGE PLPGSQL;

CREATE OR REPLACE TRIGGER mark_file_reingest
    BEFORE UPDATE ON private.files
    FOR EACH ROW
    EXECUTE FUNCTION mark_file_reingest ();

CREATE OR REPLACE FUNCTION mark_file_reindex ()
    RETURNS TRIGGER
    AS $$
BEGIN
    IF NEW.name != OLD.name THEN
        NEW.is_indexed = false;
    END IF;

    RETURN NEW;
END;
$$
LANGUAGE PLPGSQL;

CREATE OR REPLACE TRIGGER mark_file_reindex
    BEFORE UPDATE ON private.documents
    FOR EACH ROW
    EXECUTE FUNCTION mark_file_reindex ();

DROP VIEW files;

ALTER TABLE private.files DROP COLUMN folder_id;
ALTER TABLE private.files DROP COLUMN number_of_pages;
ALTER TABLE private.files DROP COLUMN path;
ALTER TABLE private.files DROP COLUMN created_at;
ALTER TABLE private.files DROP COLUMN updated_at;
ALTER TABLE private.files DROP COLUMN is_deleted;
ALTER TABLE private.files DROP COLUMN name;
ALTER TABLE private.files DROP COLUMN dirname;

CREATE OR REPLACE VIEW files WITH ( security_invoker=true ) AS
    SELECT * FROM private.files;

DROP TRIGGER IF EXISTS set_file_owner ON private.files;
DROP TRIGGER IF EXISTS set_file_path ON private.files;
DROP TRIGGER IF EXISTS set_file_updated_at ON private.files;
DROP TRIGGER IF EXISTS set_document_path ON private.documents;
DROP TRIGGER IF EXISTS reset_document_name ON private.documents;
DROP TRIGGER IF EXISTS reset_document_pagerange ON private.documents;

DROP FUNCTION IF EXISTS set_file_owner;
DROP FUNCTION IF EXISTS set_file_path;
DROP FUNCTION IF EXISTS reset_document_name;
DROP FUNCTION IF EXISTS reset_document_pagerange;
DROP FUNCTION IF EXISTS set_document_path;
DROP FUNCTION IF EXISTS document(pages);

DROP VIEW documents;
DROP TABLE private.documents;

DROP FUNCTION children (folders);
DROP FUNCTION parents (folders);
DROP VIEW folders;
DROP TABLE private.folders;

-- Add security and triggers
CREATE OR REPLACE TRIGGER set_inode_owner
    BEFORE INSERT ON private.inodes
    FOR EACH ROW
    EXECUTE FUNCTION set_owner ();

CREATE OR REPLACE TRIGGER set_inodes_updated_at
    BEFORE UPDATE ON private.inodes
    FOR EACH ROW
    EXECUTE FUNCTION set_updated_at ();

ALTER TABLE private.inodes ENABLE ROW LEVEL SECURITY;

GRANT SELECT, INSERT, UPDATE, DELETE ON private.inodes TO external_user;

CREATE POLICY inodes_external_user ON private.inodes 
    USING (owner_id = uuid(current_setting('request.jwt.claims', true)::json->>'sub'))
    WITH CHECK (owner_id = uuid(current_setting('request.jwt.claims', true)::json->>'sub'));

CREATE POLICY inodes_insight_worker ON private.inodes TO insight_worker 
    USING (true)
    WITH CHECK (true);

-- Inode functions
CREATE OR REPLACE FUNCTION storage_path (inodes)
    RETURNS text
    AS $$
BEGIN
    WITH RECURSIVE hierarchy AS (
        SELECT id, parent_id, 1 AS depth FROM inodes WHERE id = $1.id

        UNION ALL

        SELECT inodes.id, inodes.parent_id, hierarchy.depth + 1 FROM inodes
            JOIN hierarchy ON inodes.id = hierarchy.parent_id
    )
    SELECT string_agg(CAST(id AS TEXT), '/' ORDER BY depth DESC) FROM hierarchy;
END
$$
LANGUAGE PLPGSQL;

GRANT EXECUTE ON FUNCTION storage_path TO external_user;

CREATE OR REPLACE FUNCTION ancestors (inodes)
    RETURNS SETOF inodes
    AS $$
    WITH RECURSIVE hierarchy AS (
        SELECT id, parent_id FROM inodes WHERE id = $1.parent_id

        UNION ALL

        SELECT inodes.id, inodes.parent_id FROM inodes
            JOIN hierarchy ON inodes.id = hierarchy.parent_id
    )
    SELECT inodes.* FROM hierarchy JOIN inodes ON inodes.id = hierarchy.id;
$$
LANGUAGE SQL;

GRANT EXECUTE ON FUNCTION ancestors TO external_user;

