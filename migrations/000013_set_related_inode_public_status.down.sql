
DROP TRIGGER set_child_inodes_public_status ON private.inodes;
DROP TRIGGER set_parent_inodes_public_status ON private.inodes;

DROP FUNCTION private.set_child_inodes_public_status();
DROP FUNCTION private.set_parent_inodes_public_status();
