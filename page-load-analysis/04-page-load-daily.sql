-- PROPOSAL: a daily rollup with percentiles, per page class and logged-in/anonymous.
-- page_load_summary keeps only avg/min/max per script, so it cannot separate
-- category from port pages (both are the URL parser) or one search type from
-- another, and its daily average is dominated by the slow tail.
--
-- Install (once):   psql -X -f 04-page-load-daily.sql
-- Backfill what page_load_detail still holds (do this before the nightly job
-- deletes more days):
--   SELECT d::date, page_load_daily_update(d::date)
--     FROM generate_series('2026-10-09'::date, current_date - 1, '1 day') d;
-- Daily: call page_load_daily_update(<yesterday>) next to PageLoadSummaryUpdate
-- in daily_rendering_times.pl, before its DELETE.

BEGIN;

-- Page class from page_name + full_url.
-- nginx try_files sends /<category>/ and /<category>/<port>/ to the URL parser.
CREATE OR REPLACE FUNCTION page_load_class(p_page_name text, p_full_url text)
RETURNS text
LANGUAGE sql IMMUTABLE PARALLEL SAFE
AS $$
  SELECT CASE
    WHEN p_page_name IN ('/--/new-url-parsing.php', '/--/index.php') THEN
      CASE
        WHEN split_part(p_full_url, '?', 1) ~ '^/[^/]+/?$'       THEN 'category'
        WHEN split_part(p_full_url, '?', 1) ~ '^/[^/]+/[^/]+/?$' THEN 'port'
        ELSE p_page_name
      END
    WHEN p_page_name = '/search.php' AND p_full_url ~ '[?&]query=[^&]' THEN
      'search:'
      || coalesce(nullif(substring(p_full_url FROM '[?&]stype=([^&#]*)'),  ''), 'name') || ':'
      || coalesce(nullif(substring(p_full_url FROM '[?&]method=([^&#]*)'), ''), 'match')
    ELSE p_page_name
  END
$$;

CREATE TABLE IF NOT EXISTS page_load_daily (
    date       date    NOT NULL,
    page       text    NOT NULL,
    logged_in  boolean NOT NULL,
    views      integer NOT NULL,
    ips        integer NOT NULL,
    avg_s      numeric(10,3) NOT NULL,
    p50_s      numeric(10,3) NOT NULL,
    p95_s      numeric(10,3) NOT NULL,
    p99_s      numeric(10,3) NOT NULL,
    max_s      numeric(10,3) NOT NULL,
    PRIMARY KEY (date, page, logged_in)
);

-- Rebuilds one day; safe to re-run.
CREATE OR REPLACE FUNCTION page_load_daily_update(p_date date)
RETURNS integer
LANGUAGE plpgsql
AS $$
DECLARE
    l_RowCount integer;
BEGIN
    DELETE FROM page_load_daily WHERE date = p_date;

    INSERT INTO page_load_daily (date, page, logged_in, views, ips,
                                 avg_s, p50_s, p95_s, p99_s, max_s)
    SELECT date,
           page_load_class(page_name, full_url),
           user_id IS NOT NULL,
           count(*),
           count(DISTINCT ip_address),
           avg(secs),
           percentile_cont(0.50) WITHIN GROUP (ORDER BY secs),
           percentile_cont(0.95) WITHIN GROUP (ORDER BY secs),
           percentile_cont(0.99) WITHIN GROUP (ORDER BY secs),
           max(secs)
      FROM (SELECT date, page_name, full_url, user_id, ip_address,
                   extract(epoch FROM rendering_time) AS secs
              FROM page_load_detail
             WHERE date = p_date) d
     GROUP BY 1, 2, 3;

    GET DIAGNOSTICS l_RowCount = ROW_COUNT;
    RETURN l_RowCount;
END;
$$;

-- The daily job connects as a member of group commits (see configuration/POSTGRESQL.sql).
GRANT SELECT, INSERT, DELETE ON page_load_daily TO GROUP commits;

COMMIT;
