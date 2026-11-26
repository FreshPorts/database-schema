-------------------------------------------------------------------
-- Part 4: users.name (dvl: 1 row in raw Latin-1).
-- The login name's bytes change, so that user then logs in with the
-- UTF-8 spelling (which is what a browser sends anyway).  Not run anywhere.
-------------------------------------------------------------------
-- BEGIN;
-- UPDATE users SET name = pg_temp.latin1_to_utf8(name) WHERE name ~ '[\x80-\xff]' AND pg_temp.bad_utf8(name);
-- COMMIT;

