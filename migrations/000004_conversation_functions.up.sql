
-- Similarity is now a function argument
DROP VIEW IF EXISTS prompts;
ALTER TABLE private.prompts DROP COLUMN IF EXISTS similarity_top_k;
CREATE VIEW prompts WITH (security_invoker=true) AS
    SELECT * FROM private.prompts;

-- Create conversation with linked folder inodes
CREATE OR REPLACE FUNCTION create_conversation(paths citext[])
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
        SELECT i.conversation_id, i.id AS inode_id 
        FROM private.inodes i
        WHERE i.path = ANY(paths);

    RETURN QUERY SELECT * FROM conversations WHERE id=conversation_id;
END;
$$;

-- Create prompt with sources
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
    ),
    -- Based on the inodes, get files that we want to search pages for
    relevant_files AS (
        SELECT f.id AS file_id
            FROM private.files f
            -- Either the linked_inodes set is not empty and we filter by inodes
            -- Or the set is empty and we return all files
            WHERE f.inode_id IN (SELECT inode_id FROM linked_inodes)
            OR NOT EXISTS (SELECT 1 FROM linked_inodes)
    )

    -- Create new sources for this prompt
    INSERT INTO sources (prompt_id, page_id, similarity)
    SELECT prompt_id, pages.id as page_id, pages.embedding <=> prompt_embedding AS similarity
        FROM pages
        WHERE pages.file_id IN (SELECT file_id FROM relevant_files)
            AND pages.embedding IS NOT NULL
        ORDER BY similarity ASC
        LIMIT similarity_top_k
    RETURNING *;
END;
$$;

GRANT ALL ON FUNCTION create_conversation(citext[]) TO external_user;
GRANT ALL ON FUNCTION substantiate_prompt(bigint, int) TO external_user;

