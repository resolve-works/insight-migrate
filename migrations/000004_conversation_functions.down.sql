
DROP FUNCTION create_conversation(citext[]);
DROP FUNCTION substantiate_prompt(bigint, int);

DROP VIEW IF EXISTS prompts;
ALTER TABLE private.prompts ADD COLUMN similarity_top_k integer DEFAULT 3 NOT NULL;
CREATE VIEW prompts WITH (security_invoker=true) AS
    SELECT * FROM private.prompts;
