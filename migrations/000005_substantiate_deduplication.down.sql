
-- Link sources to prompt based on inodes linked to conversation
CREATE OR REPLACE FUNCTION substantiate_prompt(prompt_id bigint, similarity_top_k int)
    RETURNS SETOF sources
    LANGUAGE plpgsql
    AS $$
DECLARE
    prompt_embedding vector(1536);
    prompt_conversation_id bigint;
BEGIN
    -- Get prompt
    SELECT embedding, conversation_id
        INTO prompt_embedding, prompt_conversation_id
        FROM prompts
        WHERE id = prompt_id;

    RETURN QUERY
    -- Select inodes that are linked to conversation that prompt is a part of
    WITH RECURSIVE linked_inodes AS (
        SELECT i.id AS inode_id
            FROM private.conversations_inodes ci
            JOIN private.inodes i ON ci.inode_id = i.id
            WHERE ci.conversation_id = prompt_conversation_id

        UNION ALL

        SELECT i.id AS inode_id
            FROM linked_inodes li
            JOIN private.inodes i ON li.inode_id = i.parent_id
    )

    -- Create new sources for this prompt
    INSERT INTO sources (prompt_id, page_id, similarity)
    SELECT prompt_id, p.id as page_id, p.embedding <=> prompt_embedding AS similarity
        FROM pages p
        WHERE p.embedding IS NOT NULL
            -- Only pages from linked inodes when there are are inodes linked
            AND (
                -- Either the linked_inodes set is not empty and we filter by inodes
                -- Or the set is empty and we get pages from all inodes
                p.inode_id IN (SELECT inode_id FROM linked_inodes) 
                OR NOT EXISTS (SELECT 1 FROM linked_inodes)
            )
        ORDER BY similarity ASC
        LIMIT similarity_top_k
        RETURNING *;
END;
$$;
