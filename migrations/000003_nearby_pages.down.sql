
-- Recreate the owner_id column in private.prompts
ALTER TABLE private.prompts ADD COLUMN owner_id uuid;

-- Populate owner_id based on conversation_id
UPDATE private.prompts p
SET owner_id = c.owner_id
FROM private.conversations c
WHERE p.conversation_id = c.id;

-- Drop the new policies and triggers on prompts
DROP POLICY prompts_external_worker ON private.prompts;

-- Recreate previous RLS policies for prompts
CREATE POLICY prompts_external_user ON private.prompts
    USING ((owner_id = (((current_setting('request.jwt.claims'::text, true))::json ->> 'sub'::text))::uuid))
    WITH CHECK ((owner_id = (((current_setting('request.jwt.claims'::text, true))::json ->> 'sub'::text))::uuid));
CREATE POLICY prompts_insight_worker ON private.prompts TO insight_worker USING (true) WITH CHECK (true);

-- Recreate previous RLS policies for sources
CREATE POLICY sources_insight_worker ON private.sources TO insight_worker USING (true) WITH CHECK (true);

-- Recreate previous trigger set_prompt_owner
CREATE TRIGGER set_prompt_owner BEFORE INSERT ON private.prompts FOR EACH ROW EXECUTE FUNCTION set_owner();

-- Drop create_prompt function
DROP FUNCTION create_prompt(text, int, vector(1536));

DROP VIEW IF EXISTS conversations;
DROP VIEW IF EXISTS prompts;

-- Cleanup: Drop column conversation_id and embedding from prompts
ALTER TABLE private.prompts DROP COLUMN IF EXISTS conversation_id;
ALTER TABLE private.prompts DROP COLUMN IF EXISTS embedding;

-- Drop `private.conversations_inodes` and `private.conversations` tables
DROP TABLE IF EXISTS private.conversations_inodes;
DROP TABLE IF EXISTS private.conversations;

CREATE VIEW prompts WITH (security_invoker=true) AS
 SELECT * FROM private.prompts;

-- Recreate original set_inode_path function
CREATE OR REPLACE FUNCTION set_inode_path() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF NEW.parent_id IS NOT NULL THEN
        NEW.path = inode_path(NEW.parent_id) || '/' || NEW.name;
    ELSE
        NEW.path = NEW.name;
    END IF;
    RETURN NEW;
END;
$$;

-- Recreate original inode_path function
CREATE OR REPLACE FUNCTION inode_path(inode_id bigint) RETURNS text
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
        SELECT string_agg(name, '/' ORDER BY depth DESC) FROM hierarchy
    );
END;
$$;

-- Recreate GRANTs for all tables
GRANT SELECT,INSERT,UPDATE ON TABLE private.prompts TO external_user;
GRANT SELECT,INSERT,UPDATE ON TABLE prompts TO external_user;

GRANT SELECT,INSERT ON TABLE sources TO external_user;
GRANT SELECT,INSERT ON TABLE private.sources TO external_user;

-- Recreate original create_file function
CREATE OR REPLACE FUNCTION create_file(json) RETURNS SETOF inodes
    LANGUAGE plpgsql
    AS $$
DECLARE
    inode_id bigint;
BEGIN
    INSERT INTO inodes (name, parent_id, type)
        VALUES (($1->>'name')::text, ($1->>'parent_id')::bigint, 'file')
        RETURNING id INTO inode_id;
    INSERT INTO files (inode_id) VALUES (inode_id);
    RETURN QUERY SELECT * FROM inodes WHERE id=inode_id;
END;
$$;

GRANT ALL ON FUNCTION create_file(json) TO external_user;

-- Drop the function supporting direct parameters
DROP FUNCTION create_file(name text, parent_id bigint);

