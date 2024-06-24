
CREATE TABLE IF NOT EXISTS private.folders (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid (),
    parent_id uuid,
    owner_id uuid NOT NULL,
    name text NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (parent_id) REFERENCES private.folders (id) ON DELETE CASCADE
);

CREATE OR REPLACE TRIGGER set_folder_updated_at
    BEFORE UPDATE ON private.folders
    FOR EACH ROW
    EXECUTE FUNCTION set_updated_at ();

CREATE OR REPLACE VIEW folders AS
SELECT
    *
FROM
    private.folders;

GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE folders TO external_user;

CREATE OR REPLACE FUNCTION children (folders)
    RETURNS SETOF folders
    AS $$
    SELECT * FROM folders WHERE parent_id = $1.id
$$
LANGUAGE SQL;

GRANT EXECUTE ON FUNCTION children TO external_user;
