-- users: index lower(name) for the login lookup
--
-- The website (include/freshports.php, www/login.php) and sp.txt find a
-- user with WHERE lower(name) = lower($1).  The users_name constraint
-- indexes name, not lower(name), so every login read the whole users
-- table (~16,000 rows).  That costs a few milliseconds; the ~0.8 s per
-- login seen in pg_stat_statements is the bcrypt cost-14 crypt(), by
-- design.
--
-- Already on production (created there 2026-10-23), so IF NOT EXISTS.
-- Run as the database owner.  CREATE INDEX CONCURRENTLY cannot run inside
-- a transaction.
--
-- Also in createdb.sql.
--
-- To undo:
--   DROP INDEX CONCURRENTLY users_lower_name_idx;

\set ON_ERROR_STOP on

CREATE INDEX CONCURRENTLY IF NOT EXISTS users_lower_name_idx ON users USING btree (lower(name));
