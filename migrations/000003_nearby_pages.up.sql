
ALTER TABLE private.prompts ADD COLUMN embedding vector(1536);

-- Rebuild prompts view to include embedding column
DROP VIEW prompts;
CREATE VIEW prompts WITH (security_invoker=true) AS
 SELECT * FROM private.prompts;
GRANT SELECT,INSERT ON TABLE prompts TO external_user;
GRANT ALL ON TABLE prompts TO insight_worker;

GRANT SELECT,INSERT ON TABLE sources TO external_user;
GRANT SELECT,INSERT ON TABLE private.sources TO external_user;

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
