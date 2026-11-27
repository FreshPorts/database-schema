# Encoding repair, November 2026

psql scripts that repaired double-encoded and raw Latin-1 text in the FreshPorts
databases. They were run on every database in November 2026, after
ingress-modules commit 25c4124 (released in 2.3.8) stopped ingest from creating
new damage. They are kept as a record, and so the repair can be repeated on a
database restored from an older backup.

The background, the tests and the results are in two posts on news.freshports.org:

- [GalÃ¨ne: fixing double-encoded port files](https://news.freshports.org/2026/11/21/galene-fixing-double-encoded-port-files/)
- [GalÃ¨ne, part 2: tests passed, old data repaired](https://news.freshports.org/2026/11/26/galene-part-2-tests-passed-old-data-repaired/)

## What was wrong

Every FreshPorts database is `SQL_ASCII`: PostgreSQL stores bytes and does not
check them. Two kinds of bad text had built up:

- **Double-encoded UTF-8.** UTF-8 bytes were read as ISO-8859-1 (Latin-1) and
  each byte was stored as a UTF-8 character of its own, so `è` became `Ã¨`. From
  July 2024 the ingress read every port's Makefile, pkg-message and distinfo
  this way. Pre-git commit messages were damaged the same way, years earlier.
- **Raw Latin-1.** A few values were never UTF-8 at all, such as old
  `# Created by: José` Makefile headers.

Double encoding loses nothing, so it can be undone exactly: convert the text
from UTF-8 back to Latin-1, and the bytes that come out are the original UTF-8.

## The files

Run them in this order, in **one** psql session connected to the database to
repair, as a user that can update these tables. Each repair file opens a
transaction and leaves it open: read the counts it prints, then type `COMMIT;`
or `ROLLBACK;` before running the next file.

- **`00-helpers.sql`**

  Session setup and helper functions, all in `pg_temp`, so they disappear when psql exits. Changes no table.

- **`01-report.sql`**

  Before and after report: for each column the repair touches, how many values are double-encoded, raw Latin-1, or still contain mojibake. Run it first and last.

- **`10-commit-log.sql`**

  Part 1: `commit_log.description` for commits from before the move to git (no `commit_hash_short`). Undoes the double encoding, whole values first, then run by run for values only partly double-encoded. Lists the leftovers it could not fix. Git-era messages are left alone: their mojibake is in the freebsd-ports repository itself.

- **`11-commit-log-leftovers.sql`**

  Part 1b: six pre-git messages Part 1 could not finish. Four were double-encoded twice and get one more pass; two (Krüger, Gábor) have their exact bytes replaced. Keyed on `message_id`, because `commit_log.id` differs between databases.

- **`12-commit-log-eucjp.sql`**

  Part 1c: one 2005 commit whose message is a whole Japanese Handbook chapter in EUC-JP. It is replaced with the original message from FreeBSD doc commit 537770631a, held in the file as EUC-JP hex. It is replaced only if the stored row and the replacement have the same ASCII text, byte for byte.

- **`20-ports.sql`**

  Part 2: `ports.long_description`, `makefile`, `pkgmessage` and `distinfo`; also converts raw Latin-1 in `makefile` and `pkg_plist`. Ends with a check that should return no rows. Run it only on a host whose ingress-modules has 25c4124 (2.3.8 or later), or the next refresh of each port damages it again.

- **`30-generate-plist.sql`**

  Part 3: `generate_plist.installed_file`, and queues the affected port pages for cache clearing (that table has no trigger).

- **`40-users-OPTIONAL.sql`**

  Part 4, commented out and **not run anywhere**: one `users.name` in raw Latin-1. Converting it changes the bytes of that login name.

Triggers on `commit_log` and `ports` queue their own cache clearing. The scripts
queue the port pages that list a repaired commit.

## Results

On every database, the report before the repair showed 300 double-encoded
pre-git commit messages, 67 `long_description` values, 2 raw Latin-1
`pkg_plist` values, and 60 or 61 `generate_plist` file names. `makefile`,
`pkgmessage` and `distinfo` varied by host; see part 2 of the post. After the
repair, every `UPDATE` had touched the number of rows the report predicted, and
the report was zero in every column wherever it was run again.

## Two things learned

- In a PostgreSQL regular expression, `\x` takes every hex digit that follows
  it. `'\x87bor'` reads as byte `\x87b` followed by `or`. Bracket the byte
  instead: `'[\x87]bor'`.
- The run-by-run pass in Part 1 uses `replace()`, which changes every copy of a
  run, including copies inside longer runs. That is safe for Latin-1 text, but
  it damaged the EUC-JP commit beyond repair from the stored bytes alone; hence
  `12-commit-log-eucjp.sql` and its use of the original.
