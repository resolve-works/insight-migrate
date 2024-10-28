
-- When inserting an inode, mark it as public if it's parent is public
CREATE OR REPLACE FUNCTION private.set_inode_public_status()
RETURNS TRIGGER AS $$
BEGIN
    -- If inode is public we don't have to check parent
    IF NEW.is_public THEN
        RETURN NEW;
    END IF;

    -- If inode is private, mark it's public status same as it's parent
    SELECT is_public INTO NEW.is_public
    FROM private.inodes 
    WHERE id = NEW.parent_id;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER set_inode_public_status
    BEFORE INSERT 
    ON private.inodes
    FOR EACH ROW
    EXECUTE FUNCTION private.set_inode_public_status();
