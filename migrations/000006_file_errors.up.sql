
CREATE TYPE file_error AS ENUM ('unsupported_file_type', 'corrupted_file');

ALTER TABLE private.files ADD COLUMN error file_error;

DROP VIEW IF EXISTS files;

CREATE VIEW files WITH (security_invoker=true) AS
 SELECT * FROM private.files;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE files TO external_user;
GRANT ALL ON TABLE files TO insight_worker;

