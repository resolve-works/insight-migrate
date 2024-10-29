
-- When deleting a public inode, mark all it's parents that don't contain a public inode as private.
CREATE OR REPLACE FUNCTION private.set_parent_inodes_private_after_child_delete()
RETURNS TRIGGER AS $$
BEGIN
    -- Only proceed if visibility changed
    IF NOT OLD.is_public THEN
        RETURN OLD;
    END IF;

    -- Update parents based on the visibility change
    WITH RECURSIVE parents AS (
        SELECT id, parent_id
        FROM private.inodes
        WHERE id = OLD.parent_id
        
        UNION ALL
        
        SELECT i.id, i.parent_id
        FROM private.inodes i
        INNER JOIN parents p ON i.id = p.parent_id
    )

    -- If setting to private, check each parent if it can be private
    UPDATE private.inodes i
    SET is_public = false
    FROM parents p
    WHERE i.id = p.id
    AND NOT EXISTS (
        SELECT 1
        FROM private.inodes child
        WHERE child.parent_id = i.id
        AND child.is_public = true
    );

    RETURN OLD;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER set_parent_inodes_private_after_child_delete
    AFTER DELETE ON private.inodes
    FOR EACH ROW
    EXECUTE FUNCTION private.set_parent_inodes_private_after_child_delete();


