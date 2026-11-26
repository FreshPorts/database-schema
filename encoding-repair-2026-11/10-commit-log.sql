\set ON_ERROR_STOP on
-------------------------------------------------------------------
-- Part 1: commit_log.description, non-git commits only.
-- Git-era rows match upstream freebsd-ports byte for byte (checked
-- 121038037c0b and aa6eefd5e663), so they stay as they are.
-------------------------------------------------------------------
BEGIN;
CREATE TEMP TABLE fix_cl ON COMMIT DROP AS
SELECT id, message_id, description AS old_description,
       CASE WHEN pg_temp.double_kind(description) IS NOT NULL
            THEN pg_temp.undo_double(description, pg_temp.double_kind(description))
            ELSE pg_temp.fix_runs(description) END AS new_description
  FROM commit_log
 WHERE coalesce(commit_hash_short, '') = ''
   AND description ~ '[\x80-\xff]'
   AND (pg_temp.double_kind(description) IS NOT NULL OR description ~ pg_temp.mojibake_re());
DELETE FROM fix_cl WHERE new_description = old_description;   -- fix_runs found nothing safe (e.g. EUC-JP row)
SELECT count(*) AS commits_to_fix FROM fix_cl;                  -- expect a little over 313 on dvl

UPDATE commit_log C SET description = F.new_description FROM fix_cl F WHERE C.id = F.id;

INSERT INTO cache_clearing_ports (port_id, category, port)
SELECT DISTINCT PA.id, PA.category, PA.name
  FROM fix_cl F JOIN commit_log_ports CLP ON CLP.commit_log_id = F.id
                JOIN ports_all PA        ON PA.id = CLP.port_id
    ON CONFLICT DO NOTHING;
NOTIFY port_updated;

-- leftovers to handle by hand (EUC-JP, Mac Roman "GÂ\x87bor", etc.)
SELECT id, message_id, commit_date::date FROM commit_log
 WHERE coalesce(commit_hash_short, '') = '' AND description ~ pg_temp.mojibake_re();
-- COMMIT;  or  ROLLBACK;

