-- Drop new tables and related data
DROP TABLE IF EXISTS private.conversations_inodes;
DROP TABLE IF EXISTS private.conversations CASCADE;

-- Remove conversation_id and embedding columns from prompts
ALTER TABLE private.prompts DROP COLUMN IF EXISTS conversation_id;
ALTER TABLE private.prompts DROP COLUMN IF EXISTS embedding;
ALTER TABLE private.prompts ADD COLUMN owner_id uuid NOT NULL;

-- Recreate dropped trigger for setting prompt owner
CREATE TRIGGER set_prompt_owner BEFORE INSERT ON private.prompts FOR EACH ROW EXECUTE FUNCTION set_owner();

-- Recreate dropped and modified policies

-- Drop the modified prompts policy and recreate the original one
DROP POLICY IF EXISTS prompts_external_worker ON private.prompts;
CREATE POLICY prompts_external_user ON private.prompts
    USING ((owner_id = (((current_setting('request.jwt.claims'::text, true))::json ->> 'sub'::text))::uuid))
    WITH CHECK ((owner_id = (((current_setting('request.jwt.claims'::text, true))::json ->> 'sub'::text))::uuid));

-- Recreate the dropped policies for the prompts and sources
CREATE POLICY prompts_insight_worker ON private.prompts TO insight_worker USING (true) WITH CHECK (true);
CREATE POLICY sources_insight_worker ON private.sources TO insight_worker USING (true) WITH CHECK (true);

-- Recreate views
DROP VIEW IF EXISTS conversations;

DROP VIEW IF EXISTS prompts;
CREATE VIEW prompts WITH (security_invoker=true) AS
 SELECT * FROM private.prompts;

-- Adjust grants to match initial state

REVOKE SELECT,INSERT ON TABLE private.conversations FROM external_user;
REVOKE SELECT,INSERT ON TABLE conversations FROM external_user;
REVOKE SELECT,INSERT ON TABLE private.conversations_inodes FROM external_user;

GRANT SELECT,INSERT ON TABLE private.prompts TO external_user;
GRANT ALL ON TABLE private.prompts TO insight_worker;

ALTER TABLE private.prompts ENABLE ROW LEVEL SECURITY;
GRANT SELECT,INSERT,UPDATE ON TABLE prompts TO external_user;

ALTER TABLE private.sources ENABLE ROW LEVEL SECURITY;
GRANT SELECT,INSERT ON TABLE sources TO external_user;
GRANT ALL ON TABLE sources TO insight_worker;

-- Recreate original functions

-- Make inodes paths without starting /
CREATE OR REPLACE FUNCTION set_inode_path() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF NEW.parent_id IS NOT NULL THEN
        -- Can't use storage path on id itself here, as row is not yet inserted
        NEW.path = inode_path(NEW.parent_id) || '/' || NEW.name;
    ELSE
        NEW.path = NEW.name;
    END IF;
    RETURN NEW;
END;
$$;

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
END
$$;

-- Drop the create_prompt function created in the migration
DROP FUNCTION IF EXISTS create_prompt(query text, similarity_top_k int, embedding vector(1536));

-- Recreate initial create_file function with json parameter
DROP FUNCTION IF EXISTS create_file(name text, parent_id bigint);

CREATE FUNCTION create_file(json) RETURNS SETOF inodes
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
END
$$;

GRANT ALL ON FUNCTION create_file(json) TO external_user;
