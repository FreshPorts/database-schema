-- FUNCTION: public.portpackages(integer)

ALTER TYPE public.package_sets ADD VALUE 'kmod' AFTER 'quarterly';

DROP FUNCTION IF EXISTS public.portpackages(integer);

CREATE OR REPLACE FUNCTION public.portpackages(
	a_port_id integer)
    RETURNS TABLE(package_name text, abi text, package_version_kmod text, package_version_latest text, package_version_quarterly text, last_checked_kmod text, repo_date_kmod text, import_date_kmod text, processed_date_kmod text, last_checked_latest text, repo_date_latest text, import_date_latest text, processed_date_latest text, last_checked_quarterly text, repo_date_quarterly text, import_date_quarterly text, processed_date_quarterly text) 
    LANGUAGE 'sql'
    COST 100
    STABLE PARALLEL UNSAFE
    ROWS 1000

AS $BODY$
    WITH
      pkg AS (SELECT * FROM packages WHERE port_id = a_port_id)
    SELECT pn.package_name,
           abi.name AS abi,
           max(pkg.package_version)           FILTER (WHERE pkg.package_set = 'kmod')      AS package_version_kmod,
           max(pkg.package_version)           FILTER (WHERE pkg.package_set = 'latest')    AS package_version_latest,
           max(pkg.package_version)           FILTER (WHERE pkg.package_set = 'quarterly') AS package_version_quarterly,

           max(iso_date(PLC.last_checked))    FILTER (where PLC.package_set = 'kmod')      AS last_checked_kmod,
           max(iso_date(PLC.repo_date))       FILTER (where PLC.package_set = 'kmod')      AS repo_date_kmod,
           max(iso_date(PLC.import_date))     FILTER (where PLC.package_set = 'kmod')      AS import_date_kmod,
           max(iso_date(PLC.processed_date))  FILTER (where PLC.package_set = 'kmod')      AS processed_date_kmod,

           max(iso_date(PLC.last_checked))    FILTER (where PLC.package_set = 'latest')    AS last_checked_latest,
           max(iso_date(PLC.repo_date))       FILTER (where PLC.package_set = 'latest')    AS repo_date_latest,
           max(iso_date(PLC.import_date))     FILTER (where PLC.package_set = 'latest')    AS import_date_latest,
           max(iso_date(PLC.processed_date))  FILTER (where PLC.package_set = 'latest')    AS processed_date_latest,

           max(iso_date(PLC.last_checked))    FILTER (where PLC.package_set = 'quarterly') AS last_checked_quarterly,
           max(iso_date(PLC.repo_date))       FILTER (where PLC.package_set = 'quarterly') AS repo_date_quarterly,
           max(iso_date(PLC.import_date))     FILTER (where PLC.package_set = 'quarterly') AS import_date_quarterly,
           max(iso_date(PLC.processed_date))  FILTER (where PLC.package_set = 'quarterly') AS processed_date_quarterly
      FROM abi
           CROSS JOIN (SELECT DISTINCT package_name FROM pkg) pn
           LEFT JOIN pkg ON (pkg.abi_id = abi.id AND pkg.package_name = pn.package_name)
           JOIN packages_last_checked PLC ON PLC.abi_id  = abi.id
     GROUP BY pn.package_name, abi.name
     ORDER BY pn.package_name, abi.name;
$BODY$;

ALTER FUNCTION public.portpackages(integer)
    OWNER TO postgres;


-- FUNCTION: public.getrepostoreview()

-- DROP FUNCTION IF EXISTS public.getrepostoreview();

CREATE OR REPLACE FUNCTION public.getrepostoreview(
	)
    RETURNS TABLE(abi_name text, package_set package_sets) 
    LANGUAGE 'sql'
    COST 100
    STABLE PARALLEL UNSAFE
    ROWS 1000

AS $BODY$
  SELECT name, 'latest'::package_sets AS package_set
    FROM ABI 
   WHERE active 
UNION
  SELECT name, 'quarterly'::package_sets AS package_set
    FROM ABI
   WHERE active
UNION
  SELECT name, 'kmod'::package_sets AS package_set
    FROM ABI
   WHERE active

ORDER BY name, package_set;
$BODY$;

ALTER FUNCTION public.getrepostoreview()
    OWNER TO postgres;


  DROP TRIGGER IF EXISTS ports_origin_maintain ON ports;
CREATE TRIGGER ports_origin_maintain
    AFTER UPDATE OR INSERT ON ports
    FOR EACH ROW
    EXECUTE PROCEDURE ports_origin_maintain();

CREATE OR REPLACE FUNCTION packages_last_checked_maintain() RETURNS TRIGGER AS $$
BEGIN
   IF TG_OP = 'INSERT' THEN
      INSERT INTO packages_last_checked(abi_id, package_set)
            VALUES (NEW.id, 'latest'),
                   (NEW.id, 'quarterly'),
                   (NEW.id, 'kmod');
   END IF;

   RETURN NEW;
END
$$ LANGUAGE 'plpgsql';


-- make sure we update this table!

insert into packages_last_checked(abi_id, package_set)
select id, 'kmod' from abi;