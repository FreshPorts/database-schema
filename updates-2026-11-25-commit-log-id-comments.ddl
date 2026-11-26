-- commit_log: describe the four columns which identify a commit
--
-- FreshPorts has gone CVS -> Subversion -> git, and each move added a way
-- of naming a commit.  This puts what each column holds, era by era, on
-- the columns themselves; createdb.sql carries the same comments.  It
-- only sets comments: no data or behaviour changes, and nothing anyone
-- sees on the website changes.
--
--   column              CVS            Subversion          git
--   message_id          email Msg-ID   email Msg-ID        full git hash
--   svn_revision        NULL           revision number     full git hash
--   commit_hash_short   NULL           commit_hash, 12 ch  git's own short hash
--   commit_hash         NULL           full git hash       NULL
--
-- It replaces the old comment on commit_hash_short ("the short version of
-- the git hash stored in svn_revision ... If null/empty, it is not a git
-- hash"), which became wrong when the #660 backfill gave 262508
-- Subversion-era rows a short hash.
--
-- Run as postgres, which owns commit_log (COMMENT needs the owner).
--
-- Safe to run more than once.  Check the current comments first with:
--
--   \d+ commit_log
--
-- To undo: COMMENT ON COLUMN commit_log.<column> IS NULL; for
-- commit_hash_short, put back the old text quoted above.

\set ON_ERROR_STOP on

BEGIN;

COMMENT ON COLUMN commit_log.message_id IS
'The column which identifies a commit: NOT NULL and UNIQUE (constraint
commit_log_message_id).  svn_revision, commit_hash and commit_hash_short
can be NULL and repeat, so none of them can stand in for it.  Ingress
looks commits up by it and refuses duplicates.  CVS and Subversion
commits: the Message-ID of the commit email (the oldest CVS commits,
from before emails were kept, have a made-up
fp1.<n>@dev.null.freshports.org, where <n> is not commit_log.id).  git
commits: the full git hash.  The website tells git commits from older
ones by this value.  Commit pages are /commit.php?message_id=<this>.';

COMMENT ON COLUMN commit_log.svn_revision IS
'Subversion commits: the revision number.  git commits: the full git
hash, the same as message_id.  CVS commits: NULL.';

COMMENT ON COLUMN commit_log.commit_hash_short IS
'git commits: the abbreviated hash exactly as the git repository gave it
when the commit was processed.  Its length (7 to 11 so far) grows as git
needs longer abbreviations to stay unique, so it cannot be recomputed
from the full hash; this column is the only copy.  Subversion commits:
the first 12 characters of commit_hash, set by the #660 backfill (NULL
for the few with no git commit).  CVS commits: NULL.';

COMMENT ON COLUMN commit_log.commit_hash IS
'Subversion commits only: the full hash of the same commit in the git
repository, so the website can link to git as well as svnweb (#660,
#661).  Filled once by the #660 backfill; ingress never writes it, so
reprocessing a Subversion-era commit leaves it NULL.  NULL for CVS and
git commits (a git commit''s hash is in message_id and svn_revision) and
for the Subversion commits with no git equivalent, such as branch
creations.';

COMMIT;
