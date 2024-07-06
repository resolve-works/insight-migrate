
ALTER TABLE private.files ADD COLUMN dirname TEXT;

CREATE OR REPLACE FUNCTION set_file_path ()
    RETURNS TRIGGER
    AS $$
DECLARE
    path text;
BEGIN
    WITH RECURSIVE hierarchy AS (
        SELECT id, parent_id, 1 AS depth FROM folders WHERE id = NEW.folder_id

        UNION ALL

        SELECT folders.id, folders.parent_id, hierarchy.depth + 1 FROM folders
            JOIN hierarchy ON folders.id = hierarchy.parent_id
    )
    SELECT string_agg(CAST(id AS TEXT), '/' ORDER BY depth DESC) INTO path FROM hierarchy;

    IF path IS NOT NULL THEN
        NEW.dirname = format('users/%s/%s/%s', NEW.owner_id, path, NEW.id);
    ELSE
        NEW.dirname = format('users/%s/%s', NEW.owner_id, NEW.id);
    END IF;

    NEW.path = format('%s/%s.pdf', NEW.dirname, NEW.id);

    RETURN NEW;
END
$$
LANGUAGE PLPGSQL;

CREATE OR REPLACE FUNCTION set_document_path ()
    RETURNS TRIGGER
    AS $$
DECLARE
    file_dirname text;
BEGIN
    SELECT dirname INTO file_dirname FROM private.files WHERE id = NEW.file_id;
    NEW.path = format('%s/%s.pdf', file_dirname, NEW.id);
    RETURN NEW;
END
$$
LANGUAGE PLPGSQL;

