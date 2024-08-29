
ALTER TABLE private.prompts ADD COLUMN embedding vector(1536);

-- Rebuild prompts view to include embedding column
DROP VIEW prompts;
CREATE VIEW prompts WITH (security_invoker=true) AS
 SELECT * FROM private.prompts;
GRANT SELECT,INSERT ON TABLE prompts TO external_user;
GRANT ALL ON TABLE prompts TO insight_worker;

CREATE OR REPLACE FUNCTION create_prompt(query text, similarity_top_k int, query_embedding vector(1536))
    RETURNS SETOF prompts
    LANGUAGE plpgsql
    AS $$
DECLARE
    prompt_id bigint;
BEGIN
    INSERT INTO prompts (query, similarity_top_k, embedding) 
        VALUES (query, similarity_top_k, query_embedding)
        RETURNING id INTO prompt_id;

    INSERT INTO sources (prompt_id, page_id, similarity)
        SELECT prompt_id, pages.id as page_id, pages.embedding <=> query_embedding AS similarity
        FROM pages
        WHERE pages.embedding IS NOT NULL
        ORDER BY similarity ASC
        LIMIT similarity_top_k;

    RETURN QUERY SELECT * FROM prompts WHERE id=prompt_id;
END;
$$;

GRANT ALL ON FUNCTION create_prompt(query text, similarity_top_k int, embedding vector(1536)) TO external_user;

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
