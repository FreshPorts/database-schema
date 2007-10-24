--
-- $Id: createdb.sql,v 1.92 2007-10-24 12:37:15 dan Exp $
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

create table watch_list_staging_log
(
    id                         serial                not null,
    date_added                 timestamp without time zone not null
        default currenttimestamputc(),
    user_id                    integer                       ,
    action                     char(1)               not null
        check (action in ('U','W','C','D')),
    count_total                integer               not null
        default 0,
    count_matches              integer               not null
        default 0,
    count_missing              integer               not null
        default 0,
    count_duplicates           integer               not null
        default 0,
    count_categories           integer               not null
        default 0,
    primary key (id)
);

create table ports_check
(
    id                         serial                not null,
    category_name              text                  not null,
    port_name                  text                  not null,
    category_id                integer                       ,
    port_id                    integer                       ,
    add_to_ports_table         boolean               not null
        default 'Y',
    primary key (id)
);

create index ports_check_category_id on ports_check (category_id);

create table daily_refreshes
(
    refresh_date               date                  not null,
    primary key (refresh_date)
);

create table graphs
(
    id                         serial                not null,
    title                      text                  not null,
    query                      text                  not null,
    label                      text                          ,
    is_clickable               boolean                       
        default FALSE,
    primary key (id)
);

create table commits_latest
(
    commit_log_id              integer                       ,
    commit_date_raw            timestamp without time zone         ,
    message_subject            text                          ,
    message_id                 text                          ,
    committer                  text                          ,
    commit_description         text                          ,
    commit_date                text                          ,
    commit_time                text                          ,
    element_id                 integer                       ,
    element_name               text                          ,
    revision_name              text                          ,
    status                     char(1)                       ,
    encoding_losses            boolean                       
);

create table announcements
(
    id                         serial                not null,
    text                       text                  not null,
    start_date                 timestamp without time zone         ,
    end_date                   timestamp without time zone         ,
    primary key (id)
);

create table page_load_summary
(
    id                         serial                not null,
    date                       date                  not null,
    page_name                  text                  not null,
    total                      integer               not null
        default 0,
    users                      integer               not null
        default 0,
    rendering_time_min         interval                      ,
    rendering_time_max         interval                      ,
    rendering_time_avg         interval              not null,
    primary key (id)
);

create unique index page_loads_date_date on page_load_summary (date, page_name);

create table commits_latest_ports
(
    commit_log_id              integer               not null,
    commit_date                timestamp without time zone not null
);

create table listen_for
(
    id                         serial                not null,
    name                       text                  not null,
    script_name                text                  not null,
    primary key (id)
);

insert into listen_for (name, script_name) values ('port_updated', 'listen_port');
insert into listen_for (name, script_name) values ('ports_moved', 'listen_ports_moved');
insert into listen_for (name, script_name) values ('ports_updating', 'listen_ports_updating');
insert into listen_for (name, script_name) values ('vuxml', 'listen_vuxml');
insert into listen_for (name, script_name) values ('category_new', 'listen_category_new');

create unique index listen_for_name_idx on listen_for (name);

create table element
(
    id                         serial                not null,
    name                       text                  not null,
    parent_id                  integer                       ,
    status                     char(1)               not null
        check (status in ('A','D')),
    primary key (id)
);

create index element_name on element (name);

create table watch_notice
(
    id                         serial                not null,
    frequency                  char(1)               not null
        check (frequency in ('Z','D','W','F','M')),
    description                text                  not null,
    last_sent                  timestamp without time zone         ,
    primary key (id)
);

INSERT INTO "watch_notice" (id, frequency, description) VALUES (1,'Z','Don''t notify me');
INSERT INTO "watch_notice" (id, frequency, description) VALUES (3,'W','Week (on Tuesdays)');
INSERT INTO "watch_notice" (id, frequency, description) VALUES (4,'F','Fortnightly  (9th and 23rd)');
INSERT INTO "watch_notice" (id, frequency, description) VALUES (5,'M','Month (23rd)');
INSERT INTO "watch_notice" (id, frequency, description) VALUES (2,'D','Day');

create index watch_notice_frequency on watch_notice (frequency);

create table system
(
    id                         serial                not null,
    name                       text                  not null,
    time_adjust                interval              not null
        default '0 seconds',
    primary key (id)
);

INSERT INTO "system" VALUES (1,'FreeBSD','-03:00');

create table daily_stats
(
    id                         serial                not null,
    title                      text                  not null,
    query                      text                  not null,
    primary key (id)
);

create table reports
(
    id                         serial                not null,
    name                       text                  not null,
    description                text                  not null,
    needs_frequency            boolean               not null,
    primary key (id)
);

insert into reports(id, name, description, needs_frequency) values (1, 'Watch List Notification', 'Details of any changes to any items on your watch list', TRUE);

insert into reports(id, name, description, needs_frequency) values (2, 'New Ports', 'Lists the new ports which have been added to the ports tree', TRUE);

insert into reports(id, name, description, needs_frequency) values (3, 'Maintainer notification', 'Port maintainers are notified when their port fails to build (for maintainers only).', FALSE);

insert into reports(id, name, description, needs_frequency) values (4, 'Announcements', 'Very low frequency notices about important changes to the website (highly recommended)', FALSE);

insert into reports(id, name, description, needs_frequency) values (5, 'Security Notices', 'Notification of any security commits related to ports on your watch list.', FALSE);

create table report_frequency
(
    id                         serial                not null,
    frequency                  char(1)               not null,
    description                text                  not null,
    primary key (id)
);

INSERT INTO report_frequency (id, frequency, description) VALUES (1,'Z','Don''t notify me');
INSERT INTO report_frequency (id, frequency, description) VALUES (2,'D','Day');
INSERT INTO report_frequency (id, frequency, description) VALUES (3,'W','Week (on Tuesdays)');
INSERT INTO report_frequency (id, frequency, description) VALUES (4,'F','Fortnightly  (9th and 23rd)');
INSERT INTO report_frequency (id, frequency, description) VALUES (5,'M','Month (23rd)');

create table tasks
(
    id                         serial                not null,
    name                       text                  not null,
    description                text                  not null,
    primary key (id)
);

insert into tasks (name,description) values ('SecurityNoticeAdd', 'Ability to designate a given commit as security related');

insert into tasks (name,description) values ('CategoryVirtualDescriptionSet', 'Ability to set the description for a virtual category');

insert into tasks (name,description) values ('AnnouncementsUpdate', 'Ability to maintain the announcements table');

create unique index tasks_idx on tasks (name);

create table security_notice_status
(
    id                         char(1)               not null,
    name                       text                  not null,
    description                text                  not null,
    primary key (id)
);

insert into security_notice_status (id,name,description) values ('A', 'Active', 'A valid security concern');

insert into security_notice_status (id,name,description) values ('I', 'Ingore', 'Ingore this notice');

insert into security_notice_status (id,name,description) values ('C', 'Candidate', 'A candidate for becoming a security notice');

create table ports_updating
(
    id                         serial                not null,
    date                       date                  not null,
    affects                    text                  not null,
    author                     text                          ,
    reason                     text                  not null,
    primary key (id)
);

create table vuxml
(
    id                         serial                not null,
    vid                        text                  not null,
    topic                      text                  not null,
    description                text                  not null,
    date_discovery             text                          ,
    date_entry                 text                          ,
    date_modified              text                          ,
    status                     char(1)               not null,
    primary key (id)
);

create table releases
(
    id                         serial                not null,
    name                       text                  not null,
    revision                   text                  not null,
    primary key (id)
);

create unique index release_name_idx on releases (name);

create table archs
(
    id                         serial                not null,
    name                       text                  not null,
    primary key (id)
);

insert into archs (name) values ('alpha');
insert into archs (name) values ('amd64');
insert into archs (name) values ('i386');
insert into archs (name) values ('ia64');
insert into archs (name) values ('pc98');
insert into archs (name) values ('ppc');
insert into archs (name) values ('sparc64');

create unique index archs_name_idx on archs (name);

create table port_status
(
    id                         serial                not null,
    name                       text                  not null,
    description                text                  not null,
    primary key (id)
);

insert into port_status (name, description) values ('BROKEN', 'port is broken on this ARCH/RELEASE');
insert into port_status (name, description) values ('ONLY_FOR_ARCHS', 'port works only on these ARCHS');
insert into port_status (name, description) values ('NOT_FOR_ARCHS', 'port does not work on these ARCHS');

create unique index port_status_name_idx on port_status (name);

create table top_questions
(
    id                         serial                not null,
    question                   text                  not null,
    number_of_answers          smallint              not null
        default 1
        check (number_of_answers >= 1),
    primary key (id)
);

create table event_types
(
    id                         serial                not null,
    name                       text                  not null,
    description                text                  not null,
    primary key (id)
);

insert into event_types(name, description) values ('port_updated', 'a port has changed and the cache entry needs to be removed');
insert into event_types(name, description) values ('ports_moved', 'A commit has been performed on /usr/ports/MOVED');
insert into event_types(name, description) values ('ports_updating',  'A commit has been performed on /usr/ports/UPDATING');
insert into event_types(name, description) values ('vuxml',  'A commit has been performed on /usr/ports/security/vuxml/vuln.xml');

create table element_revision
(
    element_id                 integer               not null,
    revision_name              text                  not null,
    primary key (element_id, revision_name)
);

create table categories
(
    id                         serial                not null,
    is_primary                 boolean               not null,
    element_id                 integer                       ,
    name                       text                  not null,
    description                text                          ,
    primary key (id)
);

create table ports
(
    id                         serial                not null,
    element_id                 integer               not null,
    category_id                integer               not null,
    short_description          text                          ,
    long_description           text                          ,
    version                    text                          ,
    revision                   text                          ,
    maintainer                 text                          ,
    homepage                   text                          ,
    master_sites               text                          ,
    extract_suffix             text                          ,
    package_exists             boolean                       ,
    depends_build              text                          ,
    depends_run                text                          ,
    last_commit_id             integer                       ,
    found_in_index             boolean                       ,
    forbidden                  text                          ,
    broken                     text                          ,
    date_added                 timestamp without time zone         
        default currenttimestamputc(),
    categories                 text                          ,
    deprecated                 text                          ,
    ignore                     text                          ,
    master_port                text                          ,
    latest_link                text                          ,
    depends_lib                text                          ,
    no_latest_link             text                          ,
    no_package                 text                          ,
    package_name               text                          ,
    portepoch                  text                          ,
    restricted                 text                          ,
    no_cdrom                   text                          ,
    expiration_date            date                          ,
    is_interactive             text                          ,
    only_for_archs             text                          ,
    not_for_archs              text                          ,
    status                     char(1)               not null
        check (status in ('A','D')),
    primary key (id)
);

create index ports_ignore on ports(ignore) where ignore <> '';
create index ports_broken on ports(broken) where broken <> '';

create index ports_expiration_date on ports(expiration_date) where expiration_date is not null;

create table users
(
    id                         serial                not null,
    name                       text                  not null,
    password                   text                  not null,
    cookie                     text                  not null,
    firstlogin                 timestamp without time zone         
        default currenttimestamputc(),
    lastlogin                  timestamp without time zone         
        default currenttimestamputc(),
    email                      text                          ,
    watch_notice_id            integer               not null,
    emailsitenotices_yn        boolean                       ,
    emailbouncecount           smallint                      
        default 0,
    type                       char(1)               not null
        default 'U'
        check (type in ('U','S')),
    status                     char(1)               not null
        default 'U'
        check (status in ('U','A','D')),
    ip_address                 text                  not null,
    number_of_commits          smallint                      
        default 100,
    number_of_days             smallint                      
        default 9,
    watch_list_add_remove      text                  not null
        default 'default'
        check (watch_list_add_remove in ('ask','default')),
    max_number_watch_lists     integer               not null
        default 5
        check (max_number_watch_lists >= 1),
    last_watch_list_chosen     integer                       ,
    page_size                  smallint              not null
        default 25,
    primary key (id)
);

create index users_cookie on users (cookie);

create index users_email on users (email);

create unique index users_name on users (name);

create table watch_list
(
    id                         serial                not null,
    user_id                    integer               not null,
    name                       text                  not null,
    awaiting_staging           boolean               not null
        default FALSE,
    in_service                 boolean               not null
        default FALSE,
    token                      text                  not null
        default generate_watch_list_token(),
    primary key (id)
);

create unique index watch_list_token on watch_list (token);

create table security_notice
(
    id                         serial                not null,
    user_id                    integer               not null,
    date_added                 timestamp without time zone not null
        default currenttimestamputc(),
    ip_address                 inet                  not null,
    description                text                  not null,
    commit_log_id              integer               not null,
    security_notice_status_id  char(1)               not null
        default 'C',
    primary key (id)
);

create table commit_group
(
    id                         serial                not null,
    user_id                    integer               not null,
    name                       text                  not null,
    primary key (id)
);

create table system_branch
(
    id                         serial                not null,
    system_id                  integer               not null,
    branch_name                text                  not null,
    primary key (id)
);

create table commit_log
(
    id                         serial                not null,
    message_id                 text                  not null,
    message_date               timestamp without time zone not null,
    message_subject            text                          ,
    date_added                 timestamp without time zone not null,
    commit_date                timestamp without time zone not null,
    committer                  text                  not null,
    description                text                  not null,
    system_id                  integer               not null,
    encoding_losses            boolean               not null
        default FALSE,
    primary key (id)
);

create index commit_log_commit_date on commit_log (commit_date);

create unique index commit_log_message_id on commit_log (message_id);

create table vuxml_affected
(
    id                         serial                not null,
    vuxml_id                   integer               not null,
    type                       text                  not null,
    primary key (id)
);

create table commit_log_elements
(
    id                         serial                not null,
    commit_log_id              integer               not null,
    element_id                 integer               not null,
    revision_name              text                  not null,
    change_type                char(1)               not null
        check (change_type in ('A','M','R')),
    primary key (id)
);

create table watch_list_element
(
    watch_list_id              integer               not null,
    element_id                 integer               not null,
    primary key (watch_list_id, element_id)
);

create table watch_notice_log
(
    id                         serial                not null,
    notice_date                timestamp without time zone not null
        default currenttimestamputc(),
    frequency_id               integer               not null,
    watch_notice_count         integer               not null,
    commit_count               integer               not null,
    primary key (id)
);

create table system_branch_element_revision
(
    system_branch_id           integer               not null,
    element_id                 integer               not null,
    revision_name              text                  not null,
    primary key (system_branch_id, element_id, revision_name)
);

create table user_confirmations
(
    user_id                    integer               not null,
    token                      text                  not null,
    primary key (user_id, token)
);

create table commit_log_ports
(
    commit_log_id              integer               not null,
    port_id                    integer               not null,
    needs_refresh              smallint              not null,
    port_version               text                          ,
    port_revision              text                          ,
    port_epoch                 text                          ,
    primary key (commit_log_id, port_id)
);

create index needs_refresh on commit_log_ports (needs_refresh);

create table watch_list_staging
(
    id                         serial                not null,
    user_id                    integer               not null,
    category                   text                  not null,
    port                       text                  not null,
    item_count                 integer               not null,
    from_pkg_info              boolean               not null,
    from_watch_list            boolean               not null,
    element_id                 serial                        ,
    primary key (id)
);

create table daily_stats_data
(
    id                         serial                not null,
    daily_stats_id             integer               not null,
    date                       date                  not null,
    value                      bigint                not null,
    primary key (id)
);

create unique index daily_stats_data_unique on daily_stats_data (daily_stats_id, date);

create table report_log
(
    id                         serial                not null,
    report_id                  integer               not null,
    frequency_id               integer               not null,
    report_date                timestamp without time zone not null
        default currenttimestamputc(),
    email_count                integer               not null,
    commit_count               integer               not null,
    port_count                 integer               not null,
    primary key (id)
);

create table report_subscriptions
(
    report_id                  integer               not null,
    user_id                    integer               not null,
    report_frequency_id        integer               not null,
    primary key (report_id, user_id)
);

create table committer_notify
(
    user_id                    integer               not null,
    committer                  text                  not null,
    status                     char(1)               not null
        default 'A'
        check (status in ('A','D')),
    primary key (user_id)
);

create table element_pathnames
(
    element_id                 integer               not null,
    pathname                   text                  not null,
    primary key (element_id)
);

--
--
-- This may be useful in populating this table:
--    insert into element_pathnames select id, element_pathname(id) from element;
--
--

create unique index element_pathnames_pathname on element_pathnames (pathname);

create table user_tasks
(
    user_id                    integer               not null,
    task_id                    integer               not null,
    primary key (user_id, task_id)
);

create table commit_log_ports_ignore
(
    commit_log_id              integer               not null,
    port_id                    integer               not null,
    date_ignored               timestamp without time zone not null
        default currenttimestamputc(),
    reason                     text                  not null,
    primary key (commit_log_id, port_id)
);

create table latest_commits_ports
(
    commit_log_id              integer               not null,
    commit_date                timestamp without time zone not null,
    primary key (commit_log_id)
);

create table ports_categories
(
    port_id                    integer               not null,
    category_id                integer               not null,
    primary key (port_id, category_id)
);

create table security_notice_audit
(
    id                         serial                not null,
    security_notice_id         integer               not null,
    user_id                    integer               not null,
    date_added                 timestamp without time zone not null
        default currenttimestamputc(),
    ip_address                 inet                  not null,
    description                text                  not null,
    commit_log_id              integer               not null,
    security_notice_status_id  char(1)               not null,
    primary key (id)
);

create table latest_commits
(
    commit_log_id              integer               not null,
    commit_date                timestamp without time zone not null,
    primary key (commit_log_id)
);

create table commit_log_ports_elements
(
    commit_log_id              integer               not null,
    element_id                 integer               not null,
    primary key (commit_log_id, element_id)
);

create table ports_moved
(
    id                         serial                not null,
    from_port_id               integer               not null,
    to_port_id                 integer                       ,
    date                       date                  not null,
    reason                     text                  not null,
    primary key (id)
);

create table page_load_detail
(
    id                         serial                not null,
    date                       date                  not null
        default CURRENT_DATE,
    time                       time                  not null
        default LOCALTIME,
    page_name                  text                  not null,
    user_id                    integer               not null,
    ip_address                 inet                  not null,
    full_url                   text                  not null,
    rendering_time             interval              not null,
    primary key (id)
);

create index page_load_detail_date on page_load_detail (date);

create index page_load_ip_address on page_load_detail (ip_address);

create table ports_updating_ports_xref
(
    ports_updating_id          integer               not null,
    port_id                    integer               not null,
    primary key (ports_updating_id, port_id)
);

create table commit_log_ports_vuxml
(
    id                         serial                not null,
    commit_log_id              integer               not null,
    port_id                    integer               not null,
    vuxml_id                   integer               not null,
    primary key (id)
);

create table vuxml_ranges
(
    id                         serial                not null,
    vuxml_affected_id          integer               not null,
    operator1                  text                  not null,
    version1                   text                  not null,
    operator2                  text                          ,
    version2                   text                          ,
    primary key (id)
);

create table vuxml_references
(
    id                         serial                not null,
    vuxml_id                   integer               not null,
    type                       text                  not null,
    reference                  text                  not null,
    primary key (id)
);

create table vuxml_names
(
    id                         serial                not null,
    vuxml_affected_id          integer               not null,
    name                       text                  not null,
    primary key (id)
);

create index vuxml_names_name on vuxml_names (name);

create table ports_vulnerable
(
    port_id                    integer               not null,
    current                    integer               not null
        default 1,
    past                       integer               not null
        default 0,
    primary key (port_id)
);

create table arch_release_port_status
(
    port_id                    integer               not null,
    arch_id                    integer               not null,
    release_id                 integer               not null,
    status_id                  integer               not null,
    message                    text                  not null,
    primary key (port_id, arch_id, release_id, status_id)
);

create table element_pathname
(
    element_id                 integer               not null,
    pathname                   text                  not null,
    primary key (element_id)
);

create table top_answers
(
    user_id                    integer               not null,
    top_question_id            integer               not null,
    seq                        smallint              not null,
    port_id                    integer               not null,
    primary key (user_id, top_question_id, seq)
);

create table events
(
    id                         serial                not null,
    event_type_id              integer               not null,
    date_added                 timestamp without time zone not null,
    primary key (id)
);

create table cache_clearing_ports
(
    id                         serial                not null,
    port_id                    integer               not null,
    category                   text                  not null,
    port                       text                  not null,
    date_added                 timestamp without time zone not null
        default CURRENT_TIMESTAMP,
    primary key (id)
);

create table sanity_test_failures
(
    id                         serial                not null,
    commit_log_id              integer               not null,
    message                    text                  not null,
    primary key (id)
);

create table commit_group_contents
(
    commit_group_id            integer               not null,
    commit_log_id              integer               not null,
    date                       date                          ,
    comment                    text                          ,
    primary key (commit_group_id, commit_log_id)
);

create table master_slave
(
    master_port_id             integer               not null,
    slave_port_id              integer               not null,
    primary key (master_port_id, slave_port_id)
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

alter table element
    add foreign key  (parent_id)
       references element (id) on update cascade on delete cascade;

alter table element_revision
    add foreign key  (element_id)
       references element (id) on update cascade on delete cascade;

alter table categories
    add foreign key  (element_id)
       references element (id) on update cascade on delete cascade;

alter table ports
    add foreign key  (element_id)
       references element (id) on update cascade on delete cascade;

alter table ports
    add foreign key  (category_id)
       references categories (id) on update cascade on delete cascade;

alter table users
    add foreign key  (watch_notice_id)
       references watch_notice (id) on update cascade on delete cascade;

alter table users
    add foreign key  (last_watch_list_chosen)
       references watch_list (id) on update cascade on delete set null;

alter table watch_list
    add foreign key  (user_id)
       references users (id) on update cascade on delete cascade;

alter table security_notice
    add foreign key  (user_id)
       references users (id) on update cascade on delete cascade;

alter table security_notice
    add foreign key  (commit_log_id)
       references commit_log (id) on update cascade on delete cascade;

alter table security_notice
    add foreign key  (security_notice_status_id)
       references security_notice_status (id) on update restrict on delete restrict;

alter table commit_group
    add foreign key  (user_id)
       references users (id) on update cascade on delete cascade;

alter table system_branch
    add foreign key  (system_id)
       references system (id) on update cascade on delete cascade;

alter table commit_log
    add foreign key  (system_id)
       references system (id) on update cascade on delete cascade;

alter table vuxml_affected
    add foreign key  (vuxml_id)
       references vuxml (id) on update cascade on delete cascade;

alter table commit_log_elements
    add foreign key  (commit_log_id)
       references commit_log (id) on update cascade on delete cascade;

alter table commit_log_elements
    add foreign key  (element_id, revision_name)
       references element_revision (element_id, revision_name) on update cascade on delete cascade;

alter table watch_list_element
    add foreign key  (element_id)
       references element (id) on update cascade on delete cascade;

alter table watch_list_element
    add foreign key  (watch_list_id)
       references watch_list (id) on update cascade on delete cascade;

alter table watch_notice_log
    add foreign key  (frequency_id)
       references watch_notice (id) on update cascade on delete cascade;

alter table system_branch_element_revision
    add foreign key  (system_branch_id)
       references system_branch (id) on update cascade on delete cascade;

alter table system_branch_element_revision
    add foreign key  (element_id, revision_name)
       references element_revision (element_id, revision_name) on update cascade on delete cascade;

alter table user_confirmations
    add foreign key  (user_id)
       references users (id) on update cascade on delete cascade;

alter table commit_log_ports
    add foreign key  (commit_log_id)
       references commit_log (id) on update cascade on delete cascade;

alter table commit_log_ports
    add foreign key  (port_id)
       references ports (id) on update cascade on delete cascade;

alter table watch_list_staging
    add foreign key  (element_id)
       references element (id) on update cascade on delete set null;

alter table watch_list_staging
    add foreign key  (user_id)
       references users (id) on update cascade on delete cascade;

alter table daily_stats_data
    add foreign key  (daily_stats_id)
       references daily_stats (id) on update cascade on delete cascade;

alter table daily_stats_data
    add foreign key  (daily_stats_id)
       references daily_stats (id) on update cascade on delete cascade;

alter table report_log
    add foreign key  (report_id)
       references reports (id) on update cascade on delete cascade;

alter table report_log
    add foreign key  (frequency_id)
       references report_frequency (id) on update cascade on delete cascade;

alter table report_log
    add foreign key  (report_id)
       references reports (id) on update restrict on delete restrict;

alter table report_log
    add foreign key  (frequency_id)
       references report_frequency (id) on update restrict on delete restrict;

alter table report_subscriptions
    add foreign key  (report_id)
       references reports (id) on update cascade on delete cascade;

alter table report_subscriptions
    add foreign key  (user_id)
       references users (id) on update cascade on delete cascade;

alter table report_subscriptions
    add foreign key  (report_frequency_id)
       references report_frequency (id) on update cascade on delete cascade;

alter table report_subscriptions
    add foreign key  (report_id)
       references reports (id) on update restrict on delete restrict;

alter table report_subscriptions
    add foreign key  (report_frequency_id)
       references report_frequency (id) on update restrict on delete restrict;

alter table committer_notify
    add foreign key  (user_id)
       references users (id) on update cascade on delete cascade;

alter table element_pathnames
    add foreign key  (element_id)
       references element (id) on update cascade on delete cascade;

alter table user_tasks
    add foreign key  (user_id)
       references users (id) on update cascade on delete cascade;

alter table user_tasks
    add foreign key  (task_id)
       references tasks (id) on update cascade on delete cascade;

alter table commit_log_ports_ignore
    add foreign key  (port_id)
       references ports (id) on update cascade on delete cascade;

alter table commit_log_ports_ignore
    add foreign key  (commit_log_id)
       references commit_log (id) on update cascade on delete cascade;

alter table latest_commits_ports
    add foreign key  (commit_log_id)
       references commit_log (id) on update cascade on delete cascade;

alter table ports_categories
    add foreign key  (port_id)
       references ports (id) on update cascade on delete cascade;

alter table ports_categories
    add foreign key  (category_id)
       references categories (id) on update cascade on delete cascade;

alter table security_notice_audit
    add foreign key  (security_notice_id)
       references security_notice (id) on update cascade on delete cascade;

alter table security_notice_audit
    add foreign key  (security_notice_status_id)
       references security_notice_status (id) on update restrict on delete restrict;

alter table latest_commits
    add foreign key  (commit_log_id)
       references commit_log (id) on update cascade on delete cascade;

alter table commit_log_ports_elements
    add foreign key  (commit_log_id)
       references commit_log (id) on update cascade on delete cascade;

alter table commit_log_ports_elements
    add foreign key  (element_id)
       references element (id) on update cascade on delete cascade;

alter table ports_moved
    add foreign key  (from_port_id)
       references ports (id) on update cascade on delete cascade;

alter table ports_moved
    add foreign key  (to_port_id)
       references ports (id) on update cascade on delete cascade;

alter table page_load_detail
    add foreign key  (user_id)
       references users (id) on update cascade on delete cascade;

alter table ports_updating_ports_xref
    add foreign key  (port_id)
       references ports (id) on update cascade on delete cascade;

alter table ports_updating_ports_xref
    add foreign key  (ports_updating_id)
       references ports_updating (id) on update cascade on delete cascade;

alter table commit_log_ports_vuxml
    add foreign key  (vuxml_id)
       references vuxml (id) on update cascade on delete cascade;

alter table commit_log_ports_vuxml
    add foreign key  (port_id)
       references ports (id) on update cascade on delete cascade;

alter table commit_log_ports_vuxml
    add foreign key  (commit_log_id)
       references commit_log (id) on update cascade on delete cascade;

alter table vuxml_ranges
    add foreign key  (vuxml_affected_id)
       references vuxml_affected (id) on update cascade on delete cascade;

alter table vuxml_references
    add foreign key  (vuxml_id)
       references vuxml (id) on update cascade on delete cascade;

alter table vuxml_names
    add foreign key  (vuxml_affected_id)
       references vuxml_affected (id) on update cascade on delete cascade;

alter table ports_vulnerable
    add foreign key  (port_id)
       references ports (id) on update restrict on delete cascade;

alter table arch_release_port_status
    add foreign key  (release_id)
       references releases (id) on update cascade on delete cascade;

alter table arch_release_port_status
    add foreign key  (arch_id)
       references archs (id) on update cascade on delete cascade;

alter table arch_release_port_status
    add foreign key  (port_id)
       references ports (id) on update cascade on delete cascade;

alter table arch_release_port_status
    add foreign key  (status_id)
       references port_status (id) on update cascade on delete cascade;

alter table element_pathname
    add foreign key  (element_id)
       references element (id) on update cascade on delete cascade;

alter table top_answers
    add foreign key  (top_question_id)
       references top_questions (id) on update cascade on delete cascade;

alter table top_answers
    add foreign key  (user_id)
       references users (id) on update cascade on delete cascade;

alter table top_answers
    add foreign key  (port_id)
       references ports (id) on update cascade on delete cascade;

alter table events
    add foreign key  (event_type_id)
       references event_types (id) on update restrict on delete restrict;

alter table cache_clearing_ports
    add foreign key  (port_id)
       references ports (id) on update cascade on delete cascade;

alter table sanity_test_failures
    add foreign key  (commit_log_id)
       references commit_log (id) on update restrict on delete cascade;

alter table commit_group_contents
    add foreign key  (commit_group_id)
       references commit_group (id) on update cascade on delete cascade;

alter table commit_group_contents
    add foreign key  (commit_log_id)
       references commit_log (id) on update cascade on delete cascade;

alter table master_slave
    add foreign key  (master_port_id)
       references ports (id) on update cascade on delete cascade;

alter table master_slave
    add foreign key  (slave_port_id)
       references ports (id) on update cascade on delete cascade;

