-- category_history: the physical and virtual categories over time (#604)
--
-- One row per ports commit which changed the set of categories.  The
-- lists are read from the ports tree at that commit:
--
--   physical  the SUBDIR entries in Makefile
--   virtual   VALID_CATEGORIES in Mk/bsd.port.mk, less the physical ones
--
-- virtual is NULL before VALID_CATEGORIES existed (August 1999).
--
-- Filled by scripts/category_history_update.pl, run from periodics
-- daily/235.fp_category_history (fp_category_history_enable="YES").
-- On an empty table it walks the whole ports history (about a minute);
-- after that it starts from the newest row.  By hand, as freshports:
--
--   cd /usr/local/libexec/freshports && perl category_history_update.pl
--
-- Read by www/category-history.php.  Grants are also in permissions.sql.
--
-- To undo:
--   DROP TABLE category_history;

\set ON_ERROR_STOP on

BEGIN;

CREATE TABLE category_history (
    commit_hash  text         PRIMARY KEY,
    commit_date  timestamptz  NOT NULL,
    physical     text[]       NOT NULL,
    virtual      text[]
);

CREATE INDEX category_history_commit_date ON category_history (commit_date);

GRANT SELECT                         ON category_history TO GROUP www;
GRANT SELECT, INSERT, UPDATE, DELETE ON category_history TO GROUP commits;
GRANT SELECT                         ON category_history TO reading;

COMMIT;
