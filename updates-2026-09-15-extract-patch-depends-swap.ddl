-- DO NOT RUN.
--
-- This file used to swap ports.extract_depends with ports.patch_depends, and
-- port_dependencies type 'E' with type 'P', for every port.  It assumed every
-- row written before the make-port.sh fix (ingress-scripts 83db687,
-- 2026-09-15) held the two values transposed.  That assumption was wrong.
--
-- Production (freshports.org) never ran the swap.  On 2026-10-11, of the
-- active ports with devel/ruby-gems in either column:
--
--   3537 had it in extract_depends   (correct: USES=gem puts it there)
--      4 had it in patch_depends     (actually transposed)
--
-- So the swap would have broken about 3500 correct ports to fix 4.
-- It did exactly that on freshports.dvl on 2026-10-11, and running it a
-- second time was what put dev back.
--
-- The commit message of ingress-scripts 83db687 says to pause the refresh
-- queue and run this file before deploying.  Ignore that step.  Deploying
-- p5-freshports-scripts 2.2.7 with p5-freshports-modules 2.2.2 needs no
-- data migration.
--
-- To find ports that really are transposed, check where gem ports keep
-- devel/ruby-gems:
--
--   SELECT category || '/' || name AS origin, patch_depends, extract_depends
--     FROM ports_active
--    WHERE patch_depends LIKE '%devel/ruby-gems%'
--    ORDER BY origin;
--
-- and confirm each one with make -V PATCH_DEPENDS -V EXTRACT_DEPENDS before
-- acting.  Fix them by refreshing, not with SQL: list them one category/port
-- per line and pass that to refresh-listed-ports.pl on the ingress host.
--
-- The guard below makes psql -f stop here instead of doing anything.

DO $$
BEGIN
  RAISE EXCEPTION 'updates-2026-09-15-extract-patch-depends-swap.ddl must not be run; read the comments in the file';
END
$$;
