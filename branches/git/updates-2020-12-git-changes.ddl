REVOKE ALL ON TABLE public.commit_log FROM commits;
GRANT INSERT, UPDATE, DELETE, SELECT ON TABLE public.commit_log TO commits;

GRANT SELECT ON TABLE public.commit_log TO freshsource_ro;

ALTER TABLE public.commit_log
    ADD COLUMN commit_hash_short text COLLATE pg_catalog."default";

COMMENT ON COLUMN public.commit_log.commit_hash_short
    IS 'This is the short version of the git hash stored in
 svn_revision.

-- If null/empty, it is not a git hash.';
CREATE INDEX commit_log_commit_hash_short
    ON public.commit_log USING btree
    (commit_hash_short COLLATE pg_catalog."default" ASC NULLS LAST)
    TABLESPACE pg_default;






CREATE INDEX "commit_log_branches_branch_id_idx"
    ON public.commit_log_branches USING btree
    (branch_id ASC NULLS LAST)
    TABLESPACE pg_default;




REVOKE ALL ON TABLE public.commit_log_elements FROM commits;
GRANT INSERT, UPDATE, DELETE, SELECT ON TABLE public.commit_log_elements TO commits;

GRANT SELECT ON TABLE public.commit_log_elements TO freshsource_ro;

ALTER TABLE public.commit_log_elements DROP CONSTRAINT commit_log_elements_change_type;

ALTER TABLE public.commit_log_elements
    ADD CONSTRAINT commit_log_elements_change_type CHECK (change_type = 'A'::bpchar OR change_type = 'M'::bpchar OR change_type = 'R'::bpchar OR change_type = 'r'::bpchar);

COMMENT ON CONSTRAINT commit_log_elements_change_type ON public.commit_log_elements
    IS '
A - add
M - modify
R - remove for subersion, delete for git
r - rename (added for git)';




REVOKE ALL ON TABLE public.commit_log_port_elements FROM dan;
REVOKE ALL ON TABLE public.commit_log_port_elements FROM commits;
GRANT INSERT, UPDATE, DELETE, SELECT ON TABLE public.commit_log_port_elements TO commits;

GRANT ALL ON TABLE public.commit_log_port_elements TO dan;



REVOKE ALL ON TABLE public.commit_log_ports_vuxml FROM dan;
REVOKE ALL ON TABLE public.commit_log_ports_vuxml FROM commits;
GRANT INSERT, SELECT, DELETE ON TABLE public.commit_log_ports_vuxml TO commits;

GRANT ALL ON TABLE public.commit_log_ports_vuxml TO dan;




REVOKE ALL ON TABLE public.design_results FROM dan;
GRANT ALL ON TABLE public.design_results TO dan;




REVOKE ALL ON TABLE public.element FROM commits;
GRANT DELETE, UPDATE, SELECT, INSERT ON TABLE public.element TO commits;

GRANT SELECT ON TABLE public.element TO freshsource_ro;
GRANT SELECT ON TABLE public.element TO packaging;



REVOKE ALL ON TABLE public.latest_commits FROM dan;
GRANT ALL ON TABLE public.latest_commits TO dan;

GRANT SELECT ON TABLE public.latest_commits TO freshsource_ro;



REVOKE ALL ON TABLE public.packages FROM dan;
REVOKE ALL ON TABLE public.packages FROM packaging;
GRANT ALL ON TABLE public.packages TO dan;

GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.packages TO packaging;



REVOKE ALL ON TABLE public.packages_last_checked FROM packaging;
GRANT UPDATE, SELECT ON TABLE public.packages_last_checked TO packaging;


--ALTER TABLE public.packages_raw
--    OWNER TO packager_dev;

--REVOKE ALL ON TABLE public.packages_raw FROM packager;
REVOKE ALL ON TABLE public.packages_raw FROM packaging;
REVOKE ALL ON TABLE public.packages_raw FROM rsyncer;
GRANT ALL ON TABLE public.packages_raw TO packager_dev;

GRANT DELETE, INSERT, UPDATE, SELECT ON TABLE public.packages_raw TO packaging;

GRANT SELECT ON TABLE public.packages_raw TO rsyncer;





REVOKE ALL ON TABLE public.ports FROM commits;
REVOKE ALL ON TABLE public.ports FROM packaging;
GRANT UPDATE, SELECT, DELETE, INSERT ON TABLE public.ports TO commits;

GRANT INSERT, SELECT, DELETE ON TABLE public.ports TO packaging;


ALTER TABLE public.ports
    ADD CONSTRAINT ports_last_commit_id_fkey5 FOREIGN KEY (last_commit_id)
    REFERENCES public.commit_log (id) MATCH SIMPLE
    ON UPDATE CASCADE
    ON DELETE SET NULL;

ALTER TABLE public.ports
    ADD CONSTRAINT ports_last_commit_id_fkey6 FOREIGN KEY (last_commit_id)
    REFERENCES public.commit_log (id) MATCH SIMPLE
    ON UPDATE CASCADE
    ON DELETE SET NULL;
CREATE INDEX ports_last_commit_id_idx
    ON public.ports USING btree
    (last_commit_id ASC NULLS LAST)
    TABLESPACE pg_default;


--CREATE TRIGGER ports_ports_categories
--    AFTER INSERT OR UPDATE 
--    ON public.ports
--    FOR EACH ROW
--    EXECUTE PROCEDURE public.ports_categories_set();




REVOKE ALL ON TABLE public.ports_origin FROM dan;
GRANT ALL ON TABLE public.ports_origin TO dan;

GRANT SELECT ON TABLE public.ports_origin TO packaging;




REVOKE ALL ON TABLE public.ports_origin FROM dan;
GRANT ALL ON TABLE public.ports_origin TO dan;

GRANT SELECT ON TABLE public.ports_origin TO packaging;






REVOKE ALL ON TABLE public.repo FROM dan;
GRANT ALL ON TABLE public.repo TO dan;

GRANT SELECT ON TABLE public.repo TO freshsource_ro;

-- rename svn_hostname to repo_hostname
ALTER TABLE repo    RENAME svn_hostname TO repo_hostname;


ALTER TABLE public.repo
    ADD COLUMN repository text COLLATE pg_catalog."default" NOT NULL DEFAULT 'subversion'::text;

COMMENT ON COLUMN public.repo.repository
    IS 'subversion? git? cvs?';

DROP INDEX public.repo_name;
DROP INDEX public.repo_description;
DROP INDEX public.repo_path_to_repo;



REVOKE ALL ON TABLE public.report_subscriptions FROM www;
REVOKE ALL ON TABLE public.report_subscriptions FROM dan;
GRANT ALL ON TABLE public.report_subscriptions TO dan;

GRANT SELECT, INSERT, DELETE, UPDATE ON TABLE public.report_subscriptions TO www;





REVOKE ALL ON TABLE public.security_notice FROM www;
REVOKE ALL ON TABLE public.security_notice FROM dan;
GRANT ALL ON TABLE public.security_notice TO dan;

GRANT SELECT ON TABLE public.security_notice TO freshsource_ro;

GRANT UPDATE, SELECT, INSERT ON TABLE public.security_notice TO www;





REVOKE ALL ON TABLE public.system FROM dan;
GRANT ALL ON TABLE public.system TO dan;

GRANT SELECT ON TABLE public.system TO freshsource_ro;





GRANT SELECT ON TABLE public.system_branch TO packaging;










REVOKE ALL ON TABLE public.users FROM www;
REVOKE ALL ON TABLE public.users FROM dan;
GRANT ALL ON TABLE public.users TO dan;

GRANT SELECT ON TABLE public.users TO freshsource_ro;

GRANT UPDATE, SELECT, INSERT ON TABLE public.users TO www;









REVOKE ALL ON TABLE public.watch_list FROM www;
REVOKE ALL ON TABLE public.watch_list FROM dan;
GRANT ALL ON TABLE public.watch_list TO dan;

GRANT SELECT ON TABLE public.watch_list TO freshsource_ro;

GRANT SELECT, INSERT, DELETE, UPDATE ON TABLE public.watch_list TO www;





REVOKE ALL ON TABLE public.watch_list_element FROM dan;
REVOKE ALL ON TABLE public.watch_list_element FROM www;
GRANT ALL ON TABLE public.watch_list_element TO dan;

GRANT SELECT ON TABLE public.watch_list_element TO freshsource_ro;

GRANT SELECT, INSERT, DELETE, UPDATE ON TABLE public.watch_list_element TO www;






REVOKE ALL ON TABLE public.watch_notice FROM dan;
GRANT ALL ON TABLE public.watch_notice TO dan;

GRANT SELECT ON TABLE public.watch_notice TO freshsource_ro;





