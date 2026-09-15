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
--
--    The WHERE clause is not an optimisation.  ports carries
--    port_dependencies_clear_cache, an AFTER UPDATE ... FOR EACH ROW
--    trigger that queues the port into cache_clearing_ports and issues
--    NOTIFY port_updated.  An unqualified UPDATE would fire it for every
--    row in the table and enqueue the entire tree for re-rendering.
--
--    Restricting to rows that actually change is also the correct
--    semantics: those are exactly the ports whose rendered pages are
--    wrong.  IS DISTINCT FROM gets the NULL cases right -- a port with
--    neither value set is left alone.

UPDATE ports
   SET extract_depends = patch_depends,
       patch_depends   = extract_depends
 WHERE extract_depends IS DISTINCT FROM patch_depends;

-- 2. port_dependencies: the primary key is
--    (port_id, port_id_dependent_upon, dependency_type), so a blind
--    'E' <-> 'P' flip collides wherever a port already has the same
--    dependent recorded under both types.
--
--    Those pairs need no work: {E,P} swapped is still {E,P}.  Skipping them
--    also guarantees no two updated rows land on the same key, so the flip
--    is collision-free.  The NOT EXISTS sees the pre-UPDATE snapshot.
--
--    port_dependencies has cache-clearing triggers on INSERT and DELETE
--    only, so this UPDATE queues nothing itself.  It needs no separate
--    handling: a port whose rows flip here is one whose extract_depends
--    and patch_depends differ, so statement 1 above has already queued
--    it.  Where the two texts are identical the derived dependent sets
--    are identical too, every pair holds both types, and there is
--    nothing to flip.

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
-- Worth knowing before you start, since each one clears a cache:
--
--   SELECT count(*) FROM ports
--    WHERE extract_depends IS DISTINCT FROM patch_depends;
--
--   SELECT count(*) FROM port_dependencies a
--     JOIN port_dependencies b USING (port_id, port_id_dependent_upon)
--    WHERE a.dependency_type = 'E' AND b.dependency_type = 'P';

-- Six row-level triggers fire on each of these ports rows.  Two are the
-- point of the exercise:
--
--   ports_clear_cache               queues the port itself
--   port_dependencies_clear_cache   queues the ports it depends upon,
--                                   whose "Required by" lists also move
--
-- check_last_commit_id is a no-op here, guarded by
-- "new.last_commit_id is null", so it will not rewrite last_commit_id.
--
-- ports_conflicts_set, ports_categories_set and ports_origin_maintain
-- rebuild rows from columns this migration does not touch.  Wasted work,
-- identical results, but it makes this heavier than a 7277-row UPDATE
-- looks.  If that cost matters, disable those three by name -- never the
-- two cache-clearing triggers, which are what fixes the rendered pages.
--
-- To measure first, run the whole file with ROLLBACK in place of COMMIT.
-- The cache_clearing_ports rows roll back with it, and NOTIFY is
-- transactional, so nothing is delivered to the renderer.

COMMIT;
