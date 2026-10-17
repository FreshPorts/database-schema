-- page_load_detail / page_load_summary: size, date range, what fills them.
-- Run:  psql -X -f 01-inventory.sql
-- Everything here is cheap: catalog lookups, min/max on the date index,
-- and per-day counts over page_load_detail (which the daily job keeps to ~8 days).

\timing on
\pset null '(null)'

SHOW timezone;
SELECT now(), current_date, current_time;

\d page_load_detail
\d page_load_summary

-- The daily job (periodic 220.fp_daily_rendering_times -> daily_rendering_times.pl)
-- calls this for yesterday, then deletes detail rows older than 7 days.
\sf PageLoadSummaryUpdate

-- Sizes and row estimates
SELECT c.relname,
       pg_size_pretty(pg_relation_size(c.oid))       AS heap,
       pg_size_pretty(pg_indexes_size(c.oid))        AS indexes,
       pg_size_pretty(pg_total_relation_size(c.oid)) AS total,
       c.reltuples::bigint                           AS est_rows
  FROM pg_class c
 WHERE c.relname IN ('page_load_detail', 'page_load_summary')
 ORDER BY 1;

-- Insert/delete churn and vacuum state
SELECT relname, n_live_tup, n_dead_tup, n_tup_ins, n_tup_del,
       last_vacuum, last_autovacuum, last_analyze, last_autoanalyze
  FROM pg_stat_user_tables
 WHERE relname IN ('page_load_detail', 'page_load_summary')
 ORDER BY 1;

-- Date ranges (min/max use the date index / the unique (date, page_name) index)
SELECT 'detail'  AS tbl, min(date), max(date) FROM page_load_detail
UNION ALL
SELECT 'summary' AS tbl, min(date), max(date) FROM page_load_summary;

-- Detail rows per day (shows whether pruning is running: expect ~8 days)
SELECT date, count(*) AS rows, count(*) FILTER (WHERE user_id IS NOT NULL) AS logged_in_rows,
       min(time) AS first, max(time) AS last
  FROM page_load_detail
 WHERE date >= current_date - 60
 GROUP BY 1 ORDER BY 1;

-- Summary rows per day for the last 60 days (gaps = days the job did not run)
SELECT date, count(*) AS pages, sum(total) AS views
  FROM page_load_summary
 WHERE date >= current_date - 60
 GROUP BY 1 ORDER BY 1;

-- Which page_name values exist (confirms category/port pages arrive as the URL parser)
SELECT page_name, count(*) AS views,
       round(avg(extract(epoch FROM rendering_time))::numeric, 3) AS avg_s
  FROM page_load_detail
 WHERE date >= current_date - 7
 GROUP BY 1 ORDER BY 2 DESC
 LIMIT 30;
