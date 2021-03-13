ALTER TABLE public.ports
    ADD COLUMN options_name text;

COMMENT ON COLUMN public.ports.options_name
    IS 'make -V OPTIONS_NAME - used in make.conf for setting Configuration Options on a port by port basis';
