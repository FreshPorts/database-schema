-- Encoding repair, step 0: session setup and helper functions.
-- Creates only pg_temp functions (gone when psql exits); changes no table.
-- Run every file in ONE psql session, connected to the database to repair:
--   \i 00-helpers.sql   \i 01-report.sql   then 10, 11, 12, 20, 30, then 01 again
-- Each repair file leaves its transaction open: read the counts, then
-- type COMMIT; or ROLLBACK; before the next file.
\pset pager off
\timing on
SET client_encoding = 'SQL_ASCII';
SET statement_timeout = '20min';

-- true if t is not valid UTF-8 (raw Latin-1 / cp1252 bytes)
CREATE OR REPLACE FUNCTION pg_temp.bad_utf8(t text) RETURNS boolean LANGUAGE plpgsql IMMUTABLE AS $$
BEGIN PERFORM convert_from(convert_to(t, 'SQL_ASCII'), 'UTF8'); RETURN false;
EXCEPTION WHEN character_not_in_repertoire THEN RETURN true; END $$;

-- 'LATIN1' or 'WIN1252' if t is valid UTF-8 that becomes valid UTF-8
-- again after undoing one round of "UTF-8 read as <enc>, re-encoded".
-- NULL otherwise.  Strict: the whole value must be double-encoded.
CREATE OR REPLACE FUNCTION pg_temp.double_kind(t text) RETURNS text LANGUAGE plpgsql IMMUTABLE AS $$
DECLARE e text;
BEGIN
  IF t IS NULL OR t !~ '[\x80-\xff]' OR pg_temp.bad_utf8(t) THEN RETURN NULL; END IF;
  FOREACH e IN ARRAY ARRAY['LATIN1', 'WIN1252'] LOOP
    BEGIN
      PERFORM convert_from(convert(convert_to(t, 'SQL_ASCII'), 'UTF8', e), 'UTF8');
      RETURN e;
    EXCEPTION WHEN character_not_in_repertoire OR untranslatable_character THEN NULL;
    END;
  END LOOP;
  RETURN NULL;
END $$;

-- byte pattern of typical mojibake: Ã + 2-byte-lead, or â€ / â\u0080
CREATE OR REPLACE FUNCTION pg_temp.mojibake_re() RETURNS text LANGUAGE sql IMMUTABLE AS $$
  SELECT '\xc3[\x82-\x9f]\xc2[\x80-\xbf]|\xc3\xa2(?:\xc2[\x80-\x9f]|\xe2\x82\xac)' $$;

CREATE OR REPLACE FUNCTION pg_temp.latin1_to_utf8(t text) RETURNS text LANGUAGE sql IMMUTABLE AS $$
  SELECT convert_from(convert(convert_to(t, 'SQL_ASCII'), 'LATIN1', 'UTF8'), 'SQL_ASCII') $$;

CREATE OR REPLACE FUNCTION pg_temp.undo_double(t text, e text) RETURNS text LANGUAGE sql IMMUTABLE AS $$
  SELECT convert_from(convert(convert_to(t, 'SQL_ASCII'), 'UTF8', e), 'SQL_ASCII') $$;


-- Undo Latin-1 double encoding run by run, for values only partly
-- double-encoded.  A run is kept as-is unless undoing it gives valid UTF-8.
CREATE OR REPLACE FUNCTION pg_temp.fix_runs(t text) RETURNS text LANGUAGE plpgsql IMMUTABLE AS $$
DECLARE m text; f text; o text := t;
BEGIN
  FOR m IN SELECT r FROM (SELECT DISTINCT (regexp_matches(t, '(?:[\xc2\xc3][\x80-\xbf])+', 'g'))[1] AS r) x
            ORDER BY length(r) DESC LOOP
    BEGIN
      f := pg_temp.undo_double(m, 'LATIN1');
      PERFORM convert_from(convert_to(f, 'SQL_ASCII'), 'UTF8');
      o := replace(o, m, f);
    EXCEPTION WHEN character_not_in_repertoire OR untranslatable_character THEN NULL;
    END;
  END LOOP;
  RETURN o;
END $$;


-- Before/after numbers for each column the repair touches.
--   double_encoded = whole value double-encoded (what Parts 1-3 undo)
--   raw_latin1     = not valid UTF-8 (raw Latin-1; Part 2 converts makefile and pkg_plist)
--   mojibake_left  = valid UTF-8 still matching the mojibake pattern
--                    (partly double-encoded values; Part 1 handles pre-git commits)
CREATE OR REPLACE FUNCTION pg_temp.encoding_report()
RETURNS TABLE(column_name text, double_encoded bigint, raw_latin1 bigint, mojibake_left bigint)
LANGUAGE sql AS $$
  SELECT 'commit_log.description (pre-git)',
         count(*) FILTER (WHERE pg_temp.double_kind(description) IS NOT NULL),
         count(*) FILTER (WHERE pg_temp.bad_utf8(description)),
         count(*) FILTER (WHERE NOT pg_temp.bad_utf8(description) AND description ~ pg_temp.mojibake_re())
    FROM commit_log WHERE coalesce(commit_hash_short, '') = '' AND description ~ '[\x80-\xff]'
  UNION ALL
  SELECT 'ports.' || c, count(*) FILTER (WHERE pg_temp.double_kind(v) IS NOT NULL),
         count(*) FILTER (WHERE pg_temp.bad_utf8(v)),
         count(*) FILTER (WHERE NOT pg_temp.bad_utf8(v) AND v ~ pg_temp.mojibake_re())
    FROM ports, LATERAL (VALUES ('long_description', long_description), ('makefile', makefile),
                                ('pkgmessage', pkgmessage), ('distinfo', distinfo),
                                ('pkg_plist', pkg_plist)) x(c, v)
   WHERE v ~ '[\x80-\xff]'
   GROUP BY c
  UNION ALL
  SELECT 'generate_plist.installed_file',
         count(*) FILTER (WHERE pg_temp.double_kind(installed_file) IS NOT NULL),
         count(*) FILTER (WHERE pg_temp.bad_utf8(installed_file)),
         count(*) FILTER (WHERE NOT pg_temp.bad_utf8(installed_file) AND installed_file ~ pg_temp.mojibake_re())
    FROM generate_plist WHERE installed_file ~ '[\x80-\xff]'
  ORDER BY 1 $$;
