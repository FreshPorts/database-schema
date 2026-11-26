\set ON_ERROR_STOP on
-------------------------------------------------------------------
-- Part 2: ports.  Run only AFTER port.pm _GetFileContents() stops
-- reading files as ISO-8859-1, or the next refresh of each port
-- double-encodes makefile / pkgmessage / distinfo again.
-------------------------------------------------------------------
BEGIN;
UPDATE ports SET long_description = pg_temp.undo_double(long_description, pg_temp.double_kind(long_description))
 WHERE long_description ~ '[\x80-\xff]' AND pg_temp.double_kind(long_description) IS NOT NULL;   -- dvl: 67
UPDATE ports SET makefile = pg_temp.undo_double(makefile, pg_temp.double_kind(makefile))
 WHERE makefile ~ '[\x80-\xff]' AND pg_temp.double_kind(makefile) IS NOT NULL;                   -- dvl: 42
UPDATE ports SET pkgmessage = pg_temp.undo_double(pkgmessage, pg_temp.double_kind(pkgmessage))
 WHERE pkgmessage ~ '[\x80-\xff]' AND pg_temp.double_kind(pkgmessage) IS NOT NULL;               -- dvl: 28
UPDATE ports SET distinfo = pg_temp.undo_double(distinfo, pg_temp.double_kind(distinfo))
 WHERE distinfo ~ '[\x80-\xff]' AND pg_temp.double_kind(distinfo) IS NOT NULL;                   -- dvl: 4
UPDATE ports SET makefile = pg_temp.latin1_to_utf8(makefile)
 WHERE makefile ~ '[\x80-\xff]' AND pg_temp.bad_utf8(makefile);                                  -- dvl: 6
UPDATE ports SET pkg_plist = pg_temp.latin1_to_utf8(pkg_plist)
 WHERE pkg_plist ~ '[\x80-\xff]' AND pg_temp.bad_utf8(pkg_plist);                                -- dvl: 2
SELECT * FROM pg_temp.encoding_report() WHERE column_name LIKE 'ports.%' AND double_encoded + raw_latin1 > 0;   -- expect 0 rows
-- COMMIT;  or  ROLLBACK;

