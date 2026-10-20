-- SanityTestFailures(): LANGUAGE sql, so the planner inlines it
--
-- As PL/pgSQL, every call built every sanity test failure (27,771 rows
-- on production) before the caller's WHERE applied, spilling ~45 MB to
-- temp files.  /sanity_test_failures.php?message_id=... took 638 ms to
-- show 3 rows.  Inlined, the caller's WHERE message_id = ... or
-- commit_log_id = ... reaches the indexes:
--
--   one commit (?message_id=):  638 ms -> 1.7 ms on production
--   one list page:              822 ms -> 65 ms
--
-- Same name, arguments, result type and rows.  The unused watch list
-- subquery is gone; watch was already always 0.
--
-- The website's paged list query (classes/sanity_test_failures.php,
-- CROSS JOIN LATERAL ... OFFSET 0) needs this version: it calls the
-- function once per commit on the page, and the PL/pgSQL version
-- builds every failure on each call.  Apply this before deploying it.
--
-- The index is for the inlined function's per-commit lookups and for
-- the ON DELETE CASCADE from commit_log.  It is not unique: the ingress
-- code inserts without checking for an existing row.  The table is
-- small (1,420 rows), so a plain CREATE INDEX inside the transaction is
-- fine.  Already on production and freshports.dvl, so IF NOT EXISTS.
--
-- Function definition is also in sp.txt, the index in createdb.sql.
--
-- To undo, restore the PL/pgSQL version:
--   git show a8ffebe:sp.txt, CREATE OR REPLACE FUNCTION SanityTestFailures(int)

\set ON_ERROR_STOP on

BEGIN;

CREATE INDEX IF NOT EXISTS sanity_test_failures_commit_log_id ON sanity_test_failures (commit_log_id);

CREATE OR REPLACE FUNCTION SanityTestFailures(int) RETURNS SETOF commit_record AS $$
SELECT CL.id           AS commit_log_id,
       CL.commit_date  AS commit_date_raw,
       CL.message_subject,
       CL.message_id,
       CL.committer,
       CL.committer_name,
       CL.committer_email,
       CL.author_name,
       CL.author_email,
       CL.description  AS commit_description,
       to_char(CL.commit_date - SystemTimeAdjust(), 'DD Mon YYYY')  AS commit_date,
       to_char(CL.commit_date - SystemTimeAdjust(), 'HH24:MI')      AS commit_time,
       CL.encoding_losses,
       P.id            AS port_id,
       CLP.needs_refresh,
       P.forbidden,
       P.broken,
       P.deprecated,
       P.ignore,
       P.element_id,
       CLP.port_version  AS version,
       CLP.port_revision AS revision,
       CLP.port_epoch    AS epoch,
       date_part('epoch', P.date_added)::integer AS date_added,
       P.short_description,
       P.category_id,
       E.name AS port,
       P.status,
       C.name AS category,
       PV.current AS vulnerable_current,
       PV.past    AS vulnerable_past,
       P.restricted,
       P.no_cdrom,
       P.expiration_date,
       P.is_interactive,
       P.only_for_archs,
       P.not_for_archs,
       repo.name,
       CL.svn_revision,
       repo.repository,
       repo.repo_hostname,
       repo.path_to_repo,
       0::bigint AS watch,
       EP.pathname AS element_pathname
  FROM sanity_test_failures STF
  JOIN commit_log           CL  ON CL.id             = STF.commit_log_id
  LEFT OUTER JOIN repo          ON repo.id           = CL.repo_id
  JOIN commit_log_ports     CLP ON CLP.commit_log_id = CL.id
  JOIN ports                P   ON P.id              = CLP.port_id
  JOIN element              E   ON E.id              = P.element_id
  JOIN element_pathname     EP  ON EP.element_id     = P.element_id
  JOIN categories           C   ON C.id              = P.category_id
  LEFT OUTER JOIN ports_vulnerable PV ON PV.port_id  = P.id
$$ LANGUAGE sql STABLE;

COMMIT;
