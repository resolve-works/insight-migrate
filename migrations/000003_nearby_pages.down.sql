
GRANT SELECT ON TABLE sources TO external_user;
GRANT SELECT ON TABLE private.sources TO external_user;

DROP FUNCTION create_prompt(query text, similarity_top_k int, embedding vector(1536));

DROP VIEW prompts;

ALTER TABLE private.prompts DROP COLUMN embedding;

CREATE VIEW prompts WITH (security_invoker=true) AS
 SELECT * FROM private.prompts;
GRANT SELECT,INSERT ON TABLE prompts TO external_user;
GRANT ALL ON TABLE prompts TO insight_worker;

-- reset create_file function to json parameters
DROP FUNCTION create_file(name text, parent_id bigint);

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
