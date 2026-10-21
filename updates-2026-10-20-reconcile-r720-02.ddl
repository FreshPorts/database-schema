-- Bring r720-02's freshports.org (on r720-02-pg02) in line with production
-- (freshports.org on RDS)
--
-- Schema dumps of every FreshPorts database were compared on 2026-10-20.
-- Production is the reference.  r720-02 differs from it in:
--
--   - pkgmessage search: r720-02 still has the generated columns
--     ports.pkgmessage_textsearchable and pkgmessage_textsearchable2, with
--     an index on each.  Production uses expression indexes instead
--     (ports_pkgmessage_english_idx, ports_pkgmessage_simple_idx) and has
--     no such columns.  No website or ingress code refers to the columns.
--     The new indexes are built first, then the columns (and with them
--     their indexes) are dropped.
--   - ports_uses_simple_idx: missing
--   - ports.last_commit_id has the same foreign key three times:
--     ports_last_commit_id_fkey, _fkey8 and _fkey9.  Likely from running
--     ri.txt more than once: its ADD FOREIGN KEY had no constraint name.
--     _fkey8 and _fkey9 are dropped.
--   - users.max_number_watch_lists: DEFAULT 5; production has DEFAULT 10
--   - report_subscriptions_abi_user_abi_watch_pk: UNIQUE NULLS NOT DISTINCT;
--     production has plain UNIQUE.  All four columns are NOT NULL, so the
--     two behave the same; this only makes the definitions match.
--
-- Run as the database owner.  CREATE INDEX CONCURRENTLY cannot run inside
-- a transaction, so the indexes come first, on their own.  Dropping a
-- generated column does not rewrite the table.
--
-- To undo:
--   ALTER TABLE ports ADD COLUMN pkgmessage_textsearchable tsvector
--     GENERATED ALWAYS AS (to_tsvector('english'::regconfig, pkgmessage)) STORED;
--   ALTER TABLE ports ADD COLUMN pkgmessage_textsearchable2 tsvector
--     GENERATED ALWAYS AS (to_tsvector('english'::regconfig, translate(pkgmessage, '/'::text, ' '::text))) STORED;
--   CREATE INDEX ports_pkgmessage_textsearchable_idx  ON ports USING gin (pkgmessage_textsearchable);
--   CREATE INDEX ports_pkgmessage_textsearchable2_idx ON ports USING gin (pkgmessage_textsearchable2);
--   DROP INDEX CONCURRENTLY ports_pkgmessage_english_idx;
--   DROP INDEX CONCURRENTLY ports_pkgmessage_simple_idx;
--   DROP INDEX CONCURRENTLY ports_uses_simple_idx;
--   ALTER TABLE users ALTER COLUMN max_number_watch_lists SET DEFAULT 5;
--   ALTER TABLE report_subscriptions_abi DROP CONSTRAINT report_subscriptions_abi_user_abi_watch_pk,
--     ADD CONSTRAINT report_subscriptions_abi_user_abi_watch_pk UNIQUE NULLS NOT DISTINCT (user_id, watch_list_id, abi_id, package_set);
--   COMMENT ON CONSTRAINT report_subscriptions_abi_user_abi_watch_pk ON report_subscriptions_abi
--     IS 'For a given row: user_id, watch_list_id, abi_id, & package_set must be unique.';
--   (the duplicate foreign keys are not worth restoring; adding the
--   generated columns back rewrites ports)

\set ON_ERROR_STOP on

CREATE INDEX CONCURRENTLY IF NOT EXISTS ports_pkgmessage_english_idx ON ports USING gin (to_tsvector('english'::regconfig, pkgmessage));
CREATE INDEX CONCURRENTLY IF NOT EXISTS ports_pkgmessage_simple_idx  ON ports USING gin (to_tsvector('simple'::regconfig, pkgmessage));
CREATE INDEX CONCURRENTLY IF NOT EXISTS ports_uses_simple_idx        ON ports USING gin (to_tsvector('simple'::regconfig, uses));

BEGIN;

ALTER TABLE ports DROP COLUMN pkgmessage_textsearchable2,
                  DROP COLUMN pkgmessage_textsearchable;

ALTER TABLE ports DROP CONSTRAINT ports_last_commit_id_fkey8,
                  DROP CONSTRAINT ports_last_commit_id_fkey9;

ALTER TABLE users ALTER COLUMN max_number_watch_lists SET DEFAULT 10;

ALTER TABLE report_subscriptions_abi DROP CONSTRAINT report_subscriptions_abi_user_abi_watch_pk,
  ADD CONSTRAINT report_subscriptions_abi_user_abi_watch_pk UNIQUE (user_id, watch_list_id, abi_id, package_set);
COMMENT ON CONSTRAINT report_subscriptions_abi_user_abi_watch_pk ON report_subscriptions_abi
  IS 'For a given row: user_id, watch_list_id, abi_id, & package_set must be unique.';

COMMIT;
