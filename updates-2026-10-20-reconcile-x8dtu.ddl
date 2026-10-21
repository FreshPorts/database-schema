-- Bring x8dtu's freshports.org (on x8dtu-pg02) in line with production
-- (freshports.org on RDS)
--
-- Schema dumps of every FreshPorts database were compared on 2026-10-20.
-- Production is the reference.  x8dtu differs from it in:
--
--   - pkgmessage search: x8dtu still has the generated column
--     ports.pkgmessage_textsearchable and its index.  Production uses
--     expression indexes instead (ports_pkgmessage_english_idx,
--     ports_pkgmessage_simple_idx) and has no such column.  No website or
--     ingress code refers to it.  The new indexes are built first, then
--     the column (and with it its index) is dropped.
--   - ports_uses_simple_idx: missing
--   - is_utf8(text) in public: only on x8dtu, not used by any code
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
--   CREATE INDEX ports_pkgmessage_textsearchable_idx ON ports USING gin (pkgmessage_textsearchable);
--   DROP INDEX CONCURRENTLY ports_pkgmessage_english_idx;
--   DROP INDEX CONCURRENTLY ports_pkgmessage_simple_idx;
--   DROP INDEX CONCURRENTLY ports_uses_simple_idx;
--   ALTER TABLE users ALTER COLUMN max_number_watch_lists SET DEFAULT 5;
--   ALTER TABLE report_subscriptions_abi DROP CONSTRAINT report_subscriptions_abi_user_abi_watch_pk,
--     ADD CONSTRAINT report_subscriptions_abi_user_abi_watch_pk UNIQUE NULLS NOT DISTINCT (user_id, watch_list_id, abi_id, package_set);
--   COMMENT ON CONSTRAINT report_subscriptions_abi_user_abi_watch_pk ON report_subscriptions_abi
--     IS 'For a given row: user_id, watch_list_id, abi_id, & package_set must be unique.';
--   is_utf8(text): see the 2026-10-20 schema dump of x8dtu (LANGUAGE sql
--   regex check on encode(convert_to($1,'SQL_ASCII'),'hex')).
--   (adding the generated column back rewrites ports)

\set ON_ERROR_STOP on

CREATE INDEX CONCURRENTLY IF NOT EXISTS ports_pkgmessage_english_idx ON ports USING gin (to_tsvector('english'::regconfig, pkgmessage));
CREATE INDEX CONCURRENTLY IF NOT EXISTS ports_pkgmessage_simple_idx  ON ports USING gin (to_tsvector('simple'::regconfig, pkgmessage));
CREATE INDEX CONCURRENTLY IF NOT EXISTS ports_uses_simple_idx        ON ports USING gin (to_tsvector('simple'::regconfig, uses));

BEGIN;

ALTER TABLE ports DROP COLUMN pkgmessage_textsearchable;

DROP FUNCTION public.is_utf8(text);

ALTER TABLE users ALTER COLUMN max_number_watch_lists SET DEFAULT 10;

ALTER TABLE report_subscriptions_abi DROP CONSTRAINT report_subscriptions_abi_user_abi_watch_pk,
  ADD CONSTRAINT report_subscriptions_abi_user_abi_watch_pk UNIQUE (user_id, watch_list_id, abi_id, package_set);
COMMENT ON CONSTRAINT report_subscriptions_abi_user_abi_watch_pk ON report_subscriptions_abi
  IS 'For a given row: user_id, watch_list_id, abi_id, & package_set must be unique.';

COMMIT;
