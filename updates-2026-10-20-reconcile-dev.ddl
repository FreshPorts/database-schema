-- Bring freshports.dev in line with production (freshports.org on RDS)
--
-- Schema dumps of every FreshPorts database were compared on 2026-10-20.
-- Production is the reference.  freshports.dev differs from it in:
--
--   - port_dependencies_upon_type_idx: missing
--   - categoryportcount(text): old version joining element_pathname on
--     '/ports/head/%'; production uses ports_active, as sp.txt does
--   - delete_me_daily_refreshes: only on dvl and dev, not used by any code
--   - users.max_number_watch_lists: DEFAULT 5; production has DEFAULT 10
--
-- Run as the database owner.  CREATE INDEX CONCURRENTLY cannot run inside
-- a transaction, so it comes first, on its own.
--
-- To undo:
--   DROP INDEX CONCURRENTLY port_dependencies_upon_type_idx;
--   ALTER TABLE users ALTER COLUMN max_number_watch_lists SET DEFAULT 5;
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

CREATE INDEX CONCURRENTLY IF NOT EXISTS port_dependencies_upon_type_idx ON port_dependencies USING btree (port_id_dependent_upon, dependency_type, port_id);

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

COMMIT;
