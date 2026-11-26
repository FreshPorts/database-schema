-- supported_releases: the FreeBSD branches which are supported right now
-- (https://github.com/FreshPorts/periodics/issues/2, split from
-- https://github.com/FreshPorts/freshports/issues/612)
--
-- One row per branch:
--
--   main          CURRENT; major is its version, e.g. 16
--   stable/N      major N, minor NULL
--   releng/N.M    major N, minor M
--
-- stable/ and releng/ come from the supported releases table on
-- https://www.freebsd.org/security/#sup (freebsd-doc
-- website/content/en/security/_index.adoc).  main comes from REVISION in
-- freebsd-src main sys/conf/newvers.sh: CURRENT is not on that page.
--
-- Kept up to date by scripts/supported_releases_update.pl, run from
-- periodics daily/237.fp_supported_releases
-- (fp_supported_releases_enable="YES").  The first run fills the table.
-- By hand, as freshports:
--
--   cd /usr/local/libexec/freshports && perl supported_releases_update.pl
--
-- Newest to oldest, in the security page's order (main, stable/15,
-- releng/15.1, stable/14, ...):
--
--   SELECT branch FROM supported_releases ORDER BY major DESC, minor DESC NULLS FIRST;
--
-- Grants are also in permissions.sql.
--
-- To undo:
--   DROP TABLE supported_releases;

\set ON_ERROR_STOP on

BEGIN;

CREATE TABLE supported_releases (
    branch  text         PRIMARY KEY
                         CHECK (branch ~ '^(main|stable/[0-9]+|releng/[0-9]+\.[0-9]+)$'),
    major   integer      NOT NULL CHECK (major > 0),
    minor   integer      CHECK (minor >= 0),
    added   timestamptz  NOT NULL DEFAULT now(),
    CHECK ((branch LIKE 'releng/%') = (minor IS NOT NULL))
);

COMMENT ON TABLE supported_releases IS 'The FreeBSD branches supported right now: main (CURRENT), stable/N and releng/N.M. Kept up to date daily by supported_releases_update.pl from https://www.freebsd.org/security/#sup and freebsd-src sys/conf/newvers.sh. See https://github.com/FreshPorts/periodics/issues/2';
COMMENT ON COLUMN supported_releases.branch IS 'main for CURRENT, otherwise the branch name as the security page gives it: stable/15, releng/15.1';
COMMENT ON COLUMN supported_releases.major IS 'The major version: 15 for stable/15 and releng/15.1; for main, the version of CURRENT, e.g. 16';
COMMENT ON COLUMN supported_releases.minor IS 'The minor version for releng/N.M; NULL for main and stable/N. ORDER BY major DESC, minor DESC NULLS FIRST gives the security page''s order';
COMMENT ON COLUMN supported_releases.added IS 'When supported_releases_update.pl first saw this branch listed';

GRANT SELECT                         ON supported_releases TO GROUP www;
GRANT SELECT, INSERT, UPDATE, DELETE ON supported_releases TO GROUP commits;
GRANT SELECT                         ON supported_releases TO reading;

COMMIT;
