-- Bring freshports.dvl in line with production (freshports.org on RDS)
--
-- Schema dumps of every FreshPorts database were compared on 2026-10-20.
-- Production is the reference.  freshports.dvl differs from it in:
--
--   - ports_short_description_trgm_idx: missing (every other database has it)
--   - categoryportcount(text): old version joining element_pathname on
--     '/ports/head/%'; production uses ports_active, as sp.txt does
--   - delete_me_daily_refreshes: only on dvl and dev, not used by any code
--   - users.max_number_watch_lists: DEFAULT 5; production has DEFAULT 10
--   - commit_log, commit_log_branches, commit_log_ports: missing the
--     autovacuum_analyze settings applied everywhere else on 2026-10-16/17
--
-- Run as the database owner.  CREATE INDEX CONCURRENTLY cannot run inside
-- a transaction, so it comes first, on its own.
--
-- To undo:
--   DROP INDEX CONCURRENTLY ports_short_description_trgm_idx;
--   ALTER TABLE users ALTER COLUMN max_number_watch_lists SET DEFAULT 5;
--   ALTER TABLE commit_log          RESET (autovacuum_analyze_scale_factor, autovacuum_analyze_threshold);
--   ALTER TABLE commit_log_branches RESET (autovacuum_analyze_scale_factor, autovacuum_analyze_threshold);
--   ALTER TABLE commit_log_ports    RESET (autovacuum_analyze_scale_factor, autovacuum_analyze_threshold);
--   CREATE TABLE delete_me_daily_refreshes (refresh_date date NOT NULL);
--   ALTER TABLE delete_me_daily_refreshes ADD CONSTRAINT daily_refreshes_pkey PRIMARY KEY (refresh_date);
--   CREATE OR REPLACE FUNCTION categoryportcount(text) RETURNS bigint LANGUAGE sql STABLE AS $_$
--           SELECT count(*)
--             FROM categories C
--             JOIN ports_categories PC ON C.id         = PC.category_id
--             JOIN ports            P  ON PC.port_id   = P.id and P.category_id = C.id
--             JOIN element_pathname EP ON P.element_id = EP.element_id AND (EP.pathname LIKE '/ports/head/%')
--             JOIN element          E  ON P.element_id = E.id and E.status = 'A'
--            WHERE C.name   = $1
--   $_$;
--   (delete_me_daily_refreshes comes back empty)

\set ON_ERROR_STOP on

CREATE INDEX CONCURRENTLY IF NOT EXISTS ports_short_description_trgm_idx ON ports USING gin (short_description gin_trgm_ops);

BEGIN;

CREATE OR REPLACE FUNCTION categoryportcount(text) RETURNS bigint
    LANGUAGE sql STABLE
    AS $_$
        SELECT count(*)
          FROM categories C
          JOIN ports_categories PC ON C.id         = PC.category_id
          JOIN ports_active     P  ON PC.port_id   = P.id
         WHERE C.name   = $1;
$_$;

DROP TABLE delete_me_daily_refreshes;

ALTER TABLE users ALTER COLUMN max_number_watch_lists SET DEFAULT 10;

ALTER TABLE commit_log_branches SET (autovacuum_analyze_scale_factor = 0, autovacuum_analyze_threshold = 500);
ALTER TABLE commit_log_ports    SET (autovacuum_analyze_scale_factor = 0, autovacuum_analyze_threshold = 1000);
ALTER TABLE commit_log          SET (autovacuum_analyze_scale_factor = 0, autovacuum_analyze_threshold = 500);

COMMIT;
