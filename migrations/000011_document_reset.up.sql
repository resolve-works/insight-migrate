
CREATE OR REPLACE FUNCTION reset_document_pagerange ()
    RETURNS TRIGGER
    AS $$
BEGIN
    IF NEW.from_page != OLD.from_page OR NEW.to_page != OLD.to_page THEN
        NEW.is_ingested = false;
        NEW.is_indexed = false;
        NEW.is_embedded = false;
    END IF;

    RETURN NEW;
END;
$$
LANGUAGE PLPGSQL;

CREATE OR REPLACE TRIGGER reset_document_pagerange
    BEFORE UPDATE ON private.documents
    FOR EACH ROW
    EXECUTE FUNCTION reset_document_pagerange ();

CREATE OR REPLACE FUNCTION reset_document_name ()
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

CREATE OR REPLACE TRIGGER reset_document_name
    BEFORE UPDATE ON private.documents
    FOR EACH ROW
    EXECUTE FUNCTION reset_document_name ();
