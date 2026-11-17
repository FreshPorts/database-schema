-- committer opt-in: confirmed by mail to <committer>@FreeBSD.org
--
-- Until now, anyone logged in to FreshPorts could opt any committer login
-- into the sanity-test mail on committer-opt-in.php: the page only checked
-- that the account's own address ended in @FreeBSD.org, which nothing
-- confirms, and the login came from the form.  Only production sends these
-- mails to committers (CommitterNotify = 1).
--
-- Now a new or changed opt-in is stored as pending (status 'P') and a link
-- is mailed to <committer>@FreeBSD.org.  Only when that link is used does
-- the opt-in become active (status 'A').  ingress (committer_opt_in.pm)
-- mails only active opt-ins, and each mail carries a link to stop them.
--
-- token is the secret in those links.  Existing rows stay active and each
-- gets its own token here (the default is evaluated once per row), so the
-- committers already opted in notice nothing until their next mail, which
-- now ends with the opt-out link.
--
-- gen_random_bytes() is from pgcrypto, already installed (createdb.sql).
-- Install this before the www and ingress-modules releases which use it.
--
-- Run as postgres, on every database.

\set ON_ERROR_STOP on

BEGIN;

ALTER TABLE committer_notify
  ADD COLUMN token         text                     NOT NULL DEFAULT encode(gen_random_bytes(32), 'hex'),
  ADD COLUMN token_created timestamp with time zone NOT NULL DEFAULT now();

ALTER TABLE committer_notify
  ADD CONSTRAINT committer_notify_status CHECK (status = 'P' OR status = 'A');

CREATE UNIQUE INDEX committer_notify_token ON committer_notify USING btree (token);

COMMENT ON COLUMN committer_notify.status IS 'P: pending, waiting for the committer to confirm by the link mailed to <committer>@FreeBSD.org; A: active, sanity-test mail is sent';
COMMENT ON COLUMN committer_notify.token IS 'secret in the confirm and opt-out links; also identifies the row on committer-notify.php';

COMMIT;

-- check: every row has a distinct token, and how many are active
SELECT status, count(*), count(DISTINCT token) FROM committer_notify GROUP BY status;
