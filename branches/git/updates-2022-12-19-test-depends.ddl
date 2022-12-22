ALTER TABLE IF EXISTS public.ports
    ADD COLUMN test_depends text COLLATE pg_catalog."default";
