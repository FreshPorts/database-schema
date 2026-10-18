-- watchers_also_watched: precompute "People watching this port, also watch:"
--
-- WatchersAlsoWatched() used to aggregate watch_list_element on every
-- call: ~150 ms for devel/gmake, and it runs once per port on port,
-- search, category and index pages.  It now reads the top 5 per element
-- from watchers_also_watched, rebuilt nightly.  Lookups take ~0.2 ms.
--
-- Changes from the old function:
--   - only ports in ports_active are ranked, so deleted ports no longer
--     use up places (pages used to show fewer than 5 links, often none)
--   - ties are broken by element_id, so the result is deterministic
--   - lists with more than 5000 ports are left out: a list watching
--     nearly everything says nothing about what is watched together
--   - output is ordered by rank
--
-- The url is still built at read time from ports_active, so changes to
-- short_description and package_name show immediately.
--
-- Rebuilt nightly by scripts/watchers_also_watched_rebuild.pl, run from
-- periodics daily/230.fp_watchers_also_watched
-- (fp_watchers_also_watched_enable="YES").  About a minute on dvl
-- (24,297 elements).  By hand:
--
--   SELECT watchers_also_watched_rebuild_start();     -- once
--   SELECT watchers_also_watched_rebuild_batch(500);  -- repeat, committing, until 0
--
-- Function definitions are also in sp.txt, grants in permissions.sql.
--
-- To undo:
--   CREATE OR REPLACE FUNCTION WatchersAlsoWatched(int) RETURNS SETOF also_watched_record AS $$
--   SELECT * FROM WatchersAlsoWatched_live($1);
--   $$ LANGUAGE SQL STABLE;

\set ON_ERROR_STOP on

BEGIN;

-- The top 5 per element. Rank 1 = most lists in common.
-- No FKs: the reader joins ports_active, which drops deleted/inactive ports.
CREATE TABLE watchers_also_watched (
    element_id        integer   NOT NULL,
    rank              smallint  NOT NULL CHECK (rank BETWEEN 1 AND 5),
    also_element_id   integer   NOT NULL,
    watch_list_count  integer   NOT NULL,
    PRIMARY KEY (element_id, rank)
);

-- Lists too large to say anything about what people watch together
-- (e.g. a list watching nearly every port). Filled by rebuild_start().
CREATE TABLE watchers_also_watched_excluded_lists (
    watch_list_id  integer  PRIMARY KEY,
    elements       integer  NOT NULL
);

-- Elements still to be recomputed in the current rebuild.
CREATE TABLE watchers_also_watched_queue (
    element_id  integer  PRIMARY KEY
);


-- The original function, kept for verification and for rollback.
CREATE OR REPLACE FUNCTION WatchersAlsoWatched_live(int) RETURNS SETOF also_watched_record AS $$
SELECT O.element_id as element_id,
       '<a href="/' || P.Category || '/' || P.name || '/" TITLE="' || replace(P.short_description, '"', E'\'') || E'\">'
                           || P.package_name || '</a>' as url
  FROM ports_active P JOIN (
     SELECT W.element_id
       FROM watch_list_element W
      WHERE w.watch_list_id in (select watch_list_id from watch_list_element where element_id = $1)
        AND W.element_id != $1
   GROUP BY W.element_id
   ORDER BY count(W.watch_list_id) DESC
      LIMIT 5) AS O ON P.element_id = O.element_id;
$$ LANGUAGE SQL STABLE;


-- The new reader: same output as the original, from the stored rows. The
-- url is built here, at read time, so description/package_name changes show
-- immediately, and a port that became inactive since the last rebuild drops
-- out straight away.
-- Ordered by rank (the original had no ORDER BY).
CREATE OR REPLACE FUNCTION WatchersAlsoWatched_stored(int) RETURNS SETOF also_watched_record AS $$
SELECT W.also_element_id AS element_id,
       '<a href="/' || P.Category || '/' || P.name || '/" TITLE="' || replace(P.short_description, '"', E'\'') || E'\">'
                           || P.package_name || '</a>' AS url
  FROM watchers_also_watched W JOIN ports_active P ON P.element_id = W.also_element_id
 WHERE W.element_id = $1
 ORDER BY W.rank;
$$ LANGUAGE SQL STABLE;


-- Recompute one element: the original inner query, skipping excluded
-- lists, keeping only ports in ports_active *before* taking the top 5
-- (the original filtered after, so deleted ports used up places and pages
-- showed fewer than 5, often none), with element_id as a tie-breaker so
-- the result is deterministic.
-- An element on no (non-excluded) lists ends up with no rows.
--
-- The candidates are sorted first and checked against ports_active one at
-- a time, stopping at 5. OFFSET 0 keeps the sorted subquery from being
-- flattened, and the scalar subquery (unlike EXISTS) is not turned into a
-- join, so it runs only for rows the LIMIT asks for: ~5 checks instead of
-- one per candidate (17,000 for devel/gmake), which made the rebuild 8x slower.
CREATE OR REPLACE FUNCTION watchers_also_watched_refresh_element(p_element_id integer) RETURNS void AS $$
DELETE FROM watchers_also_watched
 WHERE element_id = p_element_id;

INSERT INTO watchers_also_watched (element_id, rank, also_element_id, watch_list_count)
SELECT p_element_id,
       row_number() OVER (ORDER BY T.n DESC, T.element_id),
       T.element_id,
       T.n
  FROM (SELECT G.element_id, G.n
          FROM (SELECT W.element_id, count(*) AS n
                  FROM watch_list_element W
                 WHERE W.watch_list_id IN (SELECT L.watch_list_id
                                             FROM watch_list_element L
                                            WHERE L.element_id = p_element_id
                                              AND NOT EXISTS (SELECT 1
                                                                FROM watchers_also_watched_excluded_lists X
                                                               WHERE X.watch_list_id = L.watch_list_id))
                   AND W.element_id <> p_element_id
              GROUP BY W.element_id
              ORDER BY n DESC, W.element_id
                OFFSET 0) AS G
         WHERE (SELECT true FROM ports_active P WHERE P.element_id = G.element_id LIMIT 1)
      ORDER BY G.n DESC, G.element_id
         LIMIT 5) AS T;
$$ LANGUAGE SQL VOLATILE;


-- Start a rebuild: decide which lists are excluded, and queue every element
-- that is watched or currently has rows (so ones no longer watched lose them).
-- Returns the number of elements queued. Calling it again restarts the rebuild.
-- p_max_list_size is the one place the size limit lives.
CREATE OR REPLACE FUNCTION watchers_also_watched_rebuild_start(p_max_list_size integer DEFAULT 5000) RETURNS bigint AS $$
DELETE FROM watchers_also_watched_excluded_lists;

INSERT INTO watchers_also_watched_excluded_lists (watch_list_id, elements)
SELECT watch_list_id, count(*)
  FROM watch_list_element
 GROUP BY watch_list_id
HAVING count(*) > p_max_list_size;

DELETE FROM watchers_also_watched_queue;

WITH ins AS (
    INSERT INTO watchers_also_watched_queue (element_id)
    SELECT element_id
      FROM (SELECT element_id FROM watch_list_element
             UNION
            SELECT element_id FROM watchers_also_watched) AS e
    RETURNING 1)
SELECT count(*) FROM ins;
$$ LANGUAGE SQL VOLATILE;


-- Recompute up to p_limit queued elements; returns how many were done
-- (0 = queue empty, or another rebuild holds the lock).
-- Call repeatedly, committing between calls, until it returns 0. Readers
-- keep seeing each element's old rows until its batch commits.
CREATE OR REPLACE FUNCTION watchers_also_watched_rebuild_batch(p_limit integer DEFAULT 500) RETURNS integer AS $$
DECLARE
    l_elements  integer[];
    l_element   integer;
BEGIN
    IF NOT pg_try_advisory_xact_lock(hashtext('watchers_also_watched_rebuild')) THEN
        RETURN 0;
    END IF;

    WITH claimed AS (
        DELETE FROM watchers_also_watched_queue
         WHERE element_id IN (SELECT element_id
                                FROM watchers_also_watched_queue
                            ORDER BY element_id
                               LIMIT p_limit)
     RETURNING element_id)
    SELECT array_agg(element_id ORDER BY element_id) INTO l_elements FROM claimed;

    IF l_elements IS NULL THEN
        RETURN 0;
    END IF;

    FOREACH l_element IN ARRAY l_elements LOOP
        PERFORM watchers_also_watched_refresh_element(l_element);
    END LOOP;

    RETURN cardinality(l_elements);
END;
$$ LANGUAGE plpgsql VOLATILE;


-- website reads; ingress (commits) rebuilds
GRANT SELECT ON watchers_also_watched TO GROUP www;
GRANT SELECT ON watchers_also_watched TO GROUP reading;
GRANT SELECT, INSERT, UPDATE, DELETE ON watchers_also_watched                TO GROUP commits;
GRANT SELECT, INSERT, UPDATE, DELETE ON watchers_also_watched_excluded_lists TO GROUP commits;
GRANT SELECT, INSERT, UPDATE, DELETE ON watchers_also_watched_queue          TO GROUP commits;

-- Point the website's function at the stored rows. Until the first
-- rebuild has run, the table is empty and port pages show no
-- "also watch" line, so run a rebuild straight after applying this
-- (see the header).
CREATE OR REPLACE FUNCTION WatchersAlsoWatched(int) RETURNS SETOF also_watched_record AS $$
SELECT * FROM WatchersAlsoWatched_stored($1);
$$ LANGUAGE SQL STABLE;

COMMIT;
