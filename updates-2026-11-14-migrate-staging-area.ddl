-- MigrateStagingAreaToWatchList(): use the given watch list's owner, not list 4656
--
-- pkg_upload.php's "Update watch list" button puts the ports in the
-- user's staging area onto the chosen watch list, through
-- include/pkg_process.inc MoveStagingToWatchList(), which calls this.
-- Two bugs meant it added nothing:
--
-- 1. The staging rows were chosen with
--      WLS.user_id = (SELECT user_id FROM watch_list WHERE id = 4656)
--    a hard-coded list id, apparently left over from testing in 2006
--    (commit 9ef0075).  Where list 4656 does not exist, as on
--    freshports.dvl, that is NULL and nothing matches.  Where it does,
--    the ports staged by that list's owner would be added instead of the
--    visitor's own.
--
-- 2. The NOT EXISTS, meant to skip ports already on the list, reused the
--    alias WLS and was not tied to the row being inserted.  If any one
--    staged port was already on the list, it skipped every row.
--
-- Now the staging rows are those of the list's owner, and each port is
-- skipped only if that port is already on the list.  DISTINCT keeps two
-- staging rows for the same port (two package names) from colliding on
-- watch_list_element's primary key.  Same name, argument and result.
--
-- The caller already refuses a list which is not the visitor's own
-- (www commit 1eaf0b3b), so this can only add to the visitor's own list.
--
-- Run as postgres, which owns the function.  CREATE OR REPLACE keeps its
-- owner and grants.  No website change is needed; deploy order does not
-- matter.
--
-- Function definition is also in sp.txt.
--
-- To undo, restore the previous version:
--   git show c2a9353:sp.txt, CREATE OR REPLACE FUNCTION MigrateStagingAreaToWatchList(bigint)

\set ON_ERROR_STOP on

BEGIN;

CREATE OR REPLACE FUNCTION MigrateStagingAreaToWatchList(bigint) returns int as $$
DECLARE
	p_Watch_List_ID ALIAS FOR $1;
BEGIN
-- take everything from the staging area of the watch list's owner and put
-- it on that watch list, skipping items which do not relate to a port and
-- items already on the watch list

   INSERT INTO watch_list_element (watch_list_id, element_id)
   SELECT DISTINCT p_Watch_List_ID, WLS.element_id
     FROM watch_list_staging WLS
          JOIN watch_list WL ON WL.id      = p_Watch_List_ID
                            AND WL.user_id = WLS.user_id
    WHERE WLS.element_id IS NOT NULL
      AND NOT EXISTS (SELECT 1
                        FROM watch_list_element WLE
                       WHERE WLE.watch_list_id = p_Watch_List_ID
                         AND WLE.element_id    = WLS.element_id);
	return 1;
END;
$$ LANGUAGE plpgsql;

COMMIT;
