-- Step 1 of 2: export page_load_summary rows before 2018 (per-URL rows from the
-- /missing.php era, ~165M rows) to a gzipped CSV on the CLIENT host.
-- Run off-peak: it reads the whole 19 GB heap once.
--   psql -X -f 06-summary-export-pre2018.sql
-- Check afterwards:  gzip -t page_load_summary-2003-2017.csv.gz
--                    gzip -dc page_load_summary-2003-2017.csv.gz | wc -l   (= COPY count + 1 header line)
-- Then run 07.

\timing on

SELECT min(date), max(date) FROM page_load_summary WHERE date < '2018-01-01';

\copy (SELECT * FROM page_load_summary WHERE date < '2018-01-01' ORDER BY date, page_name) TO PROGRAM 'gzip -6 > page_load_summary-2003-2017.csv.gz' WITH (FORMAT csv, HEADER)
