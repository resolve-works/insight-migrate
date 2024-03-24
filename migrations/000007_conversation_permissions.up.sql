
GRANT SELECT, INSERT on private.prompts TO external_user;

ALTER TABLE private.prompts ENABLE ROW LEVEL SECURITY;

ALTER VIEW prompts SET ( security_invoker=true );

CREATE POLICY prompts_external_user ON private.prompts 
    USING (owner_id = uuid(current_setting('request.jwt.claims', true)::json->>'sub'))
    WITH CHECK (owner_id = uuid(current_setting('request.jwt.claims', true)::json->>'sub'));

CREATE POLICY prompts_insight_worker ON private.prompts TO insight_worker 
    USING (true)
    WITH CHECK (true);

GRANT SELECT on private.sources TO external_user;

ALTER TABLE private.sources ENABLE ROW LEVEL SECURITY;

ALTER VIEW sources SET ( security_invoker=true );

CREATE POLICY sources_external_worker ON private.sources 
    USING (prompt_id = (SELECT id FROM private.prompts WHERE id = prompt_id));

CREATE POLICY sources_insight_worker ON private.sources TO insight_worker 
    USING (true)
    WITH CHECK (true);
