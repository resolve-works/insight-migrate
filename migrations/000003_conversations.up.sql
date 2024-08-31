
-- Create conversations and link them with prompts with inodes for filtering
CREATE TABLE private.conversations (
    id bigint PRIMARY KEY generated always as identity,
    owner_id uuid NOT NULL
);

CREATE TABLE private.conversations_inodes (
    prompt_id bigint NOT NULL REFERENCES private.prompts(id) ON DELETE CASCADE,
    inode_id bigint REFERENCES private.inodes(id) ON DELETE CASCADE,
    PRIMARY KEY (prompt_id, inode_id)
);

ALTER TABLE private.prompts ADD COLUMN embedding vector(1536);
ALTER TABLE private.prompts ADD COLUMN conversation_id bigint REFERENCES private.conversations(id) ON DELETE CASCADE;

DO $$
DECLARE
    r RECORD;
    new_conversation_id bigint;
BEGIN
    FOR r IN SELECT * FROM private.prompts LOOP
        INSERT INTO private.conversations (owner_id) VALUES (r.owner_id) RETURNING id INTO new_conversation_id;

        UPDATE private.prompts SET conversation_id = new_conversation_id WHERE id = r.id;
    END LOOP;
END $$;

-- Ownership will switch to conversations
DROP TRIGGER IF EXISTS set_prompt_owner ON private.prompts;
DROP POLICY prompts_external_user ON private.prompts;
DROP VIEW IF EXISTS prompts;
ALTER TABLE private.prompts DROP COLUMN IF EXISTS owner_id;

CREATE TRIGGER set_conversation_owner BEFORE INSERT ON private.conversations FOR EACH ROW EXECUTE FUNCTION set_owner();

ALTER TABLE private.conversations ENABLE ROW LEVEL SECURITY;
CREATE POLICY conversations_external_user ON private.conversations 
    USING ((owner_id = (((current_setting('request.jwt.claims'::text, true))::json ->> 'sub'::text))::uuid)) 
    WITH CHECK ((owner_id = (((current_setting('request.jwt.claims'::text, true))::json ->> 'sub'::text))::uuid));

CREATE POLICY prompts_external_worker ON private.prompts USING ((conversation_id = ( SELECT conversations.id
   FROM private.conversations
  WHERE (conversations.id = prompts.conversation_id))));

-- Worker does not need access anymore as prompt logic is handled in frontend
DROP POLICY prompts_insight_worker ON private.prompts;
DROP POLICY sources_insight_worker ON private.sources;

-- Create & rebuild views
CREATE VIEW conversations WITH (security_invoker=true) AS
 SELECT * FROM private.conversations;

CREATE VIEW prompts WITH (security_invoker=true) AS
 SELECT * FROM private.prompts;

-- Allow external user as prompt logic moved to frontend
GRANT SELECT,INSERT ON TABLE private.conversations TO external_user;
GRANT SELECT,INSERT ON TABLE conversations TO external_user;
GRANT SELECT,INSERT ON TABLE private.conversations_inodes TO external_user;

GRANT SELECT,INSERT,UPDATE ON TABLE private.prompts TO external_user;
GRANT SELECT,INSERT,UPDATE ON TABLE prompts TO external_user;

GRANT SELECT,INSERT ON TABLE sources TO external_user;
GRANT SELECT,INSERT ON TABLE private.sources TO external_user;

-- Make inodes paths start with / so we can use folders passed in filters without any transforms
CREATE OR REPLACE FUNCTION set_inode_path() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF NEW.parent_id IS NOT NULL THEN
        -- Can't use storage path on id itself here, as row is not yet inserted
        NEW.path = inode_path(NEW.parent_id) || '/' || NEW.name;
    ELSE
        NEW.path = '/' || NEW.name;
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
        SELECT '/' || string_agg(name, '/' ORDER BY depth DESC) FROM hierarchy
    );
END
$$;

-- Switch function to direct parameters instead of json
DROP FUNCTION create_file(json);

CREATE FUNCTION create_file(name text, parent_id bigint) RETURNS SETOF inodes
    LANGUAGE plpgsql
    AS $$
DECLARE
    inode_id bigint;
BEGIN
    INSERT INTO inodes (name, parent_id, type) 
        VALUES (name, parent_id, 'file') 
        RETURNING id INTO inode_id;
    INSERT INTO files (inode_id) VALUES (inode_id);
    RETURN QUERY SELECT * FROM inodes WHERE id=inode_id;
END
$$;

GRANT ALL ON FUNCTION create_file(name text, parent_id bigint) TO external_user;
