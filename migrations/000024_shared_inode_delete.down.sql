
DROP POLICY inodes_external_user_select ON private.inodes;
DROP POLICY inodes_external_user_delete ON private.inodes;
DROP POLICY pages_external_user_select ON private.pages;
DROP POLICY pages_external_user_delete ON private.pages;

-- Allow users to see public files, but prohibit insert / update
CREATE POLICY inodes_external_user ON private.inodes 
    USING (
        (owner_id = (((current_setting('request.jwt.claims'::text, true))::json ->> 'sub'::text))::uuid) 
        OR is_public
    ) 
    WITH CHECK (
        (owner_id = (((current_setting('request.jwt.claims'::text, true))::json ->> 'sub'::text))::uuid)
    );

CREATE POLICY pages_external_user ON private.pages 
    USING (
        (inode_id = ( SELECT inodes.id FROM private.inodes WHERE inodes.id = pages.inode_id))
        OR 
        ( SELECT inodes.is_public FROM private.inodes WHERE inodes.id = pages.inode_id)
    )
    WITH CHECK (
        (inode_id = ( SELECT inodes.id FROM private.inodes WHERE inodes.id = pages.inode_id))
    );
