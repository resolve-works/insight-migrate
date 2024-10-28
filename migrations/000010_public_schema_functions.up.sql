
-- Postgres does not allow us to edit views, when we want to edit a table we
-- need to rebuild the view. To get out of dependency hell, we rebuild the
-- complete API schema. Recommended by the maintainer
-- https://github.com/PostgREST/postgrest/discussions/2933#discussioncomment-7013203

-- Drop all of the public API schema so we can freely edit the tables
CREATE FUNCTION drop_public_schema() 
    RETURNS void
    LANGUAGE plpgsql 
    AS $OUTER$
BEGIN
    DROP FUNCTION ancestors(inodes);
    DROP FUNCTION create_conversation(citext[]);
    DROP FUNCTION create_file(text, bigint);
    DROP FUNCTION substantiate_prompt(bigint, int);

    DROP VIEW inodes;
    DROP VIEW sources;
    DROP VIEW conversations;
    DROP VIEW conversations_inodes;
    DROP VIEW files;
    DROP VIEW pages;
    DROP VIEW prompts;
END
$OUTER$;

-- Build all of the public API schema
CREATE FUNCTION create_public_schema() 
    RETURNS void
    LANGUAGE plpgsql 
    AS $OUTER$
BEGIN
    CREATE VIEW inodes WITH (security_invoker=true) AS SELECT * FROM private.inodes WHERE (is_deleted = false);
    GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE inodes TO external_user;
    GRANT ALL ON TABLE inodes TO insight_worker;

    CREATE VIEW files WITH (security_invoker=true) AS SELECT * FROM private.files;
    GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE files TO external_user;
    GRANT ALL ON TABLE files TO insight_worker;

    CREATE VIEW pages WITH (security_invoker=true) AS SELECT * FROM private.pages;
    GRANT SELECT ON TABLE pages TO external_user;
    GRANT ALL ON TABLE pages TO insight_worker;

    CREATE VIEW sources WITH (security_invoker=true) AS SELECT * FROM private.sources;
    GRANT SELECT,INSERT ON TABLE sources TO external_user;
    GRANT ALL ON TABLE sources TO insight_worker;

    CREATE VIEW conversations WITH (security_invoker=true) AS SELECT * FROM private.conversations;
    GRANT SELECT,INSERT,UPDATE ON TABLE conversations TO external_user;

    CREATE VIEW conversations_inodes WITH (security_invoker=true) AS SELECT * FROM private.conversations_inodes;
    GRANT SELECT,INSERT ON TABLE conversations_inodes TO external_user;

    CREATE VIEW prompts WITH (security_invoker=true) AS SELECT * FROM private.prompts;
    GRANT SELECT,INSERT,UPDATE ON TABLE prompts TO external_user;

    -- Get ancestor inodes of inode recursively
    CREATE FUNCTION ancestors(inodes) 
        RETURNS SETOF inodes
        LANGUAGE plpgsql
        AS $$
    BEGIN
        RETURN QUERY WITH RECURSIVE hierarchy AS (
            SELECT id, parent_id FROM inodes WHERE id = $1.parent_id
            UNION ALL
            SELECT inodes.id, inodes.parent_id FROM inodes
                JOIN hierarchy ON inodes.id = hierarchy.parent_id
        )
        SELECT inodes.* FROM hierarchy JOIN inodes ON inodes.id = hierarchy.id;
    END
    $$;

    GRANT ALL ON FUNCTION ancestors(inodes) TO external_user;

    -- Create conversation, link it to some folder paths
    CREATE FUNCTION create_conversation(folders citext[])
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
            SELECT conversation_id, i.id AS inode_id 
            FROM inodes i
            WHERE i.path = ANY(folders);

        RETURN QUERY SELECT * FROM conversations WHERE id=conversation_id;
    END;
    $$;

    GRANT ALL ON FUNCTION create_conversation(citext[]) TO external_user;

    -- Create file inode with file record
    CREATE FUNCTION create_file(name text, parent_id bigint) 
        RETURNS SETOF inodes
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
            SELECT i.id
                FROM conversations_inodes ci
                JOIN inodes i ON ci.inode_id = i.id
                WHERE ci.conversation_id = prompt_conversation_id

            UNION ALL

            SELECT i.id
                FROM linked_inodes li
                JOIN inodes i ON li.id = i.parent_id
        ),
        already_linked_pages AS (
            SELECT s.page_id AS id
                FROM sources s
                JOIN prompts p ON s.prompt_id = p.id
                WHERE p.conversation_id = prompt_conversation_id
        )

        -- Create new sources for this prompt
        INSERT INTO sources (prompt_id, page_id, similarity)
        SELECT prompt_id, p.id as page_id, p.embedding <=> prompt_embedding AS similarity
            FROM pages p
            -- Exclude pages that have been already linked to this prompt
            WHERE p.id NOT IN (SELECT id FROM already_linked_pages)
                -- Exclude non embedded pages
                AND p.embedding IS NOT NULL
                -- Only pages from linked inodes when there are are inodes linked
                AND (
                    -- Either the linked_inodes set is not empty and we filter by inodes
                    -- Or the set is empty and we get pages from all inodes
                    p.inode_id IN (SELECT id FROM linked_inodes) 
                    OR NOT EXISTS (SELECT 1 FROM linked_inodes)
                )
            ORDER BY similarity ASC
            LIMIT similarity_top_k
            RETURNING *;
    END;
    $$;

    GRANT ALL ON FUNCTION substantiate_prompt(bigint, int) TO external_user;
END
$OUTER$;

SELECT drop_public_schema();
SELECT create_public_schema();
