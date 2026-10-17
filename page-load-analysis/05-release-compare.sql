-- Compare N days before vs N days after a release, from page_load_daily (04).
-- Run:  psql -X -v release=2026-10-17 -v days=7 -f 05-release-compare.sql
-- The release day itself is left out of both windows.
-- Daily percentiles cannot be merged exactly; these are view-weighted means of the daily values.

\if :{?release}
\else
  \set release '2026-10-17'
\endif
\if :{?days}
\else
  \set days 7
\endif

WITH w AS (
  SELECT CASE WHEN date < :'release'::date THEN 'before' ELSE 'after' END AS period, *
    FROM page_load_daily
   WHERE date BETWEEN :'release'::date - :days AND :'release'::date + :days
     AND date <> :'release'::date
),
a AS (
  SELECT page, logged_in, period,
         sum(views)                                  AS views,
         round(sum(p50_s * views) / sum(views), 3)   AS p50_s,
         round(sum(p95_s * views) / sum(views), 3)   AS p95_s,
         max(max_s)                                  AS max_s
    FROM w GROUP BY 1, 2, 3
)
SELECT b.page, b.logged_in,
       b.views AS views_before, f.views AS views_after,
       b.p50_s AS p50_before,   f.p50_s AS p50_after,
       b.p95_s AS p95_before,   f.p95_s AS p95_after,
       round(b.p95_s / nullif(f.p95_s, 0), 1) AS p95_speedup,
       b.max_s AS max_before,   f.max_s AS max_after
  FROM a b
  LEFT JOIN a f ON f.page = b.page AND f.logged_in = b.logged_in AND f.period = 'after'
 WHERE b.period = 'before'
   AND b.views + coalesce(f.views, 0) >= 20
 ORDER BY b.views DESC;
