
GRANT SELECT, INSERT, UPDATE, DELETE ON private.files TO external_user;

ALTER TABLE private.files ENABLE ROW LEVEL SECURITY;

ALTER VIEW files SET ( security_invoker=true );

CREATE POLICY files_external_user ON private.files 
    USING (owner_id = uuid(current_setting('request.jwt.claims', true)::json->>'sub'))
    WITH CHECK (owner_id = uuid(current_setting('request.jwt.claims', true)::json->>'sub'));

CREATE POLICY files_insight_worker ON private.files TO insight_worker 
    USING (true)
    WITH CHECK (true);

GRANT SELECT, INSERT, UPDATE, DELETE ON private.documents TO external_user;

ALTER TABLE private.documents ENABLE ROW LEVEL SECURITY;

ALTER VIEW documents SET ( security_invoker=true );

CREATE POLICY documents_external_worker ON private.documents 
    USING (file_id = (SELECT id FROM private.files WHERE id = file_id));

CREATE POLICY documents_insight_worker ON private.documents TO insight_worker 
    USING (true)
    WITH CHECK (true);

GRANT SELECT ON private.pages TO external_user;

ALTER TABLE private.pages ENABLE ROW LEVEL SECURITY;

ALTER VIEW pages SET ( security_invoker=true );

CREATE POLICY pages_external_worker ON private.pages 
    USING (file_id = (SELECT id FROM private.files WHERE id = file_id));

CREATE POLICY pages_insight_worker ON private.pages TO insight_worker 
    USING (true)
    WITH CHECK (true);
