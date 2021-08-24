-- from https://github.com/FreshPorts/freshports/issues/328

-- Table: public.ports_to_refresh

-- DROP TABLE public.ports_to_refresh;

CREATE TABLE IF NOT EXISTS public.ports_to_refresh
(
    port_id bigint NOT NULL,
    date_added timestamp without time zone DEFAULT now(),
    CONSTRAINT ports_to_refresh_port_id_pk PRIMARY KEY (port_id),
    CONSTRAINT ports_to_refresh_port_id_fk FOREIGN KEY (port_id)
        REFERENCES public.ports (id) MATCH SIMPLE
        ON UPDATE CASCADE
        ON DELETE CASCADE
)

TABLESPACE pg_default;

ALTER TABLE public.ports_to_refresh
    OWNER to postgres;

GRANT DELETE, SELECT ON TABLE public.ports_to_refresh TO commits;

GRANT ALL ON TABLE public.ports_to_refresh TO postgres;

COMMENT ON TABLE public.ports_to_refresh
    IS 'This table lists ports which are to be refreshed. Before processing begins, run ''check checkout main'' first, to be sure we aren''t scrolled to some non-current commit.


grant select, delete on ports_to_refresh to commits;
grant select on ports_to_refresh to rsyncer;
grant select on ports_to_refresh to reporting;


insert into ports_to_refresh select id, now() from ports_active where category = 'base' and name = 'binutils';
