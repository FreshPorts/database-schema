-- elementGet(): one lookup in element_pathname instead of three Pathname_ID() calls
--
-- elementGet() called Pathname_ID($1) three times: once in its WHERE
-- clause, once for IsCategory() and once for IsPort().  Pathname_ID() walks
-- the path one element at a time in PL/pgSQL, ~5 ms each on freshports.dvl.
-- element_pathname() then rebuilt the pathname the same way.  On
-- production it was the second most expensive statement:
--
--   347,674 calls, 10.73 ms mean, 20.1 s/h (7 days 17 h to 2026-10-28)
--
-- element_pathname already holds the pathname of every element, kept by
-- the element_pathname_insert and element_pathname_update triggers on
-- element, with a unique index on pathname.  elementGetCaseInsensitive()
-- already uses it.  On freshports.dvl, /ports/head/www/nginx/Makefile:
--
--   18.6 ms -> 0.5 ms
--
-- Same name, argument, result type and rows.  Like Pathname_ID(), it
-- accepts a path without the leading slash, or with one trailing slash.
-- Compared with the old version on freshports.dvl: a 0.2% sample of
-- element_pathname (4,786 paths, with variants: no leading slash, one and
-- two trailing slashes, upper case, missing paths) and every category
-- path with and without a trailing slash (130): no differences.
--
-- The only caller is the website: classes/element_record.php,
-- ElementRecord::FetchByName(), for URLs which are not a category or a
-- port.  FreshSource and the ingress scripts do not use it.  Pathname_ID()
-- is unchanged.
--
-- Run as postgres, which owns the function.  CREATE OR REPLACE keeps its
-- owner and grants.  Already on freshports.dvl (2026-10-28).  No
-- website change is needed; deploy order does not matter.
--
-- Function definition is also in sp.txt.
--
-- To undo, restore the previous version:
--   git show 4bccc8a:sp.txt, CREATE OR REPLACE FUNCTION elementGet (text)

\set ON_ERROR_STOP on

BEGIN;

CREATE OR REPLACE FUNCTION elementGet (text) RETURNS SETOF element_type AS $$
   SELECT E.id,
          E.name::text,
          E.directory_file_flag::text,
          E.status::text,
          IsCategory(E.id) IS NOT NULL,
          IsPort(    E.id) IS NOT NULL,
          EP.pathname
     FROM element_pathname EP
     JOIN element          E ON E.id = EP.element_id
    WHERE EP.pathname = regexp_replace(CASE WHEN left($1, 1) = '/' THEN $1 ELSE '/' || $1 END, '(.)/$', '\1');
$$ LANGUAGE SQL STABLE;

COMMIT;
