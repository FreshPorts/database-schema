-- PKGVERSION as make reports it, which is not always what version,
-- revision and portepoch compose to.
--
-- audio/oss, for one:
--
--   PORTVERSION   4.2.b2019
--   PORTREVISION  5
--   PKGVERSION    4.2.b2019.1501000_5
--
-- The kmod framework splices ${OSVERSION} into PKGVERSION, between the
-- version and the revision, where none of the variables FreshPorts fetches
-- can show it.  Recording PKGVERSION is the only way to hold what the port
-- actually builds as.

ALTER TABLE IF EXISTS public.ports
    ADD COLUMN pkgversion text COLLATE pg_catalog."default";

COMMENT ON COLUMN public.ports.pkgversion
    IS 'make -V PKGVERSION: version, revision and epoch as the ports
 framework composes them.  Not always version || _revision || ,portepoch --
 see audio/oss, where the kmod framework adds OSVERSION.

-- NULL until the port has been refreshed since this column was added.';
