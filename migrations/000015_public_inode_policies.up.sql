

DROP POLICY inodes_external_user ON private.inodes;
DROP POLICY files_external_user ON private.files;
DROP POLICY pages_external_user ON private.pages;

-- Allow users to see public files, but prohibit insert / update
CREATE POLICY inodes_external_user ON private.inodes 
    USING (
        (owner_id = (((current_setting('request.jwt.claims'::text, true))::json ->> 'sub'::text))::uuid) 
        OR is_public
    ) 
    WITH CHECK (
        (owner_id = (((current_setting('request.jwt.claims'::text, true))::json ->> 'sub'::text))::uuid)
    );

CREATE POLICY files_external_user ON private.files 
    USING (
        (inode_id = ( SELECT inodes.id FROM private.inodes WHERE inodes.id = files.inode_id)) 
        OR 
        ( SELECT inodes.is_public FROM private.inodes WHERE inodes.id = files.inode_id)
    )
    WITH CHECK (
        (inode_id = ( SELECT inodes.id FROM private.inodes WHERE inodes.id = files.inode_id))
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
