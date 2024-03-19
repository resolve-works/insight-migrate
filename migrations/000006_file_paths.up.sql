CREATE OR REPLACE FUNCTION set_file_path ()
    RETURNS TRIGGER
    AS $$
BEGIN
    NEW.path = format('users/%s/%s/%s.pdf', NEW.owner_id, NEW.id, NEW.id);
    RETURN NEW;
END
$$
LANGUAGE PLPGSQL;

CREATE OR REPLACE FUNCTION set_document_path ()
    RETURNS TRIGGER
    AS $$
DECLARE
    owner_id uuid;
BEGIN
    SELECT
        files.owner_id INTO owner_id
    FROM
        files
    WHERE
        id = NEW.file_id;
    NEW.path = format('users/%s/%s/%s.pdf', owner_id, NEW.file_id, NEW.id);
    RETURN NEW;
END
$$
LANGUAGE PLPGSQL;

