--
-- $Id: createdb.sql,v 1.40 2003-02-17 20:52:48 dan Exp $
--
-- The following options should be used to create the database schema
--
-- Under tables:
--  For Create Table
--   uncheck the following
--    - Alternate Key
--    - Physical Options
--    - Comment
--    - Drop table
--
--  For Create Index
--   uncheck the following
--    - Primary Key
--    - Foreign Key
--    - Drop Index
--
-- Under Views check this::
--  Check the following:
--    - Create view
--
-- Under columns check this:
--    - Default value
--    - Check

create table commits_latest
(
    commit_log_id       int4                          ,
    commit_date_raw     timestamp                     ,
    message_subject     text                          ,
    message_id          text                          ,
    committer           text                          ,
    commit_description  text                          ,
    commit_date         text                          ,
    commit_time         text                          ,
    element_id          int4                          ,
    element_name        text                          ,
    revision_name       text                          ,
    status              char(1)                       ,
    encoding_losses     boolean                       
);

create view commits_recent as
select distinct commit_log.id, commit_log.message_id, commit_log.message_date,
commit_log.message_subject, commit_log.date_added, commit_log.commit_date,
commit_log.committer, commit_log.description, commit_log.system_id, commit_log.encoding_losses
from commit_log
where exists
(select * from commit_log_ports where commit_log_ports.commit_log_id = commit_log.id)
order by commit_log.commit_date desc, commit_log.id limit 100;;

create view ports_active as
select ports.*, element.name as name, categories.name as category
from categories, ports, element
where element.status = 'A'
and categories.id = ports.category_id
and ports.element_id = element.id;

create view ports_all as
select ports.*, element.name as name, categories.name as category, element.status
from categories, ports, element
where categories.id = ports.category_id
and ports.element_id = element.id;

create view report_log_latest as
select report_log.report_id, report_log.frequency_id, report_frequency.frequency, 
max(report_log.report_date) AS last_sent
from report_log, report_frequency
where ( report_log.frequency_id = report_frequency.id )
group by report_log.report_id, report_log.frequency_id, report_frequency.frequency;;

