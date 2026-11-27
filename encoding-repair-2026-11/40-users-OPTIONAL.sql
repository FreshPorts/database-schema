-------------------------------------------------------------------
-- Part 4: users.name stored as raw Latin-1 (not valid UTF-8).
--
-- Every database had exactly one such row: an account whose last
-- login was in 2004 and whose password was invalidated in the 2026
-- MD5 hash reset.  Run on every database on 2026-11-26.
--
-- Why it was safe: www pages are UTF-8, so a browser sends the login
-- name as UTF-8.  The database is SQL_ASCII and compares bytes, so a
-- name stored as Latin-1 could never match what the user typed: they
-- could not log in, reset their password by name, or delete their
-- account.  After conversion the stored bytes match what a browser
-- sends.  Everything else (login cookies, watch lists, foreign keys)
-- is keyed on users.id, not the name.
--
-- Optional because it changes a login name, not port data.
-- Needs 00-helpers.sql loaded first in the same psql session.
-------------------------------------------------------------------

-- Check (read-only, no helpers needed).  Expected before: 1 row,
-- would_collide = 0 (the converted name must not clash with the
-- users_name unique constraint).  Expected after: 0 rows.
SELECT u.id, u.status, u.lastlogin::date AS lastlogin, u.password_hash LIKE '$%' AS usable_pw,
       octet_length(u.name) AS bytes,
       (SELECT count(*) FROM users o
         WHERE o.id <> u.id
           AND lower(o.name) = lower(convert_from(convert(convert_to(u.name, 'SQL_ASCII'), 'LATIN1', 'UTF8'), 'SQL_ASCII'))) AS would_collide
  FROM users u
 WHERE u.name ~ '[\x80-\xff]'
   AND NOT (u.name ~ '^(?:[\x01-\x7f]|[\xc2-\xdf][\x80-\xbf]|[\xe0-\xef][\x80-\xbf]{2}|[\xf0-\xf4][\x80-\xbf]{3})*$');

-- Repair.  Expected: UPDATE 1, the returned row has still_bad = f and
-- collisions = 0, and bad_left = 0.  Then COMMIT; or ROLLBACK;
BEGIN;
UPDATE users u SET name = pg_temp.latin1_to_utf8(name)
 WHERE name ~ '[\x80-\xff]' AND pg_temp.bad_utf8(name)
RETURNING id, octet_length(name) AS bytes, pg_temp.bad_utf8(name) AS still_bad,
          (SELECT count(*) FROM users o WHERE o.id <> u.id AND lower(o.name) = lower(u.name)) AS collisions;
SELECT count(*) AS bad_left FROM users WHERE name ~ '[\x80-\xff]' AND pg_temp.bad_utf8(name);
