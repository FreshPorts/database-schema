-- port_upstream: a newer version found upstream by portscout (#626)
--
-- One row per port for which portscout has found a newer upstream
-- version, and only those.  No row means nothing to show.
--
-- Filled by scripts/portscout_upstream.sh (which fetches portscout's data)
-- and scripts/portscout_upstream.pl (which loads it), run from periodics
-- daily/236.fp_portscout_upstream (fp_portscout_upstream_enable="YES").
-- By hand, as freshports:
--
--   cd /usr/local/libexec/freshports && ./portscout_upstream.sh
--
-- A row is written only when portscout's idea of the port's version agrees
-- with ours.  port_version records ports.version at that moment; the
-- website shows the row only while the two are still equal, so a commit
-- which updates the port hides it at once, without waiting for the next run.
--
-- Read by www/classes/ports.php (LoadUpstream).  Grants are also in
-- permissions.sql.
--
-- To undo:
--   DROP TABLE port_upstream;

\set ON_ERROR_STOP on

BEGIN;

CREATE TABLE port_upstream (
    port_id       integer      PRIMARY KEY REFERENCES ports (id) ON DELETE CASCADE,
    port_version  text         NOT NULL,
    newver        text         NOT NULL,
    newurl        text,
    maintainer    text         NOT NULL,
    discovered    timestamptz,
    checked       timestamptz  NOT NULL
);

COMMENT ON TABLE  port_upstream              IS 'newer upstream versions found by portscout (#626)';
COMMENT ON COLUMN port_upstream.port_version IS 'ports.version when this row was written; shown only while still equal';
COMMENT ON COLUMN port_upstream.newver       IS 'the newer version, as portscout gives it';
COMMENT ON COLUMN port_upstream.newurl       IS 'the newer distfile, as portscout gives it';
COMMENT ON COLUMN port_upstream.maintainer   IS 'lower case, as portscout names its per-maintainer pages';
COMMENT ON COLUMN port_upstream.discovered   IS 'when portscout first found newver';
COMMENT ON COLUMN port_upstream.checked      IS 'when portscout last checked upstream';

GRANT SELECT                         ON port_upstream TO GROUP www;
GRANT SELECT, INSERT, UPDATE, DELETE ON port_upstream TO GROUP commits;
GRANT SELECT                         ON port_upstream TO reading;

COMMIT;
