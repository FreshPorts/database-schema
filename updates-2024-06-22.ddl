-- Table: public.user_cookie

-- DROP TABLE IF EXISTS public.user_cookie;

CREATE TABLE IF NOT EXISTS public.user_cookie
(
    user_id integer NOT NULL,
    cookie text COLLATE pg_catalog."default" NOT NULL,
    expiry_timestamp timestaamp without time zone NOT NULL,
    CONSTRAINT user_cookie_pkey PRIMARY KEY (user_id, cookie),
    CONSTRAINT user_cookies_user_id FOREIGN KEY (user_id)
        REFERENCES public.users (id) MATCH SIMPLE
        ON UPDATE CASCADE
        ON DELETE CASCADE
)

TABLESPACE pg_default;

ALTER TABLE IF EXISTS public.user_cookie
    OWNER to postgres;

COMMENT ON TABLE public.user_cookie
    IS 'Holds user cookies - need to create a procedure to delete expiried cookies.';

COMMENT ON COLUMN public.user_cookie.expiry_timestamp
    IS 'After this date, this row can be deleted';

alter table users drop column cookie;
