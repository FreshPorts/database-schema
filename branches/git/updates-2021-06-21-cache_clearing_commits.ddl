CREATE TABLE IF NOT EXISTS public.cache_clearing_commits
(
    commit_to_clear text,
    date_added timestamp without time zone DEFAULT now(),
    CONSTRAINT cache_clearing_commits_idx PRIMARY KEY (commit_to_clear)
)

TABLESPACE pg_default;

ALTER TABLE public.cache_clearing_commits
    OWNER to postgres;

GRANT INSERT, UPDATE, SELECT ON TABLE public.cache_clearing_commits TO commits;

GRANT SELECT, DELETE ON TABLE public.cache_clearing_commits TO listening;

GRANT ALL ON TABLE public.cache_clearing_commits TO postgres;

GRANT SELECT ON TABLE public.cache_clearing_commits TO reporting;

GRANT SELECT ON TABLE public.cache_clearing_commits TO rsyncer;

GRANT INSERT, SELECT ON TABLE public.cache_clearing_commits TO www;

COMMENT ON COLUMN public.cache_clearing_commits.commit_to_clear
    IS 'The commit which should be cleared from the archives';

COMMENT ON COLUMN public.cache_clearing_commits.date_added
    IS 'The timestamp this entry was added to the table';
