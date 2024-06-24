
CREATE OR REPLACE TRIGGER set_folder_owner
    BEFORE INSERT ON private.folders
    FOR EACH ROW
    EXECUTE FUNCTION set_owner ();
