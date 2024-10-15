
CREATE INDEX conversations_created_at_idx ON private.conversations (created_at);
CREATE INDEX prompts_created_at_idx ON private.prompts (created_at);

CREATE INDEX inodes_created_at_idx ON private.inodes (created_at);
CREATE INDEX inodes_type_idx ON private.inodes (type);

