
CREATE TYPE inode_type AS ENUM ('folder', 'file');

CREATE TABLE private.inodes (
    id bigint PRIMARY KEY generated always as identity,
    parent_id bigint REFERENCES private.inodes(id) ON DELETE CASCADE,
    owner_id uuid NOT NULL,
    type inode_type NOT NULL DEFAULT 'folder',
    name text NOT NULL CHECK (TRIM(name) <> ''),
    path citext NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    is_deleted boolean DEFAULT false NOT NULL,
    is_indexed boolean DEFAULT false NOT NULL,
    UNIQUE (owner_id, path)
);

CREATE TABLE private.files (
    id bigint PRIMARY KEY generated always as identity,
    inode_id bigint REFERENCES private.inodes(id) ON DELETE CASCADE UNIQUE,
    is_uploaded boolean DEFAULT false NOT NULL,
    is_ingested boolean DEFAULT false NOT NULL,
    is_embedded boolean DEFAULT false NOT NULL,
    is_ready boolean GENERATED ALWAYS AS ((is_uploaded AND is_ingested AND is_embedded)) STORED,
    from_page integer DEFAULT 0 NOT NULL,
    to_page integer
);

CREATE TABLE private.pages (
    id bigint PRIMARY KEY generated always as identity,
    inode_id bigint NOT NULL REFERENCES private.inodes(id) ON DELETE CASCADE,
    index integer NOT NULL,
    contents text NOT NULL,
    embedding vector(1536),
    UNIQUE (inode_id, index)
);

CREATE TABLE private.prompts (
    id bigint PRIMARY KEY generated always as identity,
    owner_id uuid NOT NULL,
    query text NOT NULL,
    similarity_top_k integer DEFAULT 3 NOT NULL,
    response text,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);
CREATE TABLE private.sources (
    prompt_id bigint NOT NULL REFERENCES private.prompts(id) ON DELETE CASCADE,
    page_id bigint NOT NULL REFERENCES private.pages(id) ON DELETE CASCADE,
    similarity double precision NOT NULL,
    PRIMARY KEY (prompt_id, page_id)
);

CREATE VIEW inodes WITH (security_invoker=true) AS 
 SELECT * FROM private.inodes WHERE (is_deleted = false);
CREATE VIEW files WITH (security_invoker=true) AS
 SELECT * FROM private.files;
CREATE VIEW pages WITH (security_invoker=true) AS
 SELECT * FROM private.pages;
CREATE VIEW prompts WITH (security_invoker=true) AS
 SELECT * FROM private.prompts;
CREATE VIEW sources WITH (security_invoker=true) AS
 SELECT * FROM private.sources;


CREATE FUNCTION ancestors(inodes) RETURNS SETOF inodes
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

CREATE FUNCTION inode_path(inode_id bigint) RETURNS text
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

CREATE FUNCTION mark_inode_reindex() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF NEW.name != OLD.name THEN
        NEW.is_indexed = false;
    END IF;
    RETURN NEW;
END;
$$;

CREATE FUNCTION set_inode_path() RETURNS trigger
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

CREATE FUNCTION set_owner() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    owner_id uuid := current_setting('request.jwt.claims', TRUE)::json ->> 'sub';
BEGIN
    NEW.owner_id = owner_id;
    RETURN NEW;
END
$$;

CREATE FUNCTION set_updated_at() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$;

CREATE TRIGGER mark_inode_reindex BEFORE UPDATE ON private.inodes FOR EACH ROW EXECUTE FUNCTION mark_inode_reindex();
CREATE TRIGGER set_inode_owner BEFORE INSERT ON private.inodes FOR EACH ROW EXECUTE FUNCTION set_owner();
CREATE TRIGGER set_inode_path BEFORE INSERT ON private.inodes FOR EACH ROW EXECUTE FUNCTION set_inode_path();
CREATE TRIGGER set_inodes_updated_at BEFORE UPDATE ON private.inodes FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER set_prompt_owner BEFORE INSERT ON private.prompts FOR EACH ROW EXECUTE FUNCTION set_owner();
CREATE TRIGGER set_prompt_updated_at BEFORE UPDATE ON private.prompts FOR EACH ROW EXECUTE FUNCTION set_updated_at();

ALTER TABLE private.inodes ENABLE ROW LEVEL SECURITY;
CREATE POLICY inodes_external_user ON private.inodes 
    USING ((owner_id = (((current_setting('request.jwt.claims'::text, true))::json ->> 'sub'::text))::uuid)) 
    WITH CHECK ((owner_id = (((current_setting('request.jwt.claims'::text, true))::json ->> 'sub'::text))::uuid));
CREATE POLICY inodes_insight_worker ON private.inodes TO insight_worker USING (true) WITH CHECK (true);

ALTER TABLE private.files ENABLE ROW LEVEL SECURITY;
CREATE POLICY files_external_user ON private.files USING ((inode_id = ( SELECT inodes.id
   FROM private.inodes
  WHERE (inodes.id = files.inode_id))));
CREATE POLICY files_insight_worker ON private.files TO insight_worker USING (true) WITH CHECK (true);

ALTER TABLE private.pages ENABLE ROW LEVEL SECURITY;
CREATE POLICY pages_external_user ON private.pages USING ((inode_id = ( SELECT inodes.id
   FROM private.inodes
  WHERE (inodes.id = pages.inode_id))));
CREATE POLICY pages_insight_worker ON private.pages TO insight_worker USING (true) WITH CHECK (true);

ALTER TABLE private.prompts ENABLE ROW LEVEL SECURITY;
CREATE POLICY prompts_external_user ON private.prompts 
    USING ((owner_id = (((current_setting('request.jwt.claims'::text, true))::json ->> 'sub'::text))::uuid)) 
    WITH CHECK ((owner_id = (((current_setting('request.jwt.claims'::text, true))::json ->> 'sub'::text))::uuid));
CREATE POLICY prompts_insight_worker ON private.prompts TO insight_worker USING (true) WITH CHECK (true);

ALTER TABLE private.sources ENABLE ROW LEVEL SECURITY;
CREATE POLICY sources_external_worker ON private.sources USING ((prompt_id = ( SELECT prompts.id
   FROM private.prompts
  WHERE (prompts.id = sources.prompt_id))));
CREATE POLICY sources_insight_worker ON private.sources TO insight_worker USING (true) WITH CHECK (true);

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE private.inodes TO external_user;
GRANT ALL ON TABLE private.inodes TO insight_worker;
GRANT SELECT,USAGE ON SEQUENCE private.inodes_id_seq TO external_user;
GRANT ALL ON SEQUENCE private.inodes_id_seq TO insight_worker;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE private.files TO external_user;
GRANT ALL ON TABLE private.files TO insight_worker;
GRANT SELECT ON TABLE private.pages TO external_user;
GRANT ALL ON TABLE private.pages TO insight_worker;
GRANT SELECT,USAGE ON SEQUENCE private.pages_id_seq TO external_user;
GRANT ALL ON SEQUENCE private.pages_id_seq TO insight_worker;
GRANT SELECT,INSERT ON TABLE private.prompts TO external_user;
GRANT ALL ON TABLE private.prompts TO insight_worker;
GRANT SELECT,USAGE ON SEQUENCE private.prompts_id_seq TO external_user;
GRANT ALL ON SEQUENCE private.prompts_id_seq TO insight_worker;
GRANT SELECT ON TABLE private.sources TO external_user;
GRANT ALL ON TABLE private.sources TO insight_worker;

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE inodes TO external_user;
GRANT ALL ON TABLE inodes TO insight_worker;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE files TO external_user;
GRANT ALL ON TABLE files TO insight_worker;
GRANT SELECT ON TABLE pages TO external_user;
GRANT ALL ON TABLE pages TO insight_worker;
GRANT SELECT,INSERT ON TABLE prompts TO external_user;
GRANT ALL ON TABLE prompts TO insight_worker;
GRANT SELECT ON TABLE sources TO external_user;
GRANT ALL ON TABLE sources TO insight_worker;

GRANT ALL ON FUNCTION ancestors(inodes) TO external_user;
GRANT ALL ON FUNCTION create_file(json) TO external_user;
GRANT ALL ON FUNCTION inode_path(inode_id bigint) TO insight_worker;
GRANT ALL ON FUNCTION inode_path(inode_id bigint) TO external_user;
