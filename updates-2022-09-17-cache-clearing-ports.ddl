-- Constraint: cache_clearing_ports_category_port_idx

ALTER TABLE IF EXISTS public.cache_clearing_ports DROP CONSTRAINT IF EXISTS cache_clearing_ports_port_id_idx;

ALTER TABLE IF EXISTS public.cache_clearing_ports
    ADD CONSTRAINT cache_clearing_ports_category_port_idx UNIQUE (category, port);

COMMENT ON CONSTRAINT cache_clearing_ports_category_port_idx ON public.cache_clearing_ports
    IS 'Unique constraint on category/port because there''s no need to clear something multiple times.';
