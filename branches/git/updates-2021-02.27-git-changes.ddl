-- Column: public.repo.db_root_prefix

-- ALTER TABLE public.repo DROP COLUMN db_root_prefix;

ALTER TABLE public.repo
    ADD COLUMN db_root_prefix text COLLATE pg_catalog."default";

COMMENT ON COLUMN public.repo.db_root_prefix
    IS 'appended to repo path names before they are inserted into the database';

UPDATE repo set repo_hostname = 'cgit.freebsd.org', path_to_repo = '/src',                   db_root_prefix = '/base'  where name = 'src'   and repository = 'git';
UPDATE repo set repo_hostname = 'cgit.freebsd.org', path_to_repo = '/freebsd/freebsd-prots', db_root_prefix = '/ports' where name = 'ports' and repository = 'git';
UPDATE repo set repo_hostname = 'cgit.freebsd.org', path_to_repo = '/doc',                   db_root_prefix = '/doc'   where name = 'doc'   and repository = 'git';
