-- Type: action

-- DROP TYPE IF EXISTS public.action;

-- CREATE TYPE public.action AS ENUM
--     ('insert', 'update', 'delete');

ALTER TYPE public.action
    OWNER TO postgres;


-- Table: public.package_notifications

-- DROP TABLE IF EXISTS public.package_notifications;

CREATE TABLE IF NOT EXISTS public.package_notifications
(
    abi_id integer NOT NULL,
    package_set package_sets NOT NULL,
    port_id integer NOT NULL,
    action action NOT NULL,
    version_previous text COLLATE pg_catalog."default",
    version_current text COLLATE pg_catalog."default",
    CONSTRAINT package_notifications_abi_set_port_idx UNIQUE (abi_id, package_set, port_id),
    CONSTRAINT package_notifications_abi_id FOREIGN KEY (abi_id)
        REFERENCES public.abi (id) MATCH SIMPLE
        ON UPDATE CASCADE
        ON DELETE CASCADE,
    CONSTRAINT package_notifications_port_id_fk FOREIGN KEY (port_id)
        REFERENCES public.ports (id) MATCH SIMPLE
        ON UPDATE CASCADE
        ON DELETE CASCADE,
    CONSTRAINT package_notifications_action_check CHECK (action = 'insert'::action AND version_previous IS NULL AND version_current IS NOT NULL OR action = 'update'::action AND version_previous IS NOT NULL AND version_current IS NOT NULL OR action = 'delete'::action AND version_previous IS NOT NULL AND version_current IS NULL)
)

TABLESPACE pg_default;

ALTER TABLE IF EXISTS public.package_notifications
    OWNER to postgres;

COMMENT ON TABLE public.package_notifications
    IS 'when a new repo is imported, we need to notify users. This table lets us build a list of what has change in this repo.

re: https://github.com/FreshPorts/freshports/issues/542';

COMMENT ON COLUMN public.package_notifications.action
    IS 'Was this row the result of an insert, update, or a delete on the packages table?';

COMMENT ON CONSTRAINT package_notifications_action_check ON public.package_notifications
    IS 'read the constraint as:

		(action = ''insert''::action AND version_previous IS NULL AND version_current IS NOT NULL)
		OR (action = ''update''::action AND version_previous IS NOT NULL AND version_current IS NOT NULL)
		OR (action = ''delete''::action AND version_previous IS NOT NULL AND version_current IS NULL))
';


--
-- for package_notifications
--

-- UPDATE
CREATE OR REPLACE FUNCTION package_notifications_update() RETURNS TRIGGER AS $$
   BEGIN
        -- by definition, this is an update

        -- theoretically, this statement should always be true
        -- commented out for easier testing
--        if (new.package_version != old.package_version) then
            insert into package_notifications(abi_id, package_set, port_id, action, version_previous, version_current)
            values (NEW.abi_id, NEW.package_set, NEW.port_id, 'update', OLD.package_version, NEW.package_version)
            on conflict on constraint package_notifications_abi_set_port_idx do nothing;
--        end if;

        RETURN NEW;
   END
$$ LANGUAGE 'plpgsql';

  DROP TRIGGER IF EXISTS package_notifications_update ON packages;
CREATE TRIGGER package_notifications_update
    AFTER UPDATE ON packages
    FOR EACH ROW
    EXECUTE PROCEDURE package_notifications_update();

-- INSERT (and delete are next to each other for easier comparison)
CREATE OR REPLACE FUNCTION package_notifications_insert() RETURNS TRIGGER AS $$
   BEGIN
        -- by definition, this is an insert

        insert into package_notifications(abi_id, package_set, port_id, action, version_current)
        values (NEW.abi_id, NEW.package_set, NEW.port_id, 'insert', NEW.package_version)
            on conflict on constraint package_notifications_abi_set_port_idx do nothing;

        RETURN NEW;
   END
$$ LANGUAGE 'plpgsql';

  DROP TRIGGER IF EXISTS package_notifications_insert ON packages;
CREATE TRIGGER package_notifications_insert
    AFTER INSERT ON packages
    FOR EACH ROW
    EXECUTE PROCEDURE package_notifications_insert();

-- DELETE (and delete are next to each other for easier comparison)
CREATE OR REPLACE FUNCTION package_notifications_delete() RETURNS TRIGGER AS $$
   BEGIN
        -- by definition, this is a delete

        insert into package_notifications(abi_id, package_set, port_id, action, version_previous)
        values (OLD.abi_id, OLD.package_set, OLD.port_id, 'delete', OLD.package_version)
            on conflict on constraint package_notifications_abi_set_port_idx do nothing;

        RETURN OLD;
   END
$$ LANGUAGE 'plpgsql';

  DROP TRIGGER IF EXISTS package_notifications_delete ON packages;
CREATE TRIGGER package_notifications_delete
    AFTER DELETE ON packages
    FOR EACH ROW
    EXECUTE PROCEDURE package_notifications_delete();



grant insert, select, update, delete on package_notifications to packaging;


-- Table: public.report_subscriptions_abi

-- DROP TABLE IF EXISTS public.report_subscriptions_abi;

CREATE TABLE IF NOT EXISTS public.report_subscriptions_abi
(
    user_id integer NOT NULL,
    watch_list_id integer NOT NULL,
    abi_id integer NOT NULL,
    package_set package_sets NOT NULL,
    CONSTRAINT report_subscriptions_abi_user_abi_watch_pk UNIQUE NULLS NOT DISTINCT (user_id, watch_list_id, abi_id, package_set),
    CONSTRAINT report_subscriptions_abi_abi_id FOREIGN KEY (abi_id)
        REFERENCES public.abi (id) MATCH SIMPLE
        ON UPDATE CASCADE
        ON DELETE CASCADE,
    CONSTRAINT report_subscriptions_abi_user_id FOREIGN KEY (user_id)
        REFERENCES public.users (id) MATCH SIMPLE
        ON UPDATE CASCADE
        ON DELETE CASCADE,
    CONSTRAINT report_subscriptions_abi_watch_list_id FOREIGN KEY (watch_list_id)
        REFERENCES public.watch_list (id) MATCH SIMPLE
        ON UPDATE CASCADE
        ON DELETE CASCADE
)

TABLESPACE pg_default;

ALTER TABLE IF EXISTS public.report_subscriptions_abi
    OWNER to postgres;

REVOKE ALL ON TABLE public.report_subscriptions_abi FROM reading;
REVOKE ALL ON TABLE public.report_subscriptions_abi FROM www;

GRANT ALL ON TABLE public.report_subscriptions_abi TO postgres;

GRANT SELECT ON TABLE public.report_subscriptions_abi TO reading;

GRANT SELECT, INSERT, DELETE ON TABLE public.report_subscriptions_abi TO www;

COMMENT ON TABLE public.report_subscriptions_abi
    IS 'Records the ABI a given user follows - relates to package_notifications table

You can associate a given watch list with one or more ABI.';

COMMENT ON COLUMN public.report_subscriptions_abi.watch_list_id
    IS 'We don''t need user_id, because watch_list_id will find us the user_id. We duplicate that information here because I think it''ll be useful in queries.';

COMMENT ON CONSTRAINT report_subscriptions_abi_user_abi_watch_pk ON public.report_subscriptions_abi
    IS 'For a given user_id, abi_id, and watch_list_id must be unique.';INSERT INTO public.reports(
	name, description, needs_frequency)
	VALUES ('New Package Notification', 'Notification when a new package is available for something on your watch list.', false);
	
	
	-- Table: public.report_log_package_notifications

-- DROP TABLE IF EXISTS public.report_log_package_notifications;

CREATE TABLE IF NOT EXISTS public.report_log_package_notifications
(
    id integer NOT NULL DEFAULT nextval('report_log_package_notifications_id_seq'::regclass),
    abi_id integer NOT NULL,
    package_set package_sets NOT NULL,
    report_date timestamp with time zone NOT NULL DEFAULT ('now'::text)::timestamp(6) with time zone,
    num_emails integer NOT NULL,
    num_ports integer NOT NULL,
    num_users integer NOT NULL,
    num_watch_lists integer NOT NULL,
    CONSTRAINT report_log_package_notifications_pkey PRIMARY KEY (id),
    CONSTRAINT report_log_package_notifications_abi_id_fk FOREIGN KEY (abi_id)
        REFERENCES public.abi (id) MATCH SIMPLE
        ON UPDATE CASCADE
        ON DELETE CASCADE
        NOT VALID
)

TABLESPACE pg_default;

ALTER TABLE IF EXISTS public.report_log_package_notifications
    OWNER to postgres;

REVOKE ALL ON TABLE public.report_log_package_notifications FROM reading;

GRANT ALL ON TABLE public.report_log_package_notifications TO postgres;

GRANT INSERT ON TABLE public.report_log_package_notifications TO reading;
-- Index: fki_a

-- DROP INDEX IF EXISTS public.fki_a;

CREATE INDEX IF NOT EXISTS fki_a
    ON public.report_log_package_notifications USING btree
    (abi_id ASC NULLS LAST)
    TABLESPACE pg_default;
    

# for sending out package notifications
GRANT SELECT                 ON announcements            to reading;
GRANT SELECT                 ON package_notifications    to reading;
GRANT SELECT                 ON report_subscriptions_abi to reading;
GRANT SELECT                 ON abi                      to reading;
GRANT TRUNCATE               ON package_notifications    to packaging;
GRANT INSERT                 ON report_log_package_notifications to reading;
GRANT SELECT, UPDATE         ON report_log_package_notifications_id_seq TO reading;
