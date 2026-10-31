-- drop the tables used by the old *_DEFAULT variable tracking
--
-- default_version_variable and port_default_version_variable came from
-- FreshPorts/DefaultVersions (PostgreSQL/DDL/0100 and 0200), for the
-- process_default_versions.pl approach.  compare-index.sh replaced it,
-- and ingress-scripts 2.3.6 removes the script.  Nothing else reads them.
--
-- None of the schema dumps taken on 2026-10-20 had these tables, so most
-- databases will not.  Everything here uses IF EXISTS and is safe to run
-- on every database.  To see whether a database has them first:
--
--   select relname from pg_class where relname in
--     ('default_version_variable', 'port_default_version_variable');
--
-- Run as postgres, on every database.

begin;

-- port_default_version_variable references default_version_variable,
-- so it goes first.
drop table if exists port_default_version_variable;

-- dropping the table drops trg_default_version_variable_updated_at too
drop table if exists default_version_variable;
drop function if exists default_version_variable_set_updated_at();

commit;
