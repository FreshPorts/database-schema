-- BUILD_RUN_DEPENDS is now extracted by make-port.sh and saved by FreshPorts::Port

ALTER TABLE IF EXISTS public.ports
    ADD COLUMN build_run_depends text COLLATE pg_catalog."default";

-- port_dependencies.dependency_type is char(1) with no check constraint,
-- so the new 'A' (build And run) type needs no DDL.
