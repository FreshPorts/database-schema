-- Bring freshports.test in line with production (freshports.org on RDS)
--
-- Schema dumps of every FreshPorts database were compared on 2026-10-20.
-- Production is the reference.  freshports.test differs from it in:
--
--   - port_dependencies_upon_type_idx: missing
--   - schema utf8, with badutf8(text), is_double_utf8(text), is_utf8(text):
--     only on test, not used by any code
--   - users.max_number_watch_lists: DEFAULT 5; production has DEFAULT 10
--   - report_subscriptions_abi_user_abi_watch_pk: UNIQUE NULLS NOT DISTINCT;
--     production has plain UNIQUE.  All four columns are NOT NULL, so the
--     two behave the same; this only makes the definitions match.
--
-- Run as the database owner.  CREATE INDEX CONCURRENTLY cannot run inside
-- a transaction, so it comes first, on its own.
--
-- To undo:
--   DROP INDEX CONCURRENTLY port_dependencies_upon_type_idx;
--   ALTER TABLE users ALTER COLUMN max_number_watch_lists SET DEFAULT 5;
--   ALTER TABLE report_subscriptions_abi DROP CONSTRAINT report_subscriptions_abi_user_abi_watch_pk,
--     ADD CONSTRAINT report_subscriptions_abi_user_abi_watch_pk UNIQUE NULLS NOT DISTINCT (user_id, watch_list_id, abi_id, package_set);
--   COMMENT ON CONSTRAINT report_subscriptions_abi_user_abi_watch_pk ON report_subscriptions_abi
--     IS 'For a given row: user_id, watch_list_id, abi_id, & package_set must be unique.';
--   The utf8 schema and its three functions: see the 2026-10-20 schema dump
--   of freshports.test (they are copies of the well-known is_utf8 /
--   is_double_utf8 / badutf8 regex checks, LANGUAGE sql).

\set ON_ERROR_STOP on

CREATE INDEX CONCURRENTLY IF NOT EXISTS port_dependencies_upon_type_idx ON port_dependencies USING btree (port_id_dependent_upon, dependency_type, port_id);

BEGIN;

DROP FUNCTION utf8.badutf8(text);
DROP FUNCTION utf8.is_double_utf8(text);
DROP FUNCTION utf8.is_utf8(text);
DROP SCHEMA utf8;

ALTER TABLE users ALTER COLUMN max_number_watch_lists SET DEFAULT 10;

ALTER TABLE report_subscriptions_abi DROP CONSTRAINT report_subscriptions_abi_user_abi_watch_pk,
  ADD CONSTRAINT report_subscriptions_abi_user_abi_watch_pk UNIQUE (user_id, watch_list_id, abi_id, package_set);
COMMENT ON CONSTRAINT report_subscriptions_abi_user_abi_watch_pk ON report_subscriptions_abi
  IS 'For a given row: user_id, watch_list_id, abi_id, & package_set must be unique.';

COMMIT;
