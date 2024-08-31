
-- Create conversation with linked folder inodes
CREATE OR REPLACE FUNCTION create_conversation(paths citext[])
    RETURNS SETOF conversations
    LANGUAGE plpgsql
    AS $$
DECLARE
    conversation_id bigint;
BEGIN
    INSERT INTO conversations 
        DEFAULT VALUES 
        RETURNING id INTO conversation_id;

    INSERT INTO conversations_inodes (conversation_id, inode_id)
        SELECT conversation_id, id AS inode_id 
        FROM inodes 
        WHERE path IN paths;

    RETURN QUERY SELECT * FROM conversations WHERE id=conversation_id;
END;
$$;

-- Create prompt with sources
CREATE OR REPLACE FUNCTION substantiate_prompt(prompt_id bigint)
    RETURNS SETOF sources
    LANGUAGE plpgsql
    AS $$
DECLARE
    prompt_embedding vector(1536);
BEGIN
    SELECT embedding
        INTO prompt_embedding
        FROM prompts
        WHERE id = prompt_id;

    WITH RECURSIVE linked_inodes AS (
        SELECT p.inode_id AS target_inode_id, i.id AS inode_id
        FROM private.prompts_inodes p
        JOIN private.inodes i ON p.inode_id = i.id
        WHERE p.prompt_id = prompt_id

        UNION ALL

        SELECT ih.target_inode_id, i.id AS inode_id
        FROM linked_inodes ih
        JOIN private.inodes i ON ih.inode_id = i.parent_id
    )

    INSERT INTO sources (prompt_id, page_id, similarity)
        -- $3 = embedding. The name 'embedding' is in conflict with the pages.embedding column.
        -- Changing the argument name would however change the argument name in the Postgrest REST api.
        SELECT prompt_id, pages.id as page_id, pages.embedding <=> prompt_embedding AS similarity
        FROM pages
        WHERE pages.embedding IS NOT NULL
        ORDER BY similarity ASC
        LIMIT similarity_top_k;

    RETURN QUERY SELECT * FROM prompts WHERE id=prompt_id;
END;
$$;

GRANT ALL ON FUNCTION create_prompt(query text, similarity_top_k int, embedding vector(1536)) TO external_user;

