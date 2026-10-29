-- let the website read vuxml_import
--
-- /--/status/ shows SELECT count(*) FROM GetListOfVulnsForUpdate(), the
-- number of vulns process_vuxml.pl selects for update.  That function
-- reads vuxml_import, which only commits and rsyncer could read.
--
-- Run as postgres, on every database.

grant select on vuxml_import to group www;
