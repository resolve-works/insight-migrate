
CREATE OR REPLACE FUNCTION parents (folders)
    RETURNS SETOF folders
    AS $$
    WITH RECURSIVE folders_cte(id, name, parent_id, ancestors) AS (
        SELECT 
            folders.id,
            folders.name, 
            folders.parent_id, 
            ARRAY [folders.id] AS ancestors
            FROM folders
            WHERE folders.parent_id IS NULL

        UNION ALL

        SELECT 
            folders.id,
            folders.name, 
            folders.parent_id, 
            array_append(folders_cte.ancestors, folders.id)
            FROM folders_cte,
                 folders
            WHERE folders.parent_id = folders_cte.id
    )

    SELECT folders.*
    FROM folders_cte,
    LATERAL UNNEST(ancestors) AS ancestor_id
    JOIN folders ON folders.id = ancestor_id
    WHERE folders_cte.id = $1.id AND folders.id != $1.id;
$$
LANGUAGE SQL;

GRANT EXECUTE ON FUNCTION parents TO external_user;
