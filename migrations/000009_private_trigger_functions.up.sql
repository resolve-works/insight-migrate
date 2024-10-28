
-- Move private triggers & functions to private schema
DROP TRIGGER IF EXISTS set_inode_owner ON private.inodes;
DROP TRIGGER IF EXISTS set_inode_path ON private.inodes;
DROP TRIGGER IF EXISTS set_inodes_updated_at ON private.inodes;
DROP TRIGGER IF EXISTS set_prompt_updated_at ON private.prompts;
DROP TRIGGER IF EXISTS set_conversation_owner ON private.conversations;
DROP TRIGGER IF EXISTS set_conversation_updated_at ON private.conversations;

DROP FUNCTION IF EXISTS set_owner();
DROP FUNCTION IF EXISTS set_updated_at();
DROP FUNCTION IF EXISTS inode_path(bigint);
DROP FUNCTION IF EXISTS set_inode_path();

CREATE OR REPLACE FUNCTION private.set_owner() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    owner_id uuid := current_setting('request.jwt.claims', TRUE)::json ->> 'sub';
BEGIN
    NEW.owner_id = owner_id;
    RETURN NEW;
END
$$;

CREATE OR REPLACE FUNCTION private.set_updated_at() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION private.inode_path(inode_id bigint) RETURNS text
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN (
        WITH RECURSIVE hierarchy AS (
            SELECT id, name, parent_id, 1 AS depth FROM inodes WHERE id = inode_id
            UNION ALL
            SELECT inodes.id, inodes.name, inodes.parent_id, hierarchy.depth + 1 FROM inodes
                JOIN hierarchy ON inodes.id = hierarchy.parent_id
        )
        SELECT '/' || string_agg(name, '/' ORDER BY depth DESC) FROM hierarchy
    );
END
$$;

GRANT ALL ON FUNCTION private.inode_path(inode_id bigint) TO insight_worker;
GRANT ALL ON FUNCTION private.inode_path(inode_id bigint) TO external_user;

CREATE OR REPLACE FUNCTION private.set_inode_path() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF NEW.parent_id IS NOT NULL THEN
        -- Can't use storage path on id itself here, as row is not yet inserted
        NEW.path = private.inode_path(NEW.parent_id) || '/' || NEW.name;
    ELSE
        NEW.path = '/' || NEW.name;
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER set_inode_owner BEFORE INSERT ON private.inodes FOR EACH ROW EXECUTE FUNCTION private.set_owner();
CREATE TRIGGER set_inode_path BEFORE INSERT ON private.inodes FOR EACH ROW EXECUTE FUNCTION private.set_inode_path();
CREATE TRIGGER set_inodes_updated_at BEFORE UPDATE ON private.inodes FOR EACH ROW EXECUTE FUNCTION private.set_updated_at();
CREATE TRIGGER set_prompt_updated_at BEFORE UPDATE ON private.prompts FOR EACH ROW EXECUTE FUNCTION private.set_updated_at();
CREATE TRIGGER set_conversation_owner BEFORE INSERT ON private.conversations FOR EACH ROW EXECUTE FUNCTION private.set_owner();
CREATE TRIGGER set_conversation_updated_at BEFORE UPDATE ON private.conversations FOR EACH ROW EXECUTE FUNCTION private.set_updated_at();

