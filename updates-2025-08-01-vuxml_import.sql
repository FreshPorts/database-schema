-- re https://news.freshports.org/2025/07/30/how-freshports-processes-vuxml-entries/
--    https://github.com/FreshPorts/freshports/issues/633
--
-- Table: public.vuxml_import

-- DROP TABLE IF EXISTS public.vuxml_import;

CREATE TABLE IF NOT EXISTS public.vuxml_import
(
    vid text COLLATE pg_catalog."default" NOT NULL,
    checksum text COLLATE pg_catalog."default" NOT NULL,
    CONSTRAINT vuxml_import_vid PRIMARY KEY (vid)
)

TABLESPACE pg_default;

ALTER TABLE IF EXISTS public.vuxml_import
    OWNER to postgres;

REVOKE ALL ON TABLE public.vuxml_import FROM commits;
REVOKE ALL ON TABLE public.vuxml_import FROM rsyncer;

GRANT INSERT, DELETE, SELECT, UPDATE, TRUNCATE ON TABLE public.vuxml_import TO commits;

GRANT ALL ON TABLE public.vuxml_import TO postgres;

GRANT SELECT ON TABLE public.vuxml_import TO rsyncer;

-- DROP INDEX IF EXISTS public.vuxml_import_vid;

CREATE INDEX IF NOT EXISTS vuxml_import_vid
    ON public.vuxml_import USING btree
    (vid COLLATE pg_catalog."default" ASC NULLS LAST)
    TABLESPACE pg_default;


grant truncate on vuxml_import to commits;

-- delete the deleted vids.

CREATE OR REPLACE FUNCTION DeleteMissingVuxml() returns int4 AS $$
DECLARE
    RowCount    int8;

BEGIN

    -- if it's not in vuxml_import, remove it from vuxml

    WITH deleted_vids AS (
    SELECT V.vid, V.checksum
      FROM vuxml V
    LEFT OUTER JOIN vuxml_import vi
    ON V.vid = vi.vid
    WHERE vi.vid IS NULL
    )
    DELETE from vuxml V
     USING deleted_vids as DV
     WHERE V.vid = DV.vid;

    GET DIAGNOSTICS RowCount = ROW_COUNT;
    
    RETURN RowCount;
END
$$ LANGUAGE 'plpgsql';

CREATE OR REPLACE FUNCTION GetListOfVulnsForUpdate() returns SETOF text AS $$

-- return a list of vid for updating

SELECT vi.vid
  FROM vuxml_import vi
LEFT OUTER JOIN vuxml
ON vuxml.vid = vi.vid
WHERE vuxml.checksum <> vi.checksum
union
SELECT vi.vid
  FROM vuxml_import vi
LEFT OUTER JOIN vuxml
ON vuxml.vid = vi.vid
WHERE vuxml.vid IS NULL;

$$ LANGUAGE SQL STABLE;
