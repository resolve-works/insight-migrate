
-- When inserting a public inode, mark all it's parents as public
-- When updating a inode to public, mark all it's parents as public
-- When updating a inode to private, mark all it's parents that don't contain a public inode as private.
CREATE OR REPLACE FUNCTION private.set_parent_inodes_public_status()
RETURNS TRIGGER AS $$
BEGIN
    -- Only proceed if visibility changed
    IF OLD.is_public = NEW.is_public THEN
        RETURN NEW;
    END IF;

    -- Update parents based on the visibility change
    IF NEW.is_public THEN
        WITH RECURSIVE parents AS (
            SELECT id, parent_id
            FROM private.inodes
            WHERE id = NEW.parent_id
            
            UNION ALL
            
            SELECT i.id, i.parent_id
            FROM private.inodes i
            INNER JOIN parents p ON i.id = p.parent_id
        )

        -- If setting to public, mark all parents as public
        UPDATE private.inodes
        SET is_public = true
        WHERE id IN (SELECT id FROM parents);
    ELSE
        WITH RECURSIVE parents AS (
            SELECT id, parent_id
            FROM private.inodes
            WHERE id = NEW.parent_id
            
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
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER set_child_inodes_public_status ON private.inodes;
CREATE TRIGGER set_child_inodes_public_status
    AFTER UPDATE OF is_public ON private.inodes
    FOR EACH ROW
    EXECUTE FUNCTION private.set_child_inodes_public_status();
