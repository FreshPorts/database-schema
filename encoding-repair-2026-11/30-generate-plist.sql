\set ON_ERROR_STOP on
-------------------------------------------------------------------
-- Part 3: generate_plist.installed_file (dvl: 61 rows; ~15 s scan)
-------------------------------------------------------------------
BEGIN;
CREATE TEMP TABLE fix_gp ON COMMIT DROP AS
SELECT id, port_id FROM generate_plist
 WHERE installed_file ~ '[\x80-\xff]' AND pg_temp.double_kind(installed_file) IS NOT NULL;
SELECT count(*) AS rows, count(DISTINCT port_id) AS ports FROM fix_gp;
UPDATE generate_plist G SET installed_file = pg_temp.undo_double(G.installed_file, pg_temp.double_kind(G.installed_file))
  FROM fix_gp F WHERE G.id = F.id;
INSERT INTO cache_clearing_ports (port_id, category, port)
SELECT DISTINCT PA.id, PA.category, PA.name FROM fix_gp F JOIN ports_all PA ON PA.id = F.port_id
    ON CONFLICT DO NOTHING;
NOTIFY port_updated;
-- COMMIT;  or  ROLLBACK;

