-- One-off copy of page_load_detail to a gzipped CSV on the CLIENT host, before
-- the nightly job deletes rows older than 7 days.
-- Contains IP addresses and full URLs: the file is created mode 600.
--   psql -X -f 08-detail-export.sql
-- Check:  gzip -t page_load_detail-from-2026-10-09.csv.gz
-- psql does not expand variables inside \copy, so the date is written out twice below;
-- change both for a later export.
--
-- To analyse it later, in one psql session (a temp table shadows the real one,
-- because pg_temp comes first in the search path):
--   CREATE TEMP TABLE page_load_detail (LIKE public.page_load_detail);
--   \copy page_load_detail FROM PROGRAM 'gzip -dc page_load_detail-from-2026-10-09.csv.gz' WITH (FORMAT csv, HEADER)
--   CREATE INDEX ON page_load_detail (date);
--   ANALYZE page_load_detail;
--   \i 02-search.sql
--   \i 03-pages.sql

\timing on

SELECT date, count(*) AS rows FROM page_load_detail WHERE date >= '2026-10-09' GROUP BY 1 ORDER BY 1;

\copy (SELECT * FROM page_load_detail WHERE date >= '2026-10-09' ORDER BY id) TO PROGRAM 'umask 077; gzip -6 > page_load_detail-from-2026-10-09.csv.gz' WITH (FORMAT csv, HEADER)
