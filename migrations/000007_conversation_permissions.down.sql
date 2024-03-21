
ALTER TABLE private.prompts DISABLE ROW LEVEL SECURITY;

ALTER VIEW prompts SET ( security_invoker=false );

REVOKE SELECT, INSERT on private.prompts FROM external_user;

DROP POLICY prompts_external_user;
DROP POLICY prompts_insight_worker;

REVOKE SELECT on private.sources FROM external_user;


ALTER TABLE private.sources DISABLE ROW LEVEL SECURITY;

ALTER VIEW sources SET ( security_invoker=false );

DROP POLICY sources_external_worker;
DROP POLICY sources_insight_worker;
