

DROP VIEW IF EXISTS files;

ALTER TABLE private.files DROP COLUMN error;

DROP TYPE file_error;

CREATE VIEW files WITH (security_invoker=true) AS
 SELECT * FROM private.files;
