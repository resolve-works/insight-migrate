

CREATE FUNCTION mark_inode_reindex() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF NEW.name != OLD.name THEN
        NEW.is_indexed = false;
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER mark_inode_reindex BEFORE UPDATE ON private.inodes FOR EACH ROW EXECUTE FUNCTION mark_inode_reindex();

