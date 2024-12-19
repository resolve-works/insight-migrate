
UPDATE private.inodes
    SET name = regexp_replace(name, '[/\\]', '-', 'g')
    WHERE name ~ '[/\\]';

ALTER TABLE private.inodes 
    ADD CONSTRAINT inodes_name_no_slashes CHECK (name !~ '[/\\]');
