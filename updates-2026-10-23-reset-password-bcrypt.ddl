-- reset_password_token(): hash with bcrypt cost 14, not MD5-crypt
--
-- The password reset page (www/password-reset-via-token.php) calls
-- reset_password_token(), which hashed the new password with
-- gen_salt('md5').  Every reset therefore wrote an MD5-crypt hash, which
-- stayed until the user next logged in with the password and login.php
-- rehashed it.  Sign-up (new-user.php) and customize.php already use
-- PW_HASH_METHOD / PW_HASH_COST from include/constants.php: bf, 14.
--
-- Run this before invalidating the MD5 hashes
-- (updates-2026-10-23-invalidate-md5-hashes.sql): those users must reset
-- their password, and the reset must not write MD5 again.
--
-- Also in sp.txt.
--
-- To undo: re-create the function with gen_salt('md5').

\set ON_ERROR_STOP on

CREATE OR REPLACE FUNCTION reset_password_token(text, text) RETURNS int AS $$
DECLARE
 in_password ALIAS for $1;
 in_token    ALIAS for $2;
 RowCount    bigint;

BEGIN
  UPDATE users SET password_hash = crypt( in_password, gen_salt('bf', 14))
    WHERE id = (SELECT user_id from user_password_reset
                 WHERE token = in_token);
  GET DIAGNOSTICS RowCount = ROW_COUNT;
  IF RowCount = 1 THEN
    DELETE FROM user_password_reset WHERE token = in_token;
  END IF;
  RETURN RowCount;
END
$$ LANGUAGE 'plpgsql';
