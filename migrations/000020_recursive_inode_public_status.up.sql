
-- When inserting a public inode, mark its parent as public
-- When updating a inode to public, mark it's parent as public
-- When updating a inode to private, mark it's parent private if it doesn't contain a public inode.
CREATE OR REPLACE FUNCTION private.set_parent_inodes_public_status()
RETURNS TRIGGER AS $$
BEGIN
    -- Only proceed if visibility changed
    IF OLD.is_public = NEW.is_public THEN
        RETURN NEW;
    END IF;

    -- Update parents based on the visibility change
    IF NEW.is_public THEN
        -- If setting to public, mark parent as public
        UPDATE private.inodes SET is_public = true WHERE id = NEW.parent_id;
    ELSE
        -- If setting to private, check if parent can be private, meaning it has no more public children
        UPDATE private.inodes 
        SET is_public = false
        WHERE id = NEW.parent_id
        AND NOT EXISTS (
            SELECT 1
            FROM private.inodes children
            WHERE children.parent_id = NEW.parent_id
            AND children.is_public = true
        );
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Updating the parent of an inode to be public triggers the
-- set_child_inodes_public_status trigger, marking all children of the parent
-- as public, effectively marking the whole hierarchy public. Use the
-- pg_trigger_depth() function to only update the children of the original
-- updated inode
DROP TRIGGER set_child_inodes_public_status ON private.inodes;
CREATE TRIGGER set_child_inodes_public_status
    AFTER UPDATE OF is_public ON private.inodes
    FOR EACH ROW
    WHEN (pg_trigger_depth() = 0)
    EXECUTE FUNCTION private.set_child_inodes_public_status();
