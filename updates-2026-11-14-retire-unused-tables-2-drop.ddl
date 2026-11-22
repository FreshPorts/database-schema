-- Retire unused tables, stage 2 of 2: drop the tables renamed by
-- updates-2026-11-14-retire-unused-tables-1-rename.ddl.
--
-- What it does: drops public.zz_retired_<name> for each table in the
-- list below, and nothing else.  It never touches a table under its
-- original name: if the rename script did not rename a table in this
-- database, that table stays.  Nothing anyone sees on the website
-- changes; the data in these tables is gone for good (keep the nightly
-- pg_dump from before this run if you might want it).
--
-- Run it once on each database, as postgres, in the order
-- dvl -> dev -> test -> stage -> r720-02 -> x8dtu -> prod, no sooner than
-- 30 days after the rename on that database:
--
--   psql -U postgres -d <db> -f updates-2026-11-14-retire-unused-tables-2-drop.ddl
--
-- It is safe to run more than once.  For each table it checks that:
--   - public.zz_retired_<name> exists (if not, it says so and moves on)
--   - its comment starts 'Retired YYYY-MM-DD' (set by the rename script)
--     and that date is at least 30 days ago
--   - no foreign key in another table, and no view, depends on it
-- and skips the table, with a WARNING, if any check fails.  DROP TABLE
-- is used without CASCADE, so anything else that depends on a table
-- makes the whole transaction fail rather than go with it.
--
-- Dropping commit_log_port_elements and commit_log_ports_ignore also
-- drops their foreign keys to commit_log, commit_log_elements and ports,
-- which briefly locks those three tables; lock_timeout stops it waiting
-- behind commit processing.  If it times out, run it again.

\set ON_ERROR_STOP on

BEGIN;

SET LOCAL lock_timeout = '10s';

DO $retire$
DECLARE
	l_min_days CONSTANT int    := 30;
	l_tables   CONSTANT text[] := ARRAY[
		'commit_log_port_elements',
		'commit_log_ports_ignore',
		'users_md5_hash_backup',
		'commits_latest',
		'commits_latest_ports',
		'maxcommitid',
		'portcount',
		'wlc',
		'watch_notice_log',
		'design_results'
	];
	l_name    text;
	l_old     text;
	l_date    date;
	l_problem text;
	l_size    text;
BEGIN
	FOREACH l_old IN ARRAY l_tables LOOP
		l_name := 'zz_retired_' || l_old;

		IF to_regclass('public.' || l_name) IS NULL THEN
			IF to_regclass('public.' || l_old) IS NOT NULL THEN
				RAISE NOTICE '%: not retired in this database (still named %), left alone', l_name, l_old;
			ELSE
				RAISE NOTICE '%: not in this database, nothing to do', l_name;
			END IF;
			CONTINUE;
		END IF;

		l_date := substring(obj_description(('public.' || l_name)::regclass, 'pg_class')
		                    FROM '^Retired (\d{4}-\d{2}-\d{2})')::date;
		IF l_date IS NULL THEN
			RAISE WARNING '%: SKIPPED, its comment does not start ''Retired YYYY-MM-DD''', l_name;
			CONTINUE;
		END IF;
		IF current_date - l_date < l_min_days THEN
			RAISE WARNING '%: SKIPPED, retired % (% days ago); wait until %',
				l_name, l_date, current_date - l_date, l_date + l_min_days;
			CONTINUE;
		END IF;

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

		l_size := pg_size_pretty(pg_total_relation_size(('public.' || l_name)::regclass));
		EXECUTE format('DROP TABLE public.%I', l_name);
		RAISE NOTICE '%: dropped (retired %, %)', l_name, l_date, l_size;
	END LOOP;
END
$retire$;

-- Anything still retired but not dropped in this database
SELECT c.relname                                              AS still_retired,
       substring(obj_description(c.oid, 'pg_class') FROM '^Retired (\d{4}-\d{2}-\d{2})') AS retired_on,
       pg_size_pretty(pg_total_relation_size(c.oid))          AS size
  FROM pg_class c
 WHERE c.relnamespace = 'public'::regnamespace
   AND c.relkind      = 'r'
   AND c.relname LIKE 'zz\_retired\_%'
 ORDER BY 1;

COMMIT;
