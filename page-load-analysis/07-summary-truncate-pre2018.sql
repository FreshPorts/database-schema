-- Step 2 of 2: keep only rows from 2018 on in page_load_summary. Run only after 06's export checks out.
-- TRUNCATE keeps the table's grants, sequence and indexes, and frees the space at COMMIT.
-- Takes an ACCESS EXCLUSIVE lock on page_load_summary for the few seconds this runs
-- (only the nightly job writes to it).
--   psql -X -f 07-summary-truncate-pre2018.sql

\timing on
\set ON_ERROR_STOP on

SELECT pg_size_pretty(pg_total_relation_size('page_load_summary')) AS size_before;

BEGIN;
CREATE TEMP TABLE keep ON COMMIT DROP AS
  SELECT * FROM page_load_summary WHERE date >= '2018-01-01';
SELECT count(*) AS kept FROM keep;                -- expect 126,732 (as of 2026-10-17) plus later days
TRUNCATE page_load_summary;
INSERT INTO page_load_summary SELECT * FROM keep;
COMMIT;

ANALYZE page_load_summary;

SELECT pg_size_pretty(pg_total_relation_size('page_load_summary')) AS size_after,
       min(date), max(date), count(*)
  FROM page_load_summary;
