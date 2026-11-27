-- package_notifications_delete(): record deleted packages again
-- (https://github.com/FreshPorts/freshports/issues/449, follow-up to
-- https://github.com/FreshPorts/freshports/issues/642)
--
-- When a repo is imported, triggers on packages record each change in
-- package_notifications, and report-notification-packages.pl mails it to
-- the users who follow that ABI.  The report knows three actions: insert,
-- update and delete ("package not found in this repo build").
--
-- No delete has ever been recorded since October 2025.  For #642 the
-- AFTER DELETE trigger was given a guard, IF new.abi_id IS NOT NULL, so
-- that deleting an ABI would not fail on the foreign key to abi.  NEW is
-- always NULL in a DELETE trigger, so the guard was always false.
--
-- The new guard checks that the row's ABI and port still exist.  Deleting
-- an ABI (refresh-abi.sh) or a port cascades to packages; those rows are
-- still skipped, as #642 intended.  Every other deleted package is
-- recorded again.
--
-- What anyone sees: after the next import of each repo, subscribers'
-- package notification mails list packages which have left that repo
-- build as "delete", alongside insert and update.  Nothing else changes.
-- The daily PackagesDeleteForMissingRepos() now also fills
-- package_notifications, but nothing reports those rows: the next import
-- truncates the table first (UpdatePackagesFromRawPackages.py).
--
-- Run as postgres, which owns the function.  CREATE OR REPLACE keeps its
-- owner and the trigger which calls it.  No script or website change.
--
-- Also in ri.txt.
--
-- To undo, restore the previous version from ri.txt before this change.

\set ON_ERROR_STOP on

BEGIN;

CREATE OR REPLACE FUNCTION package_notifications_delete() RETURNS TRIGGER AS $$
   BEGIN
        -- by definition, this is a delete
        --
        -- Skip the row when its ABI or port is gone: deleting an ABI (see
        -- refresh-abi.sh) or a port cascades to packages, and the insert
        -- would fail the foreign keys on package_notifications, e.g.
        -- Key (abi_id)=(24) is not present in table "abi".
        -- re https://github.com/FreshPorts/freshports/issues/642
        --
        -- This used to test NEW.abi_id.  NEW is always NULL in a DELETE
        -- trigger, so no delete was ever recorded and subscribers never
        -- saw "delete" in their package notifications.
        -- re https://github.com/FreshPorts/freshports/issues/449
        --
        IF EXISTS (SELECT 1 FROM abi   WHERE id = OLD.abi_id)
       AND EXISTS (SELECT 1 FROM ports WHERE id = OLD.port_id) THEN
                insert into package_notifications(abi_id, package_set, port_id, action, version_previous)
                values (OLD.abi_id, OLD.package_set, OLD.port_id, 'delete', OLD.package_version)
                ON CONFLICT ON CONSTRAINT package_notifications_abi_set_port_idx DO NOTHING;
        END IF;

        RETURN OLD;
   END
$$ LANGUAGE 'plpgsql';

COMMIT;
