-- Type: package_sets

-- DROP TYPE public.package_sets;

CREATE TYPE public.package_sets AS ENUM
    ('latest', 'quarterly');

ALTER TYPE public.package_sets
    OWNER TO dan;

COMMENT ON TYPE public.package_sets
    IS 'The name is derived from https://wiki.freebsd.org/Ports/QuarterlyBranch

"Quarterly is the name for Ports branches cut from HEAD at the beginning of every (yearly) quarter in January, April, July, and October, and the name for the binary package sets that are produced from these branches."';



-- Table: public.abi

-- DROP TABLE public.abi;

CREATE TABLE public.abi
(
    id integer NOT NULL GENERATED ALWAYS AS IDENTITY ( INCREMENT 1 START 1 MINVALUE 1 MAXVALUE 2147483647 CACHE 1 ),
    name text COLLATE pg_catalog."default" NOT NULL,
    active boolean NOT NULL DEFAULT true,
    CONSTRAINT abi_pkey PRIMARY KEY (id)
)

TABLESPACE pg_default;

ALTER TABLE public.abi
    OWNER to dan;

GRANT SELECT ON TABLE public.abi TO www;

GRANT SELECT ON TABLE public.abi TO rsyncer;

GRANT ALL ON TABLE public.abi TO dan;

GRANT INSERT, SELECT ON TABLE public.abi TO packaging;

COMMENT ON TABLE public.abi
    IS 'list of ABI - e.g. FreeBSD:12:amd64';

COMMENT ON COLUMN public.abi.active
    IS 'Do we still fetch packages for this ABI';
-- Index: abi_name_idx

-- DROP INDEX public.abi_name_idx;

CREATE UNIQUE INDEX abi_name_idx
    ON public.abi USING btree
    (name COLLATE pg_catalog."default" ASC NULLS LAST)
    TABLESPACE pg_default;


-- Table: public.ports_origin

-- DROP TABLE public.ports_origin;

CREATE TABLE public.ports_origin
(
    port_id integer NOT NULL,
    port_origin text COLLATE pg_catalog."default" NOT NULL,
    CONSTRAINT port_origin_pkey PRIMARY KEY (port_id),
    CONSTRAINT ports_origin_port_id_fk FOREIGN KEY (port_id)
        REFERENCES public.ports (id) MATCH SIMPLE
        ON UPDATE CASCADE
        ON DELETE CASCADE
        NOT VALID
)

TABLESPACE pg_default;

ALTER TABLE public.ports_origin
    OWNER to dan;

GRANT INSERT, SELECT, UPDATE ON TABLE public.ports_origin TO commits;

GRANT ALL ON TABLE public.ports_origin TO dan;

GRANT SELECT ON TABLE public.ports_origin TO rsyncer;

COMMENT ON TABLE public.ports_origin
    IS 'This table is only for ports on head.

can be pre-populated via:

insert into ports_origin select id, categoryport(id) from ports_active;';

COMMENT ON COLUMN public.ports_origin.port_origin
    IS 'The category/port for this port';
-- Index: ports_origin_port_id_idx

-- DROP INDEX public.ports_origin_port_id_idx;

CREATE INDEX ports_origin_port_id_idx
    ON public.ports_origin USING btree
    (port_id ASC NULLS LAST)
    TABLESPACE pg_default;
-- Index: ports_origin_port_origin_idx

-- DROP INDEX public.ports_origin_port_origin_idx;

CREATE INDEX ports_origin_port_origin_idx
    ON public.ports_origin USING btree
    (port_origin COLLATE pg_catalog."default" ASC NULLS LAST)
    TABLESPACE pg_default;



-- Table: public.packages_last_checked

-- DROP TABLE public.packages_last_checked;

CREATE TABLE public.packages_last_checked
(
    abi_id integer NOT NULL,
    last_checked timestamp with time zone,
    repo_date timestamp with time zone,
    import_date timestamp with time zone,
    package_set package_sets,
    processed_date timestamp with time zone,
    CONSTRAINT packages_last_checked_abi_id_fk FOREIGN KEY (abi_id)
        REFERENCES public.abi (id) MATCH SIMPLE
        ON UPDATE CASCADE
        ON DELETE CASCADE
)

TABLESPACE pg_default;

ALTER TABLE public.packages_last_checked
    OWNER to dan;

GRANT SELECT ON TABLE public.packages_last_checked TO www;

GRANT SELECT ON TABLE public.packages_last_checked TO rsyncer;

GRANT ALL ON TABLE public.packages_last_checked TO dan;

GRANT SELECT, UPDATE ON TABLE public.packages_last_checked TO packaging;

COMMENT ON COLUMN public.packages_last_checked.processed_date
    IS 'The timestamp of the last processing of data, for a given ABI/branch, from packages_raw into packages.';





-- Table: public.packages

-- DROP TABLE public.packages;

CREATE TABLE public.packages
(
    id bigint NOT NULL GENERATED ALWAYS AS IDENTITY ( INCREMENT 1 START 1 MINVALUE 1 MAXVALUE 9223372036854775807 CACHE 1 ),
    abi_id integer NOT NULL,
    port_id integer NOT NULL,
    package_version text COLLATE pg_catalog."default" NOT NULL,
    package_name text COLLATE pg_catalog."default" NOT NULL,
    package_set package_sets,
    CONSTRAINT packages_pkey PRIMARY KEY (id),
    CONSTRAINT packages_abi_id_fk FOREIGN KEY (abi_id)
        REFERENCES public.abi (id) MATCH SIMPLE
        ON UPDATE CASCADE
        ON DELETE CASCADE
        DEFERRABLE INITIALLY DEFERRED
        NOT VALID,
    CONSTRAINT packages_port_id_fk FOREIGN KEY (port_id)
        REFERENCES public.ports (id) MATCH SIMPLE
        ON UPDATE CASCADE
        ON DELETE CASCADE
        DEFERRABLE INITIALLY DEFERRED
        NOT VALID
)

TABLESPACE pg_default;

ALTER TABLE public.packages
    OWNER to dan;

GRANT ALL ON TABLE public.packages TO dan;

GRANT INSERT, SELECT, DELETE ON TABLE public.packages TO packaging;

GRANT SELECT ON TABLE public.packages TO rsyncer;

GRANT SELECT ON TABLE public.packages TO www;

COMMENT ON TABLE public.packages
    IS 're https://github.com/FreshPorts/freshports/issues/142';
-- Index: fki_packages_abi_id_fk

-- DROP INDEX public.fki_packages_abi_id_fk;

CREATE INDEX fki_packages_abi_id_fk
    ON public.packages USING btree
    (abi_id ASC NULLS LAST)
    TABLESPACE pg_default;
-- Index: fki_packages_port_id_fk

-- DROP INDEX public.fki_packages_port_id_fk;

CREATE INDEX fki_packages_port_id_fk
    ON public.packages USING btree
    (port_id ASC NULLS LAST)
    TABLESPACE pg_default;
-- Index: packages_all_idx

-- DROP INDEX public.packages_all_idx;

CREATE INDEX packages_all_idx
    ON public.packages USING btree
    (abi_id ASC NULLS LAST, package_name COLLATE pg_catalog."default" ASC NULLS LAST, package_set ASC NULLS LAST)
    INCLUDE(package_version)
    TABLESPACE pg_default;

COMMENT ON INDEX public.packages_all_idx
    IS 'This is not a unique index because multiple package names can exist.

See editors/jucipp & devel/jucipp';
-- Index: packages_package_name_idx

-- DROP INDEX public.packages_package_name_idx;

CREATE INDEX packages_package_name_idx
    ON public.packages USING btree
    (package_name COLLATE pg_catalog."default" ASC NULLS LAST)
    TABLESPACE pg_default;




-- Table: public.package_imports

-- DROP TABLE public.package_imports;

CREATE TABLE public.package_imports
(
    id integer NOT NULL GENERATED ALWAYS AS IDENTITY ( INCREMENT 1 START 1 MINVALUE 1 MAXVALUE 2147483647 CACHE 1 ),
    abi_id integer NOT NULL,
    package_set package_sets NOT NULL,
    date time with time zone NOT NULL,
    inserts integer NOT NULL,
    updates integer NOT NULL,
    deletes integer NOT NULL,
    CONSTRAINT package_imports_pkey PRIMARY KEY (id),
    CONSTRAINT package_imports_abi_id FOREIGN KEY (abi_id)
        REFERENCES public.abi (id) MATCH SIMPLE
        ON UPDATE CASCADE
        ON DELETE CASCADE
        DEFERRABLE INITIALLY DEFERRED
)

TABLESPACE pg_default;

ALTER TABLE public.package_imports
    OWNER to dan;

GRANT SELECT ON TABLE public.package_imports TO rsyncer;

GRANT ALL ON TABLE public.package_imports TO dan;




-- Table: public.packages_raw

-- DROP TABLE public.packages_raw;

CREATE TABLE public.packages_raw
(
    id bigint NOT NULL GENERATED ALWAYS AS IDENTITY ( INCREMENT 1 START 1 MINVALUE 1 MAXVALUE 9223372036854775807 CACHE 1 ),
    package_origin text COLLATE pg_catalog."default" NOT NULL,
    package_name text COLLATE pg_catalog."default" NOT NULL,
    package_version text COLLATE pg_catalog."default" NOT NULL,
    abi text COLLATE pg_catalog."default" NOT NULL,
    abi_id integer,
    port_id integer,
    package_set package_sets,
    CONSTRAINT packages_raw_alt_pkey PRIMARY KEY (id),
    CONSTRAINT packages_raw_abi_id_fk FOREIGN KEY (abi_id)
        REFERENCES public.abi (id) MATCH SIMPLE
        ON UPDATE CASCADE
        ON DELETE CASCADE
        DEFERRABLE INITIALLY DEFERRED
        NOT VALID,
    CONSTRAINT packages_raw_port_id_fk FOREIGN KEY (port_id)
        REFERENCES public.ports (id) MATCH SIMPLE
        ON UPDATE CASCADE
        ON DELETE CASCADE
        DEFERRABLE INITIALLY DEFERRED
        NOT VALID
)

TABLESPACE pg_default;

ALTER TABLE public.packages_raw
    OWNER to dan;

GRANT ALL ON TABLE public.packages_raw TO dan;

GRANT INSERT, SELECT, DELETE ON TABLE public.packages_raw TO packaging;

GRANT SELECT ON TABLE public.packages_raw TO rsyncer;
-- Index: packages_raw_abi_id_idx

-- DROP INDEX public.packages_raw_abi_id_idx;

CREATE INDEX packages_raw_abi_id_idx
    ON public.packages_raw USING btree
    (abi_id ASC NULLS LAST)
    TABLESPACE pg_default;
-- Index: packages_raw_abi_idx

-- DROP INDEX public.packages_raw_abi_idx;

CREATE INDEX packages_raw_abi_idx
    ON public.packages_raw USING btree
    (abi COLLATE pg_catalog."default" ASC NULLS LAST)
    TABLESPACE pg_default;
-- Index: packages_raw_abi_package_set_idx

-- DROP INDEX public.packages_raw_abi_package_set_idx;

CREATE INDEX packages_raw_abi_package_set_idx
    ON public.packages_raw USING btree
    (abi COLLATE pg_catalog."default" ASC NULLS LAST, package_set ASC NULLS LAST)
    TABLESPACE pg_default;
-- Index: packages_raw_all

-- DROP INDEX public.packages_raw_all;

CREATE INDEX packages_raw_all
    ON public.packages_raw USING btree
    (abi_id ASC NULLS LAST, package_name COLLATE pg_catalog."default" ASC NULLS LAST, package_set ASC NULLS LAST)
    INCLUDE(package_version)
    TABLESPACE pg_default;
-- Index: packages_raw_alt_package_name_idx

-- DROP INDEX public.packages_raw_alt_package_name_idx;

CREATE INDEX packages_raw_alt_package_name_idx
    ON public.packages_raw USING btree
    (package_name COLLATE pg_catalog."default" ASC NULLS LAST)
    TABLESPACE pg_default;
-- Index: packages_raw_package_origin_idx

-- DROP INDEX public.packages_raw_package_origin_idx;

CREATE INDEX packages_raw_package_origin_idx
    ON public.packages_raw USING btree
    (package_origin COLLATE pg_catalog."default" ASC NULLS LAST)
    TABLESPACE pg_default;
-- Index: packages_raw_port_id_idx

-- DROP INDEX public.packages_raw_port_id_idx;

CREATE INDEX packages_raw_port_id_idx
    ON public.packages_raw USING btree
    (port_id ASC NULLS LAST)
    TABLESPACE pg_default;


