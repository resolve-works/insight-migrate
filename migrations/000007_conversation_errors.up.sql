
-- Create conversation with linked folder inodes
DROP FUNCTION create_conversation(citext[]);
CREATE OR REPLACE FUNCTION create_conversation(folders citext[])
    RETURNS SETOF private.conversations
    LANGUAGE plpgsql
    AS $$
DECLARE
    conversation_id bigint;
BEGIN
    INSERT INTO private.conversations 
        DEFAULT VALUES 
        RETURNING id INTO conversation_id;

    INSERT INTO private.conversations_inodes (conversation_id, inode_id)
        SELECT conversation_id, i.id AS inode_id 
        FROM private.inodes i
        WHERE i.path = ANY(folders);

    RETURN QUERY SELECT * FROM private.conversations WHERE id=conversation_id;
END;
$$;

GRANT ALL ON FUNCTION create_conversation(citext[]) TO external_user;

CREATE TYPE conversation_error AS ENUM ('completion_context_exceeded');
CREATE TYPE prompt_error AS ENUM ('embed_context_exceeded');

ALTER TABLE private.conversations ADD COLUMN error conversation_error;
ALTER TABLE private.prompts ADD COLUMN error prompt_error;

DROP VIEW IF EXISTS conversations;
DROP VIEW IF EXISTS prompts;

CREATE VIEW conversations WITH (security_invoker=true) AS
 SELECT * FROM private.conversations;
GRANT SELECT,INSERT,UPDATE ON TABLE private.conversations TO external_user;
GRANT SELECT,INSERT,UPDATE ON TABLE conversations TO external_user;

CREATE VIEW prompts WITH (security_invoker=true) AS
 SELECT * FROM private.prompts;
GRANT SELECT,INSERT,UPDATE ON TABLE prompts TO external_user;
