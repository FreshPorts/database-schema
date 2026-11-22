-- PageLoadSummaryUpdate(): rerunning for the same date no longer fails
--
-- The daily periodic 220.fp_daily_rendering_times runs
-- daily_rendering_times.pl, which calls PageLoadSummaryUpdate(date) to
-- write one page_load_summary row per (date, page_name).  It was a plain
-- INSERT, so a second run for the same date (a rerun of the periodic, or
-- a manual run) died with a duplicate key on page_loads_date_date.
--
-- The new version ends with ON CONFLICT (date, page_name) DO UPDATE: a
-- rerun recomputes that date's totals from page_load_detail.  The first
-- run for a date gives the same rows as before, so nothing anyone sees
-- changes.  For a date whose page_load_detail is already purged (older
-- than 7 days) it finds no rows and leaves the summary alone.
--
-- Tested on freshports.dvl 2026-11-22 inside BEGIN/ROLLBACK: two calls for
-- the same date in a row, no error.
--
-- Run as postgres, which owns the function.  CREATE OR REPLACE keeps its
-- owner and grants.  No script or website change is needed; deploy order
-- does not matter.
--
-- Function definition is also in sp.txt (cd25c23).
--
-- To undo, restore the previous version:
--   git show cd25c23~1:sp.txt, CREATE OR REPLACE FUNCTION PageLoadSummaryUpdate(date)

\set ON_ERROR_STOP on

BEGIN;

CREATE OR REPLACE FUNCTION PageLoadSummaryUpdate(date) returns int AS $$
   DECLARE
       l_RowCount   int;

   BEGIN
   INSERT INTO page_load_summary (date, page_name, total, users, rendering_time_min, rendering_time_max, rendering_time_avg)
      SELECT date,
             CASE WHEN page_name = '/missing.php' THEN
                CASE WHEN position('?' in full_url) != 0 THEN
                   substring(full_url from 0 for position('?' in full_url))
                ELSE
                    CASE WHEN position('cgi-bin/ads/' in full_url) = 0 THEN
                        full_url
                     ELSE
                        substring(full_url from 0 for position('%20' in full_url))
                     END
                END
                ELSE page_name
             END,
             count(*)            AS total,
             count(user_id)      AS users,
             min(rendering_time) AS min,
             max(rendering_time) AS max,
             avg(rendering_time) AS avg
        FROM page_load_detail
       WHERE date = $1
    GROUP BY 1, 2
    -- Running this twice for the same date (a rerun of the daily periodic,
    -- or a manual run) used to fail with a duplicate key on
    -- page_loads_date_date (date, page_name).  Now a rerun recomputes that
    -- date's totals from page_load_detail and overwrites them.
    --
    -- Dates older than 7 days: after calling this function,
    -- daily_rendering_times.pl deletes page_load_detail rows dated more
    -- than 7 days before the date it just summarized.  For such a date the
    -- SELECT above finds no rows, so nothing is inserted or updated, the
    -- existing page_load_summary rows for that date are kept, and the
    -- function returns 0.  This is why this is an upsert and not DELETE
    -- then INSERT: that would delete the summary for an old date and have
    -- no detail left to rebuild it from.
    ON CONFLICT (date, page_name) DO UPDATE
       SET total              = EXCLUDED.total,
           users              = EXCLUDED.users,
           rendering_time_min = EXCLUDED.rendering_time_min,
           rendering_time_max = EXCLUDED.rendering_time_max,
           rendering_time_avg = EXCLUDED.rendering_time_avg;

    GET DIAGNOSTICS l_RowCount = ROW_COUNT;

    return l_RowCount;

    END;
$$  LANGUAGE 'plpgsql';

COMMIT;
