-- Before/after report.  Needs 00-helpers.sql in this session.
-- generate_plist has ~20 million rows; expect a scan of about 15 s or more.
SELECT * FROM pg_temp.encoding_report();
