
SELECT drop_public_schema();

DROP TRIGGER set_inode_should_move ON private.inodes;
DROP FUNCTION private.set_inode_should_move();

ALTER TABLE private.inodes DROP COLUMN should_move;

SELECT create_public_schema();
