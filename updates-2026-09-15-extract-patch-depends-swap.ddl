-- Correct historical EXTRACT_DEPENDS / PATCH_DEPENDS transposition.
--
-- make-port.sh emitted PATCH_DEPENDS before EXTRACT_DEPENDS, but the split in
-- FreshPorts::Port assigned them the other way round.  So every row written
-- before that was fixed holds the two values swapped:
--
--   ports.extract_depends          actually holds PATCH_DEPENDS
--   ports.patch_depends            actually holds EXTRACT_DEPENDS
--   port_dependencies type 'E'     actually means patch
--   port_dependencies type 'P'     actually means extract
--
-- Ports refreshed after the fix are written correctly, so the two populations
-- must not be allowed to mix: pause the refresh queue, run this, then deploy
-- the new make-port.sh, then resume.  Deploying first and migrating afterwards
-- would re-transpose whatever was refreshed in between.

BEGIN;

-- 1. ports: a straight column swap, no constraints involved.

UPDATE ports
   SET extract_depends = patch_depends,
       patch_depends   = extract_depends;

-- 2. port_dependencies: the primary key is
--    (port_id, port_id_dependent_upon, dependency_type), so a blind
--    'E' <-> 'P' flip collides wherever a port already has the same
--    dependent recorded under both types.
--
--    Those pairs need no work: {E,P} swapped is still {E,P}.  Skipping them
--    also guarantees no two updated rows land on the same key, so the flip
--    is collision-free.  The NOT EXISTS sees the pre-UPDATE snapshot.

UPDATE port_dependencies pd
   SET dependency_type = CASE pd.dependency_type WHEN 'E' THEN 'P' ELSE 'E' END
 WHERE pd.dependency_type IN ('E', 'P')
   AND NOT EXISTS (
         SELECT 1
           FROM port_dependencies other
          WHERE other.port_id                = pd.port_id
            AND other.port_id_dependent_upon = pd.port_id_dependent_upon
            AND other.dependency_type        = CASE pd.dependency_type WHEN 'E' THEN 'P' ELSE 'E' END
       );

-- Sanity check before committing: the per-type totals should have exchanged
-- values, and the both-types overlap should be unchanged (5209 as of
-- 2026-09-15).
--
--   SELECT dependency_type, count(*) FROM port_dependencies
--    WHERE dependency_type IN ('E','P') GROUP BY dependency_type;
--
--   SELECT count(*) FROM port_dependencies a
--     JOIN port_dependencies b USING (port_id, port_id_dependent_upon)
--    WHERE a.dependency_type = 'E' AND b.dependency_type = 'P';

COMMIT;
