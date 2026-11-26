\set ON_ERROR_STOP on
-------------------------------------------------------------------
-- Part 1b: pre-git commit messages Part 1 could not finish.
-- Run after 10-commit-log.sql is committed, in the same session.
-- Keyed on message_id: commit_log.id differs between databases.
-- A row that is already right is not matched, so this can run twice.
-------------------------------------------------------------------
BEGIN;

-- Double-encoded twice: one more pass gives the right text.
-- Erik Sjölund, Søren Straarup, an en dash, a non-breaking space.
UPDATE commit_log
   SET description = pg_temp.undo_double(description, pg_temp.double_kind(description))
 WHERE message_id IN ('200501251355.j0PDt7gB049014@repoman.freebsd.org',
                      '200503090909.j2999ivp075066@repoman.freebsd.org',
                      '201105180155.p4I1t01d083435@repoman.freebsd.org',
                      '201103131221.p2DCLbJD005794@repoman.freebsd.org')
   AND pg_temp.double_kind(description) IS NOT NULL;                   -- dvl: 4

-- Mixed encodings: replace the exact bytes with the right name.
-- Gábor: Mac Roman 0x87 (á), then double-encoded.  [\x87] is in brackets
-- because \x takes every hex digit after it: \x87bor would read as \x87b.
UPDATE commit_log
   SET description = regexp_replace(description, 'G\xc3\x82\xc2[\x87]bor', 'Gábor', 'g')
 WHERE message_id = '200412130215.iBD2FGnt099450@repoman.freebsd.org'
   AND description ~ 'G\xc3\x82\xc2[\x87]bor';                              -- dvl: 1
-- Stefan Krüger
UPDATE commit_log
   SET description = regexp_replace(description, 'Kr\xc3\x83\xc5\x92ger', 'Krüger', 'g')
 WHERE message_id = '201201112227.q0BMRiF5063092@repoman.freebsd.org'
   AND description ~ 'Kr\xc3\x83\xc5\x92ger';                             -- dvl: 1

-- port pages that list these commits
INSERT INTO cache_clearing_ports (port_id, category, port)
SELECT DISTINCT PA.id, PA.category, PA.name
  FROM commit_log C JOIN commit_log_ports CLP ON CLP.commit_log_id = C.id
                    JOIN ports_all PA        ON PA.id = CLP.port_id
 WHERE C.message_id IN ('200501251355.j0PDt7gB049014@repoman.freebsd.org',
                        '200503090909.j2999ivp075066@repoman.freebsd.org',
                        '201105180155.p4I1t01d083435@repoman.freebsd.org',
                        '201103131221.p2DCLbJD005794@repoman.freebsd.org',
                        '200412130215.iBD2FGnt099450@repoman.freebsd.org',
                        '201201112227.q0BMRiF5063092@repoman.freebsd.org')
    ON CONFLICT DO NOTHING;
NOTIFY port_updated;

-- check: the names as they now read (expect Sjölund, Søren, Gábor, Krüger)
SELECT message_id,
       substring(description FROM '[\x01-\x7f]{0,20}[\x80-\xff]+[\x01-\x7f]{0,20}') AS now
  FROM commit_log
 WHERE message_id IN ('200501251355.j0PDt7gB049014@repoman.freebsd.org',
                      '200503090909.j2999ivp075066@repoman.freebsd.org',
                      '201105180155.p4I1t01d083435@repoman.freebsd.org',
                      '201103131221.p2DCLbJD005794@repoman.freebsd.org',
                      '200412130215.iBD2FGnt099450@repoman.freebsd.org',
                      '201201112227.q0BMRiF5063092@repoman.freebsd.org');
-- COMMIT;  or  ROLLBACK;
