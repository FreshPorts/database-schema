-- re https://github.com/FreshPorts/freshports/issues/637

ALTER TABLE IF EXISTS public.ports
    ADD COLUMN use_rc_subr text;
    
    