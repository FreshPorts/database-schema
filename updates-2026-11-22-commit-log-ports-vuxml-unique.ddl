-- commit_log_ports_vuxml: delete duplicate marks, then make them impossible
--
-- See https://github.com/FreshPorts/ingress-modules/issues/3
--
-- vuxml_mark_commits.pm marked a port version once for each range of a
-- vuln it fell in, not once per vuln, so the same (commit_log_id, port_id,
-- vuxml_id) was stored many times: 33,719 extra rows on freshports.dvl.
-- On a port's commit history the vuln icon then linked to the same vuln
-- several times.  Vuln counts were not affected; they use distinct.
--
-- This keeps the oldest row of each group, deletes the rest, and adds a
-- unique constraint so duplicates cannot come back.
--
-- PREREQUISITE: the ingress host for this database must already run the
-- vuxml_mark_commits.pm with the issue #3 fix (each vuln marked once, both
-- inserts ending in ON CONFLICT DO NOTHING).  The old code inserts
-- duplicates on purpose; with this constraint in place that would be an
-- error, aborting a VuXML update or the processing of a commit.
--
-- What anyone sees: each port that had duplicates is queued in
-- cache_clearing_ports by the commit_log_ports_vuxml_clear_cache trigger
-- (once per port, however many rows go) and fp-listen is notified, so those
-- port pages are rebuilt with one link per vuln.
--
-- Locking: the LOCK blocks writes to the table (ingress only) for the
-- whole transaction; the website can still read it until ADD CONSTRAINT,
-- which blocks reads too while the index builds.  On dvl that is a few
-- seconds at most.
--
-- The new index leads with commit_log_id.  The table had no index on that
-- column (only on id, port_id and vuxml_id), so lookups by commit can now
-- use it too.
--
-- Run as postgres, so the new index is owned by postgres.
--
-- Also in createdb.sql.
--
-- To undo (the deleted rows are not restored; they were duplicates):
--   ALTER TABLE commit_log_ports_vuxml
--     DROP CONSTRAINT commit_log_ports_vuxml_commit_port_vuxml_key;

\set ON_ERROR_STOP on

BEGIN;

LOCK TABLE commit_log_ports_vuxml IN SHARE ROW EXCLUSIVE MODE;

\echo duplicate rows before:
SELECT count(*) - count(DISTINCT (commit_log_id, port_id, vuxml_id)) AS duplicate_rows
  FROM commit_log_ports_vuxml;

DELETE FROM commit_log_ports_vuxml c
 USING commit_log_ports_vuxml k
 WHERE c.commit_log_id = k.commit_log_id
   AND c.port_id       = k.port_id
   AND c.vuxml_id      = k.vuxml_id
   AND c.id            > k.id;

-- fails, and rolls back the DELETE too, if any duplicate is left
ALTER TABLE commit_log_ports_vuxml
  ADD CONSTRAINT commit_log_ports_vuxml_commit_port_vuxml_key
  UNIQUE (commit_log_id, port_id, vuxml_id);

COMMIT;
