-- to convert the generate_plist table, multiple rows per port, into a
-- single row of JSON. Mostly used for Dependency line:
--
-- re https://github.com/FreshPorts/freshports/issues/216
--
CREATE OR REPLACE FUNCTION pkg_plist(bigint) returns json as $$
   WITH tmp AS (
       select regexp_match(installed_file, 'lib/[^/]*?\.so') as lib 
         from generate_plist
        where generate_plist.port_id = $1
   )
   select json_agg(distinct lib[1]) from tmp where lib is not null
$$ LANGUAGE SQL STABLE;


-- committer name and email

ALTER TABLE public.commit_log
    ADD COLUMN committer_name text;

ALTER TABLE public.commit_log
    ADD COLUMN committer_email text;

-- author name and email

ALTER TABLE public.commit_log
    ADD COLUMN author_name text;

ALTER TABLE public.commit_log
    ADD COLUMN author_email text;
