-- users: invalidate the remaining MD5-crypt password hashes
--
-- DATA CHANGE.  Run on each database only with the go-ahead.
--
-- login.php upgrades a hash to bcrypt cost 14 when the user logs in with
-- the password.  The MD5-crypt ($1$) hashes left are accounts that have
-- not logged in since bcrypt arrived: on production 2026-10-23, 12,440
-- MD5 hashes, of which 19 were seen in the last 5 years.  MD5-crypt is
-- quick to crack if the database leaks.
--
-- This replaces each MD5 hash with '!', which no password matches.  The
-- user gets "Login Failed!" and must use "Forgotten your password?".
-- Watch list notification emails are unaffected; they do not need a login.
--
-- The old hashes are kept in users_md5_hash_backup so this can be undone.
-- That is a separate table, not a column on users: users_record mirrors
-- the users columns, and user_fetch_by_cookie() returns users.* as
-- users_record, so a new users column breaks every logged-in page.
-- No grants: the website cannot read it.  Drop it once nobody has asked
-- for the old hashes back; until then they are as crackable as before.
--
-- Prerequisites, in this order:
--   1. updates-2026-10-23-reset-password-bcrypt.ddl (resets write bcrypt)
--   2. the website release whose getLoginDetails() only calls crypt()
--      when password_hash starts with '$', deployed on the host which
--      uses this database.  Older code calls crypt($2, '!'), which raises
--      "ERROR: invalid salt", so the login page dies with "query failed".
--
-- Run as the database owner.
--
-- To undo, for users who have not reset their password since:
--   UPDATE users u
--      SET password_hash = b.password_hash
--     FROM users_md5_hash_backup b
--    WHERE b.user_id = u.id
--      AND u.password_hash = '!';
--
-- To finish, once the old hashes are no longer wanted:
--   DROP TABLE users_md5_hash_backup;

\set ON_ERROR_STOP on

BEGIN;

CREATE TABLE users_md5_hash_backup (
    user_id       integer     NOT NULL PRIMARY KEY
                  REFERENCES users(id) ON UPDATE CASCADE ON DELETE CASCADE,
    password_hash text        NOT NULL,
    invalidated   timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE users_md5_hash_backup IS 'MD5-crypt hashes replaced by ''!'' in users on 2026-10-23, kept to undo that. Drop when no longer needed.';

SELECT count(*) AS md5_hashes FROM users WHERE password_hash LIKE '$1$%';

INSERT INTO users_md5_hash_backup (user_id, password_hash)
SELECT id, password_hash
  FROM users
 WHERE password_hash LIKE '$1$%';

UPDATE users u
   SET password_hash = '!'
  FROM users_md5_hash_backup b
 WHERE b.user_id = u.id
   AND u.password_hash = b.password_hash;

SELECT count(*) AS md5_hashes_left FROM users WHERE password_hash LIKE '$1$%';

-- the INSERT and UPDATE counts must match the first SELECT, and
-- md5_hashes_left must be 0; then:
--   COMMIT;   or   ROLLBACK;
