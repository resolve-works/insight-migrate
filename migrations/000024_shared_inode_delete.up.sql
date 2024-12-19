
-- More specific policies to prevent unauthorized delete

DROP POLICY inodes_external_user ON private.inodes;

CREATE POLICY inodes_external_user_select ON private.inodes 
    USING (
        (owner_id = (((current_setting('request.jwt.claims'::text, true))::json ->> 'sub'::text))::uuid) 
        OR is_public
    )
    WITH CHECK (
        (owner_id = (((current_setting('request.jwt.claims'::text, true))::json ->> 'sub'::text))::uuid)
    );

CREATE POLICY inodes_external_user_delete ON private.inodes 
    AS RESTRICTIVE
    FOR DELETE 
    USING (
        (owner_id = (((current_setting('request.jwt.claims'::text, true))::json ->> 'sub'::text))::uuid) 
    );

DROP POLICY pages_external_user ON private.pages;

CREATE POLICY pages_external_user_select ON private.pages 
    FOR SELECT
    USING (
        (inode_id = ( SELECT inodes.id FROM private.inodes WHERE inodes.id = pages.inode_id))
        OR 
        ( SELECT inodes.is_public FROM private.inodes WHERE inodes.id = pages.inode_id)
    );

CREATE POLICY pages_external_user_delete ON private.pages 
    AS RESTRICTIVE
    FOR DELETE
    USING (
        (inode_id = ( SELECT inodes.id FROM private.inodes WHERE inodes.id = pages.inode_id))
    );
