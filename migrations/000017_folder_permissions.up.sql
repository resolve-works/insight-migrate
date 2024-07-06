
GRANT SELECT, INSERT, UPDATE, DELETE ON private.folders TO external_user;

ALTER TABLE private.folders ENABLE ROW LEVEL SECURITY;

ALTER VIEW folders SET ( security_invoker=true );

CREATE POLICY files_external_user ON private.folders 
    USING (owner_id = uuid(current_setting('request.jwt.claims', true)::json->>'sub'))
    WITH CHECK (owner_id = uuid(current_setting('request.jwt.claims', true)::json->>'sub'));

CREATE POLICY files_insight_worker ON private.folders TO insight_worker 
    USING (true)
    WITH CHECK (true);
