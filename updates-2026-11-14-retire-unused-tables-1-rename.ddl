-- Retire unused tables, stage 1 of 2: rename each to zz_retired_<name>.
--
-- What it does: renames tables that no code uses, so anything that still
-- uses one fails loudly with 'relation "<name>" does not exist' instead
-- of the data going away.  After the waiting period,
-- updates-2026-11-14-retire-unused-tables-2-drop.ddl drops the renamed
-- tables.  Nothing anyone sees on the website changes.
--
-- Every FreshPorts database is separate (dvl, dev, test, stage, r720-02,
-- x8dtu, prod).  Run this once on each, as postgres, in the order
-- dvl -> dev -> test -> stage -> r720-02 -> x8dtu -> prod:
--
--   psql -U postgres -d <db> -f updates-2026-11-14-retire-unused-tables-1-rename.ddl
--
-- It is safe to run more than once.  For each table it checks that:
--   - public.<name> exists (if not, it says so and moves on)
--   - public.zz_retired_<name> does not exist yet
--   - no foreign key in another table points at it
--   - no view depends on it
--   - no function in public reads or writes it by name
-- and skips the table, with a WARNING, if any check fails.  Everything
-- runs in one transaction.
--
-- Each renamed table gets a comment starting 'Retired YYYY-MM-DD'.  The
-- drop script reads that date and refuses to drop a table renamed less
-- than 30 days earlier.  A comment already on the table is kept after it.
--
-- commit_log_port_elements is skipped unless you ask for it:
--
--   psql -U postgres -d <db> -v retire_clpe=1 -f updates-2026-11-14-retire-unused-tables-1-rename.ddl
--
-- Ask for it only on a database whose ingress host runs ingress-modules
-- with commit 0b88269 (verifyport.pm no longer has
-- _RecordPortFilesTouchedByThatCommit).  On 2026-11-14 that is dvl and
-- dev only.  Running the script again later with -v retire_clpe=1 renames
-- just that table; the others are already done.
--
-- Undo, per table, before the drop script has run:
--
--   ALTER TABLE public.zz_retired_<name> RENAME TO <name>;
--   COMMENT ON TABLE public.<name> IS NULL;
--   (users_md5_hash_backup: put its old comment back instead of NULL; it
--   is after 'Previous comment: ' in the retired table's comment)

\set ON_ERROR_STOP on

BEGIN;

-- don't queue behind a long-running query; fail and try again later
SET LOCAL lock_timeout = '10s';

\if :{?retire_clpe}
SELECT set_config('freshports.retire_clpe', 'yes', true);
\endif

DO $retire$
DECLARE
	-- table name => why it is unused (the evidence, short)
	l_tables CONSTANT text[][] := ARRAY[
		['commit_log_port_elements',  'last row 2012-10-23; writer removed in ingress-modules 0b88269; www stopped reading it 2006-11'],
		['commit_log_ports_ignore',   'only user is unrefreshed.pl, which nothing runs; newest row for a 2015-08-13 commit'],
		['users_md5_hash_backup',     'MD5 hashes saved 2026-10-23 so that change could be undone; no code reads it'],
		['commits_latest',            'empty; no code since 2002 (www switched to commits_latest_ports, now latest_commits)'],
		['commits_latest_ports',      'replaced by latest_commits_ports; the name survives only as an alias in commit_log_ports_insert()'],
		['maxcommitid',               'one row; no code, function or view uses it; only postgres and rsyncer can read it'],
		['portcount',                 'one row; no code, function or view uses it; only postgres and rsyncer can read it'],
		['wlc',                       'ad hoc watch-list-count snapshot; no code uses it; only postgres and rsyncer can read it'],
		['watch_notice_log',          'last row 2002-12-24; no code since the 2006 FreshPorts2 merge'],
		['design_results',            '2002-era design vote; its page was removed in www 7d791688 (2020-06-27); include/design-voting/voting.php is included by nothing']
	];
	l_name    text;
	l_why     text;
	l_new     text;
	l_comment text;
	l_problem text;
	l_rows    bigint;
	i         int;
BEGIN
	FOR i IN 1 .. array_length(l_tables, 1) LOOP
		l_name := l_tables[i][1];
		l_why  := l_tables[i][2];
		l_new  := 'zz_retired_' || l_name;

		IF to_regclass('public.' || l_new) IS NOT NULL THEN
			RAISE NOTICE '%: already retired as %, nothing to do', l_name, l_new;
			CONTINUE;
		END IF;

		IF to_regclass('public.' || l_name) IS NULL THEN
			RAISE NOTICE '%: not in this database, nothing to do', l_name;
			CONTINUE;
		END IF;

		IF l_name = 'commit_log_port_elements'
		   AND coalesce(current_setting('freshports.retire_clpe', true), '') <> 'yes' THEN
			RAISE NOTICE '%: skipped; rerun with -v retire_clpe=1 once this host has ingress-modules 0b88269', l_name;
			CONTINUE;
		END IF;

		-- foreign keys from other tables pointing at this one
		SELECT string_agg(conrelid::regclass::text || '.' || conname, ', ')
		  INTO l_problem
		  FROM pg_constraint
		 WHERE contype   = 'f'
		   AND confrelid = ('public.' || l_name)::regclass
		   AND conrelid <> confrelid;
		IF l_problem IS NOT NULL THEN
			RAISE WARNING '%: SKIPPED, referenced by foreign key(s) %', l_name, l_problem;
			CONTINUE;
		END IF;

		-- views (or materialized views) built on it
		SELECT string_agg(DISTINCT v.oid::regclass::text, ', ')
		  INTO l_problem
		  FROM pg_depend d
		  JOIN pg_rewrite r ON r.oid = d.objid
		  JOIN pg_class   v ON v.oid = r.ev_class
		 WHERE d.classid    = 'pg_rewrite'::regclass
		   AND d.refobjid   = ('public.' || l_name)::regclass
		   AND v.oid       <> d.refobjid;
		IF l_problem IS NOT NULL THEN
			RAISE WARNING '%: SKIPPED, used by view(s) %', l_name, l_problem;
			CONTINUE;
		END IF;

		-- functions naming it after FROM, JOIN, INSERT INTO, MERGE INTO, UPDATE,
		-- TABLE, TRUNCATE or COPY.  Not a bare INTO: 'SELECT count(*) INTO
		-- PortCount' in the stats_portcount*() functions is a PL/pgSQL
		-- variable, not the portcount table.  An alias that shares a table's
		-- name ('FROM latest_commits_ports commits_latest_ports' in
		-- commit_log_ports_insert()) follows another table name, so it does
		-- not match either.
		SELECT string_agg(DISTINCT p.proname, ', ')
		  INTO l_problem
		  FROM pg_proc p
		 WHERE p.pronamespace = 'public'::regnamespace
		   AND p.prosrc ~* ('\m(from|join|insert\s+into|merge\s+into|update|table|truncate|copy)\s+(public\.)?' || l_name || '\M');
		IF l_problem IS NOT NULL THEN
			RAISE WARNING '%: SKIPPED, used by function(s) %', l_name, l_problem;
			CONTINUE;
		END IF;

		SELECT n_live_tup INTO l_rows
		  FROM pg_stat_user_tables
		 WHERE relid = ('public.' || l_name)::regclass;

		l_comment := 'Retired ' || to_char(current_date, 'YYYY-MM-DD')
		          || ': renamed from ' || l_name
		          || ' by updates-2026-11-14-retire-unused-tables-1-rename.ddl; '
		          || 'drop with updates-2026-11-14-retire-unused-tables-2-drop.ddl after 30 days. '
		          || 'Unused because: ' || l_why || '.';
		IF obj_description(('public.' || l_name)::regclass, 'pg_class') IS NOT NULL THEN
			l_comment := l_comment || ' Previous comment: '
			          || obj_description(('public.' || l_name)::regclass, 'pg_class');
		END IF;

		EXECUTE format('ALTER TABLE public.%I RENAME TO %I', l_name, l_new);
		EXECUTE format('COMMENT ON TABLE public.%I IS %L', l_new, l_comment);

		RAISE NOTICE '%: renamed to % (about % rows, %)', l_name, l_new, coalesce(l_rows, 0),
			pg_size_pretty(pg_total_relation_size(('public.' || l_new)::regclass));
	END LOOP;
END
$retire$;

-- What is retired in this database now, and when
SELECT c.relname                                              AS retired_table,
       substring(obj_description(c.oid, 'pg_class') FROM '^Retired (\d{4}-\d{2}-\d{2})') AS retired_on,
       pg_size_pretty(pg_total_relation_size(c.oid))          AS size
  FROM pg_class c
 WHERE c.relnamespace = 'public'::regnamespace
   AND c.relkind      = 'r'
   AND c.relname LIKE 'zz\_retired\_%'
 ORDER BY 1;

COMMIT;
