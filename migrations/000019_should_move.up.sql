
SELECT drop_public_schema();

ALTER TABLE private.inodes ADD COLUMN should_move boolean DEFAULT false NOT NULL;

-- When inode changes parent or name, it should be moved. All it's children should also be moved
CREATE OR REPLACE FUNCTION private.set_inode_should_move()
RETURNS TRIGGER AS $$
BEGIN
    -- Only set when changes are actually made
    IF OLD.parent_id = NEW.parent_id AND OLD.name = NEW.name THEN
        RETURN NEW;
    END IF;

    NEW.should_move = True;

    -- Mark all children to be moved
    WITH RECURSIVE children AS (
        SELECT id
        FROM private.inodes
        WHERE parent_id = NEW.id
        
        UNION ALL
        
        SELECT i.id
        FROM private.inodes i
        INNER JOIN children c ON i.parent_id = c.id
    )
    UPDATE private.inodes
    SET should_move = True
    WHERE id IN (SELECT id FROM children);

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create the triggers
CREATE TRIGGER set_inode_should_move
    BEFORE UPDATE OF parent_id, name ON private.inodes
    FOR EACH ROW
    EXECUTE FUNCTION private.set_inode_should_move();

SELECT create_public_schema();
