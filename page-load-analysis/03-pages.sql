-- Non-search pages, before vs after a release.
-- Run:  psql -X -v since=2026-09-15 -v release='2026-10-17 07:57' -f 03-pages.sql
--
-- nginx sends anything that is not a file (/<category>/, /<category>/<port>/)
-- to /--/new-url-parsing.php (try_files), so SCRIPT_NAME is the parser for
-- both; the path in full_url tells them apart.

\timing on
\if :{?since}
\else
  \set since '2026-09-15'
\endif
\if :{?release}
\else
  \set release '2026-10-17 07:57'
\endif

DROP VIEW IF EXISTS pg_temp.p;
CREATE TEMP VIEW p AS
SELECT date,
       date + time         AS ts,
       user_id IS NOT NULL AS logged_in,
       ip_address,
       CASE
         WHEN page_name IN ('/--/new-url-parsing.php', '/--/index.php') THEN
           CASE
             WHEN split_part(full_url, '?', 1) ~ '^/[^/]+/?$'             THEN 'category'
             WHEN split_part(full_url, '?', 1) ~ '^/[^/]+/[^/]+/?$'       THEN 'port'
             ELSE 'parser-other'
           END
         ELSE page_name
       END                 AS page,
       extract(epoch FROM rendering_time) AS secs
  FROM page_load_detail
 WHERE date >= :'since'
   AND page_name IN ('/--/new-url-parsing.php', '/--/index.php', '/index.php',
                     '/ports-new.php', '/ports-broken.php', '/commit.php', '/vuxml.php');

-- 1. Before vs after
\echo '== 1. pages before vs after release'
SELECT page,
       CASE WHEN ts < :'release'::timestamp THEN '1 before' ELSE '2 after' END AS period,
       count(*)                   AS views,
       count(DISTINCT ip_address) AS ips,
       round(avg(secs)::numeric, 3) AS avg_s,
       round(percentile_cont(0.5)  WITHIN GROUP (ORDER BY secs)::numeric, 3) AS p50_s,
       round(percentile_cont(0.95) WITHIN GROUP (ORDER BY secs)::numeric, 3) AS p95_s,
       round(max(secs)::numeric, 3) AS max_s
  FROM p
 GROUP BY 1, 2 ORDER BY 1, 2;

-- 2. Per day
\echo '== 2. pages per day'
SELECT date, page,
       count(*)                   AS views,
       round(avg(secs)::numeric, 3) AS avg_s,
       round(percentile_cont(0.5)  WITHIN GROUP (ORDER BY secs)::numeric, 3) AS p50_s,
       round(percentile_cont(0.95) WITHIN GROUP (ORDER BY secs)::numeric, 3) AS p95_s,
       round(max(secs)::numeric, 3) AS max_s
  FROM p
 GROUP BY 1, 2 ORDER BY 2, 1;

-- 3. Long-run trend from page_load_summary (no category/port or stype split there:
--    the parser and search.php are one row each per day)
\echo '== 3. page_load_summary since 2026-08-01'
SELECT date, page_name, total, users,
       round(extract(epoch FROM rendering_time_avg)::numeric, 3) AS avg_s,
       round(extract(epoch FROM rendering_time_max)::numeric, 3) AS max_s
  FROM page_load_summary
 WHERE date >= '2026-08-01'
   AND page_name IN ('/search.php', '/--/new-url-parsing.php', '/--/index.php', '/index.php',
                     '/ports-new.php', '/ports-broken.php', '/commit.php', '/vuxml.php')
 ORDER BY page_name, date;
