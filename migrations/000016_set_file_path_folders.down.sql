
ALTER TABLE private.files DROP COLUMN dirname;

CREATE OR REPLACE FUNCTION set_file_path ()
    RETURNS TRIGGER
    AS $$
BEGIN
    NEW.path = format('%s/%s.pdf', NEW.owner_id, NEW.id);
    RETURN NEW;
END
$$
LANGUAGE PLPGSQL;
