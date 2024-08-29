
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
        SELECT string_agg(name, '/' ORDER BY depth DESC) FROM hierarchy
    );
END
$$;

CREATE OR REPLACE FUNCTION set_inode_path() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF NEW.parent_id IS NOT NULL THEN
        -- Can't use storage path on id itself here, as row is not yet inserted
        NEW.path = inode_path(NEW.parent_id) || '/' || NEW.name;
    ELSE
        NEW.path = NEW.name;
    END IF;
    RETURN NEW;
END;
$$;
