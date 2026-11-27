-- packages_last_checked.missing_since: remove packages for a repo which
-- has gone from pkg.freebsd.org
-- (https://github.com/FreshPorts/freshports/issues/449)
--
-- Port pages showed packages from repos which no longer exist, such as
-- git 2.39.0 for FreeBSD:14:armv6 latest.  Every hour,
-- check_repos_for_new_stuff.py asks pkg.freebsd.org for each repo's date
-- and passes it to PackagesLastCheckedSetRepoDate().  When the repo is gone
-- (a 404), the date is NULL, repo_date becomes NULL, and no import starts.
-- Nothing removed the packages rows from the last import, so they stayed on
-- the port pages for as long as the ABI was listed.
--
-- A NULL date also comes back when a fetch merely fails, so one NULL is
-- not enough to delete anything.  This adds:
--
--   packages_last_checked.missing_since  when the hourly check first got no
--                                        date for this repo; NULL while the
--                                        repo is there
--
--   PackagesLastCheckedSetRepoDate()     now also sets missing_since on the
--                                        first check with no date, keeps it
--                                        while the date stays NULL, and
--                                        clears it when a date comes back
--
--   PackagesDeleteForMissingRepos(interval)
--                                        deletes the packages rows of every
--                                        repo missing for longer than the
--                                        interval (default 7 days), writes
--                                        one package_imports row for each
--                                        such repo (inserts 0, updates 0,
--                                        deletes n) and returns the same
--                                        counts
--
-- ingress-scripts packages-delete-missing-repos.py calls
-- PackagesDeleteForMissingRepos() once a day, from refresh-abi.sh (periodic
-- daily/330.refresh-abi), and prints what it deleted, so it shows in the
-- daily periodic mail.  A day with nothing to delete prints nothing.
--
-- Repos which are old but still there (FreeBSD:14:armv7 and
-- FreeBSD:15:armv7, last built September 2025) have a repo_date, so
-- missing_since stays NULL and their packages stay: they are still what
-- pkg.freebsd.org serves.
--
-- When a repo comes back, the hourly check gets its date, missing_since is
-- cleared, and the next import fills packages again, as before.
--
-- Rows with no repo_date now get missing_since = now, so the 7 days start
-- when this file runs.  That includes repos which never existed (e.g.
-- FreeBSD:16 quarterly); they have no packages rows, so nothing is deleted
-- for them.
--
-- Run as postgres, which owns packages_last_checked and the function.
-- CREATE OR REPLACE keeps the owner and grants of
-- PackagesLastCheckedSetRepoDate().  No new tables or sequences, so no new
-- grants: packaging already has UPDATE on packages_last_checked, DELETE on
-- packages and INSERT on package_imports, and
-- PackagesDeleteForMissingRepos() runs with the caller's rights.
--
-- Deploy order: this file first, then ingress-scripts with
-- packages-delete-missing-repos.py.  The old check_repos_for_new_stuff.py
-- works unchanged with the new function.
--
-- Also in createdb.sql (column) and sp.txt (functions).
--
-- To undo:
--   DROP FUNCTION PackagesDeleteForMissingRepos(interval);
--   restore PackagesLastCheckedSetRepoDate() from sp.txt before this change
--   ALTER TABLE packages_last_checked DROP COLUMN missing_since;

\set ON_ERROR_STOP on

BEGIN;

ALTER TABLE packages_last_checked ADD COLUMN missing_since timestamp with time zone;

COMMENT ON COLUMN packages_last_checked.missing_since IS 'When the hourly check (check_repos_for_new_stuff.py) first got no date for this repo, usually a 404; NULL while the repo is there. PackagesDeleteForMissingRepos() deletes the packages of repos missing for more than 7 days. See https://github.com/FreshPorts/freshports/issues/449';

UPDATE packages_last_checked
   SET missing_since = CURRENT_TIMESTAMP
 WHERE repo_date IS NULL;

CREATE OR REPLACE FUNCTION PackagesLastCheckedSetRepoDate(
	a_abi_name text,
	a_package_set package_sets,
	a_repodate timestamp without time zone)
    RETURNS boolean
    LANGUAGE 'plpgsql'
    COST 100
    VOLATILE PARALLEL UNSAFE
AS $BODY$
  DECLARE
    l_repo_date  timestamp;
  BEGIN
    SELECT repo_date
      INTO l_repo_date
      FROM packages_last_checked PLC, abi
     WHERE PLC.abi_id  = abi.id
       AND abi.name    = a_abi_name
       AND package_set = a_package_set
       FOR UPDATE OF PLC;

    -- last_checked must always be updated
    -- we set the other fields to null when we have a new repo date
    -- because we haven't imported that repo and we haven't processed it yet.
    -- That assumes import_date and processed_date reflect the repo_date.
    --
    -- A NULL a_RepoDate means the check got no date: usually a 404 because
    -- the repo is gone, sometimes a failed fetch.  missing_since records
    -- the first such check and is kept until a date comes back.
    -- PackagesDeleteForMissingRepos() deletes the packages of repos missing
    -- for long enough.  re https://github.com/FreshPorts/freshports/issues/449
    UPDATE packages_last_checked PLC
       SET last_checked   = CURRENT_TIMESTAMP,
           repo_date      = CASE WHEN repo_date = a_RepoDate THEN repo_date      ELSE a_RepoDate END,
           import_date    = CASE WHEN repo_date = a_RepoDate THEN import_date    ELSE null       END,
           processed_date = CASE WHEN repo_date = a_RepoDate THEN processed_date ELSE null       END,
           missing_since  = CASE WHEN a_RepoDate IS NULL     THEN coalesce(missing_since, CURRENT_TIMESTAMP) ELSE null END
      FROM abi
     WHERE PLC.abi_id  = abi.id
       AND abi.name    = a_abi_name
       AND package_set = a_package_set;

    -- we compare against the value before the update
    RETURN a_RepoDate IS NOT NULL AND l_repo_date IS DISTINCT FROM a_RepoDate;
  END;
$BODY$;

CREATE OR REPLACE FUNCTION PackagesDeleteForMissingRepos(a_grace interval DEFAULT '7 days')
    RETURNS TABLE(abi_name text, package_set package_sets, missing_since timestamp with time zone, deletes integer)
    LANGUAGE sql
    VOLATILE
AS $BODY$
  -- Delete the packages rows of every repo which has had no date from
  -- pkg.freebsd.org (see packages_last_checked.missing_since) for longer
  -- than a_grace.  One package_imports row is written for each repo, so the
  -- deletion shows in the import history.  Returns one row per repo.
  -- re https://github.com/FreshPorts/freshports/issues/449
  WITH gone AS (
    DELETE FROM packages P
     USING packages_last_checked PLC
     WHERE PLC.abi_id        = P.abi_id
       AND PLC.package_set   = P.package_set
       AND PLC.missing_since < CURRENT_TIMESTAMP - a_grace
    RETURNING P.abi_id, P.package_set
  ),
  counts AS (
    SELECT abi_id, package_set, count(*)::integer AS deletes
      FROM gone
     GROUP BY abi_id, package_set
  ),
  logged AS (
    INSERT INTO package_imports (abi_id, package_set, date, inserts, updates, deletes, last_checked, repo_date, import_date, processed_date)
    SELECT C.abi_id, C.package_set, CURRENT_TIMESTAMP, 0, 0, C.deletes,
           PLC.last_checked, PLC.repo_date, PLC.import_date, CURRENT_TIMESTAMP
      FROM counts C
      JOIN packages_last_checked PLC ON PLC.abi_id = C.abi_id AND PLC.package_set = C.package_set
  )
  SELECT abi.name, C.package_set, PLC.missing_since, C.deletes
    FROM counts C
    JOIN abi                       ON abi.id = C.abi_id
    JOIN packages_last_checked PLC ON PLC.abi_id = C.abi_id AND PLC.package_set = C.package_set
   ORDER BY abi.name, C.package_set;
$BODY$;

COMMENT ON FUNCTION PackagesDeleteForMissingRepos(interval) IS 'Deletes the packages rows of repos missing from pkg.freebsd.org for longer than the interval (packages_last_checked.missing_since), logs each in package_imports, returns abi_name, package_set, missing_since, deletes. Called daily by packages-delete-missing-repos.py. See https://github.com/FreshPorts/freshports/issues/449';

COMMIT;
