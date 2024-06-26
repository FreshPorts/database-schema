CREATE OR REPLACE FUNCTION user_set_cookie( a_user_id integer, a_cookie text, a_expires timestamp without time zone) RETURNS void AS $$
   INSERT INTO user_cookie(user_id, cookie, expiry_timestamp)
   VALUES (a_user_id, a_cookie, a_expires);
$$ LANGUAGE SQL VOLATILE;


CREATE OR REPLACE FUNCTION user_fetch_by_cookie( a_cookie text) RETURNS SETOF Users_Record AS $$


-- if the cookie is valid, return the user details while saying: we just used this cookie.
-- Originally, we tried a SELECT followed by an UPDATE, but that didn't return data
-- by design. Next idea, never implemented, was UPDATE first, then SELECT. That should work.

     UPDATE user_cookie
        SET expiry_timestamp = localtimestamp
       FROM users
      WHERE users.id           =  user_cookie.user_id
        AND user_cookie.cookie = a_cookie
  RETURNING users.*;

$$ LANGUAGE SQL VOLATILE;

CREATE OR REPLACE FUNCTION user_logout( a_cookie text) RETURNS void AS $$

     DELETE FROM user_cookie
           WHERE user_cookie.cookie = a_cookie;

$$ LANGUAGE SQL VOLATILE;



CREATE OR REPLACE FUNCTION user_clear_bouncecount( a_cookie text) RETURNS void AS $$

     UPDATE users
        SET emailbouncecount = 0
      FROM user_cookie
     WHERE user_cookie.cookie  = a_cookie
       AND user_cookie.user_id = users.id;

$$ LANGUAGE SQL VOLATILE;
