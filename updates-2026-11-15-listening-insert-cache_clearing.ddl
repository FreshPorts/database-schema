-- let fp-listen put a queue row back
--
-- fp-listen 2.1.0 deletes a row from a cache_clearing_* queue before it
-- removes that row's cached files.  If the files cannot all be removed, it
-- inserts the row again, so the pages are cleared on a later try.  The
-- listening role can only select and delete, so that insert fails with
-- "permission denied", the row is lost, and the pages stay stale until the
-- next commit to that port.  Nothing changes when the removal succeeds.
--
-- cache_clearing_ports and cache_clearing_dates take their ids from serial
-- sequences, so the insert needs those too.  cache_clearing_files uses an
-- identity column and cache_clearing_commits has no id: no sequence needed.
--
-- The select and delete grants on cache_clearing_files and
-- cache_clearing_commits were never in permissions.sql, though fp-listen
-- has always used them; they are repeated here and are harmless if present.
--
-- Run as postgres, on every database.

grant select, delete on cache_clearing_files   to group listening;
grant select, delete on cache_clearing_commits to group listening;

grant insert on cache_clearing_ports, cache_clearing_files,
                cache_clearing_dates, cache_clearing_commits to group listening;
grant usage on sequence cache_clearing_ports_id_seq,
                        cache_clearing_dates_id_seq to group listening;
