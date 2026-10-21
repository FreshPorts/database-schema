-- Bring freshports.stage in line with production (freshports.org on RDS)
--
-- Schema dumps of every FreshPorts database were compared on 2026-10-20.
-- Production is the reference.  freshports.stage differs from it in:
--
--   - element_name_trgm_idx: missing
--   - pkgmessage search: stage still has the generated columns
--     ports.pkgmessage_textsearchable and pkgmessage_textsearchable2, with
--     an index on each.  Production uses expression indexes instead
--     (ports_pkgmessage_english_idx, ports_pkgmessage_simple_idx) and has
--     no such columns.  No website or ingress code refers to the columns.
--     The new indexes are built first, then the columns (and with them
--     their indexes) are dropped.
--   - wlc: missing (production has it; nothing uses it)
--   - plpgsql_call_handler() in public: a leftover from old PostgreSQL
--     releases; the plpgsql language uses pg_catalog's own handler
--   - users.max_number_watch_lists: DEFAULT 5; production has DEFAULT 10
--   - report_subscriptions_abi_user_abi_watch_pk: UNIQUE NULLS NOT DISTINCT;
--     production has plain UNIQUE.  All four columns are NOT NULL, so the
--     two behave the same; this only makes the definitions match.
--   - the comment on commit_log.commit_hash_short has '-- ' before its
--     last line
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
--   DROP INDEX CONCURRENTLY element_name_trgm_idx;
--   DROP INDEX CONCURRENTLY ports_pkgmessage_english_idx;
--   DROP INDEX CONCURRENTLY ports_pkgmessage_simple_idx;
--   DROP TABLE wlc;
--   CREATE FUNCTION plpgsql_call_handler() RETURNS language_handler
--     LANGUAGE c AS '$libdir/plpgsql', 'plpgsql_call_handler';
--   ALTER TABLE users ALTER COLUMN max_number_watch_lists SET DEFAULT 5;
--   ALTER TABLE report_subscriptions_abi DROP CONSTRAINT report_subscriptions_abi_user_abi_watch_pk,
--     ADD CONSTRAINT report_subscriptions_abi_user_abi_watch_pk UNIQUE NULLS NOT DISTINCT (user_id, watch_list_id, abi_id, package_set);
--   COMMENT ON CONSTRAINT report_subscriptions_abi_user_abi_watch_pk ON report_subscriptions_abi
--     IS 'For a given row: user_id, watch_list_id, abi_id, & package_set must be unique.';
--   (adding the generated columns back rewrites ports)

\set ON_ERROR_STOP on

CREATE INDEX CONCURRENTLY IF NOT EXISTS element_name_trgm_idx        ON element USING gin (name gin_trgm_ops);
CREATE INDEX CONCURRENTLY IF NOT EXISTS ports_pkgmessage_english_idx ON ports   USING gin (to_tsvector('english'::regconfig, pkgmessage));
CREATE INDEX CONCURRENTLY IF NOT EXISTS ports_pkgmessage_simple_idx  ON ports   USING gin (to_tsvector('simple'::regconfig, pkgmessage));

BEGIN;

ALTER TABLE ports DROP COLUMN pkgmessage_textsearchable2,
                  DROP COLUMN pkgmessage_textsearchable;

CREATE TABLE wlc (
    name text,
    category text,
    wlc bigint
);

DROP FUNCTION public.plpgsql_call_handler();

ALTER TABLE users ALTER COLUMN max_number_watch_lists SET DEFAULT 10;

ALTER TABLE report_subscriptions_abi DROP CONSTRAINT report_subscriptions_abi_user_abi_watch_pk,
  ADD CONSTRAINT report_subscriptions_abi_user_abi_watch_pk UNIQUE (user_id, watch_list_id, abi_id, package_set);
COMMENT ON CONSTRAINT report_subscriptions_abi_user_abi_watch_pk ON report_subscriptions_abi
  IS 'For a given row: user_id, watch_list_id, abi_id, & package_set must be unique.';

COMMENT ON COLUMN commit_log.commit_hash_short IS 'This is the short version of the git hash stored in
 svn_revision.

If null/empty, it is not a git hash.';

COMMIT;
