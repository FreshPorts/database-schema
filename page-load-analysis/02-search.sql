-- Search timing per day / stype / logged-in, and before vs after a release.
-- Run:  psql -X -v since=2026-09-15 -v release='2026-10-17 07:57' -f 02-search.sql
-- Defaults below apply when -v is not given.
--
-- Only fully rendered searches are recorded. Not recorded: login refusals,
-- search-gate challenges, nginx refusals, and single-result searches that
-- redirect to the port page.
-- stype/method default to name/match in search.php when absent from the URL.
-- ts = date + time, in the database's timezone (see SHOW timezone in 01).

\timing on
\if :{?since}
\else
  \set since '2026-09-15'
\endif
\if :{?release}
\else
  \set release '2026-10-17 07:57'
\endif

DROP VIEW IF EXISTS pg_temp.s;
CREATE TEMP VIEW s AS
SELECT date,
       date + time                                        AS ts,
       user_id IS NOT NULL                                AS logged_in,
       ip_address,
       coalesce(nullif(substring(full_url FROM '[?&]stype=([^&#]*)'),  ''), 'name')  AS stype,
       coalesce(nullif(substring(full_url FROM '[?&]method=([^&#]*)'), ''), 'match') AS method,
       extract(epoch FROM rendering_time)                 AS secs
  FROM page_load_detail
 WHERE page_name = '/search.php'
   AND full_url ~ '[?&]query=[^&]'
   AND date >= :'since';

-- 1. Per day: volume, how spread out the sources are, anonymous share
\echo '== 1. search per day'
SELECT date,
       count(*)                                          AS searches,
       count(*) FILTER (WHERE NOT logged_in)             AS anon,
       count(DISTINCT ip_address)                        AS ips,
       count(DISTINCT network(set_masklen(ip_address,
             CASE family(ip_address) WHEN 4 THEN 24 ELSE 48 END))) AS nets,
       round(count(*)::numeric / nullif(count(DISTINCT ip_address), 0), 1) AS per_ip,
       count(*) FILTER (WHERE stype = 'depends_all')     AS depends_all,
       round(avg(secs)::numeric, 2)                      AS avg_s,
       round(percentile_cont(0.5)  WITHIN GROUP (ORDER BY secs)::numeric, 2) AS p50_s,
       round(percentile_cont(0.95) WITHIN GROUP (ORDER BY secs)::numeric, 2) AS p95_s,
       round(max(secs)::numeric, 2)                      AS max_s
  FROM s
 GROUP BY 1 ORDER BY 1;

-- 2. Per day x stype x logged-in
\echo '== 2. search per day, stype, logged-in'
SELECT date, stype, logged_in,
       count(*)                   AS searches,
       count(DISTINCT ip_address) AS ips,
       round(avg(secs)::numeric, 2) AS avg_s,
       round(percentile_cont(0.5)  WITHIN GROUP (ORDER BY secs)::numeric, 2) AS p50_s,
       round(percentile_cont(0.95) WITHIN GROUP (ORDER BY secs)::numeric, 2) AS p95_s,
       round(max(secs)::numeric, 2) AS max_s
  FROM s
 GROUP BY 1, 2, 3 ORDER BY 1, 2, 3;

-- 3. Before vs after the release, per stype x method x logged-in
\echo '== 3. before vs after release'
SELECT CASE WHEN ts < :'release'::timestamp THEN '1 before' ELSE '2 after' END AS period,
       stype, method, logged_in,
       count(*)                   AS searches,
       count(DISTINCT ip_address) AS ips,
       round(avg(secs)::numeric, 3) AS avg_s,
       round(percentile_cont(0.5)  WITHIN GROUP (ORDER BY secs)::numeric, 3) AS p50_s,
       round(percentile_cont(0.95) WITHIN GROUP (ORDER BY secs)::numeric, 3) AS p95_s,
       round(max(secs)::numeric, 3) AS max_s
  FROM s
 GROUP BY 1, 2, 3, 4 ORDER BY 2, 3, 4, 1;

-- 4. Hourly around the changes (10-15 .. now): when anonymous search stopped,
--    when depends_all load dropped, how timings moved through the DB changes and the release
\echo '== 4. hourly since 2026-10-15'
SELECT date_trunc('hour', ts)                    AS hour,
       count(*)                                  AS searches,
       count(*) FILTER (WHERE NOT logged_in)     AS anon,
       count(*) FILTER (WHERE stype = 'depends_all') AS dep_all,
       count(DISTINCT ip_address)                AS ips,
       round(avg(secs)::numeric, 2)              AS avg_s,
       round(percentile_cont(0.95) WITHIN GROUP (ORDER BY secs)::numeric, 2) AS p95_s,
       round(max(secs)::numeric, 2)              AS max_s
  FROM s
 WHERE date >= '2026-10-15'
 GROUP BY 1 ORDER BY 1;

-- 5. Long-run view from page_load_summary (beyond detail's 7-day window).
--    Counts every /search.php render, including the empty search form;
--    anon = total - users.
\echo '== 5. /search.php from page_load_summary'
SELECT date, total, users, total - users AS anon,
       round(extract(epoch FROM rendering_time_avg)::numeric, 2) AS avg_s,
       round(extract(epoch FROM rendering_time_max)::numeric, 2) AS max_s
  FROM page_load_summary
 WHERE page_name = '/search.php'
   AND date >= :'since'
 ORDER BY date;
