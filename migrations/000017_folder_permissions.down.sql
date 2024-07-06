
DROP POLICY files_insight_worker ON private.folders;
DROP POLICY files_external_user ON private.folders;

ALTER VIEW folders RESET (security_invoker);

ALTER TABLE private.folders DISABLE ROW LEVEL SECURITY;

REVOKE SELECT, INSERT, UPDATE, DELETE ON private.folders FROM external_user;
