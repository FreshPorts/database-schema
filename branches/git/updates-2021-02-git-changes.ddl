-- looks like this already exists too.
-- ALTER TABLE public.cache_clearing_ports
--    ADD CONSTRAINT cache_clearing_ports_port_id_idx UNIQUE (port_id);

COMMENT ON CONSTRAINT cache_clearing_ports_port_id_idx ON public.cache_clearing_ports
    IS 'Let''s store just one instance per port_id';
