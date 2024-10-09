

DROP VIEW IF EXISTS conversations;
ALTER TABLE private.conversations DROP COLUMN error;
DROP TYPE conversation_error;

DROP VIEW IF EXISTS prompts;
ALTER TABLE private.prompts DROP COLUMN error;
DROP TYPE prompt_error;

CREATE VIEW conversations WITH (security_invoker=true) AS
 SELECT * FROM private.conversations;
GRANT SELECT,INSERT ON TABLE conversations TO external_user;
GRANT SELECT,INSERT ON TABLE private.conversations TO external_user;

CREATE VIEW prompts WITH (security_invoker=true) AS
 SELECT * FROM private.prompts;
GRANT SELECT,INSERT,UPDATE ON TABLE prompts TO external_user;

DROP FUNCTION create_conversation(citext[]);
CREATE OR REPLACE FUNCTION create_conversation(folders citext[])
    RETURNS SETOF conversations
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

    RETURN QUERY SELECT * FROM conversations WHERE id=conversation_id;
END;
$$;

GRANT ALL ON FUNCTION create_conversation(citext[]) TO external_user;
