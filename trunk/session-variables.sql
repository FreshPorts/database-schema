-- from http://www.depesz.com/2009/08/20/getting-session-variables-without-touching-postgresql-conf/
-- see also http://news.freshports.org/2014/01/28/multiple-repos-good-progress/

CREATE SCHEMA session_variables;

 

CREATE OR REPLACE FUNCTION session_variables.create_table() RETURNS VOID as $$

DECLARE

    temprec RECORD;

BEGIN

    LOOP

        SELECT c.relname, n.nspname INTO temprec

            FROM pg_class c join pg_namespace n on c.relnamespace = n.oid

            WHERE c.relkind = 'r' AND c.relname = '_session_variables_data' AND n.nspname ~ '^pg_temp_';

        IF FOUND THEN

            RETURN;

        END IF;

        BEGIN

            EXECUTE 'CREATE TEMP TABLE _session_variables_data(variable_name TEXT PRIMARY KEY, variable_value TEXT, expires_on TIMESTAMPTZ NOT NULL)';

            EXECUTE 'CREATE INDEX session_variables_data_expires_on ON _session_variables_data ( expires_on )';

            RETURN;

        EXCEPTION

            WHEN duplicate_table THEN

                -- ignore, retry loop

        END;

    END LOOP;

END;

$$ language plpgsql;

 

CREATE OR REPLACE FUNCTION session_variables.cleanup() RETURNS void as $$

BEGIN

    PERFORM session_variables.create_table();

    EXECUTE 'TRUNCATE _session_variables_data';

    RETURN;

END;

$$ language plpgsql;

 

CREATE OR REPLACE FUNCTION session_variables.expire() RETURNS void as $$

BEGIN

    PERFORM session_variables.create_table();

    EXECUTE 'DELETE FROM _session_variables_data WHERE expires_on < ' || quote_literal(clock_timestamp());

    RETURN;

END;

$$ language plpgsql;

 

CREATE OR REPLACE FUNCTION session_variables.set_value( IN _name TEXT, IN _value TEXT, IN _expires TIMESTAMPTZ ) RETURNS void as $$

DECLARE

    tempint INT4;

BEGIN

    PERFORM session_variables.expire();

    LOOP

        EXECUTE 'UPDATE _session_variables_data SET variable_value = $2, expires_on = $3 WHERE variable_name = $1' USING _name, _value, _expires;

        GET DIAGNOSTICS tempint = ROW_COUNT;

        IF tempint > 0 THEN

            RETURN;

        END IF;

        BEGIN

            EXECUTE 'INSERT INTO _session_variables_data( variable_name, variable_value, expires_on) VALUES ($1, $2, $3 )' USING _name, _value, _expires;

            RETURN;

        EXCEPTION

            WHEN unique_violation THEN

                -- ignore

        END;

    END LOOP;

END;

$$ language plpgsql;

 

CREATE OR REPLACE FUNCTION session_variables.set_value( TEXT, TEXT ) RETURNS void as $$

    SELECT session_variables.set_value($1, $2, 'infinity');

$$ language sql;

 

CREATE OR REPLACE FUNCTION session_variables.get_value( IN _name TEXT ) RETURNS TEXT as $$

DECLARE

    reply TEXT;

BEGIN

    PERFORM session_variables.expire();

    EXECUTE 'SELECT variable_value FROM _session_variables_data WHERE variable_name = $1' INTO reply USING _name;

    RETURN reply;

END;

$$ language plpgsql;


CREATE OR REPLACE FUNCTION freshports_branch_set( TEXT ) RETURNS void as $$

   SELECT session_variables.set_value('branch', $1);

$$ language sql;

CREATE OR REPLACE FUNCTION freshports_branch_get() RETURNS TEXT as $$

DECLARE
    reply TEXT;
    
BEGIN

   reply := session_variables.get_value( 'branch' );
   
   IF reply IS NULL THEN
      reply := 'head';
   END IF;
   
   RETURN reply;

END;

$$ language plpgsql;
