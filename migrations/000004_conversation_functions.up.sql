
-- Create prompt with sources
CREATE OR REPLACE FUNCTION create_prompt(query text, similarity_top_k int, embedding vector(1536))
    RETURNS SETOF prompts
    LANGUAGE plpgsql
    AS $$
DECLARE
    prompt_id bigint;
BEGIN
    INSERT INTO prompts (query, similarity_top_k, embedding) 
        VALUES (query, similarity_top_k, embedding)
        RETURNING id INTO prompt_id;

    INSERT INTO sources (prompt_id, page_id, similarity)
        -- $3 = embedding. The name 'embedding' is in conflict with the pages.embedding column.
        -- Changing the argument name would however change the argument name in the Postgrest REST api.
        SELECT prompt_id, pages.id as page_id, pages.embedding <=> $3 AS similarity
        FROM pages
        WHERE pages.embedding IS NOT NULL
        ORDER BY similarity ASC
        LIMIT similarity_top_k;

    RETURN QUERY SELECT * FROM prompts WHERE id=prompt_id;
END;
$$;

GRANT ALL ON FUNCTION create_prompt(query text, similarity_top_k int, embedding vector(1536)) TO external_user;

