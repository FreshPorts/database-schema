#
# $Id: createdb.sql,v 1.35 2002-07-26 21:21:39 dan Exp $
#
# Things which must be done to make this script work with PostgreSQL
# 
# remove asc from indexes. ' asc);' => ');'
#                          ' asc,' => ','
# remove quotes from around 'current_timestamp'
# remove key names from foreign keys
# in ports_active, put quotes around status.
#
# The following options should be used to create the database schema
#
# Under tables:
#  For Create Table
#   uncheck the following
#    - Alternate Key
#    - Physical Options
#    - Comment
#    - Drop table
#  For Create Index
#   uncheck the following
#    - Primary Key
#    - Foreign Key
#    - Drop Index
#
# Under Views:
#  Check the following:
#    - Create view
#    - Default value
#    - Check

create table housekeeping
(
    last_port_commit       int4                  not null,
    refresh_now            smallint              not null
);

insert into housekeeping values (0,0);

create table commits_latest_ports
(
    commit_date_raw        timestamp                     ,
    commit_log_id          int4                          ,
    encoding_losses        boolean                       ,
    message_id             text                          ,
    committer              text                          ,
    commit_description     text                          ,
    commit_date            text                          ,
    commit_time            text                          ,
    port_id                int4                          ,
    category               text                          ,
    category_id            int4                          ,
    port                   text                          ,
    version                text                          ,
    revision               text                          ,
    status                 char(1)                       ,
    needs_refresh          smallint                      ,
    forbidden              text                          ,
    broken                 text                          ,
    date_added             double precision              ,
    element_id             int4                          ,
    short_description      text                          ,
    watch                  text                          
);

create table commits_latest
(
commit_log_id		int4,
commit_date_raw		timestamp,
message_subject		text,
message_id			text,
committer			text,
commit_description	text,
commit_date			text,
commit_time			text,
element_id			int4,
element_name		text,
status				char(1),
encoding_losses		boolean,
element_pathname	text
);



create table watch_list_staging_log
(
    id                     int4                  not null,
    date_added             timestamp             not null,
    user_id                int4                  not null,
    action                 char(1)               not null
        check (
            action in ('U','W','C','D')),
    count_total            int4                  not null
        default '0',
    count_matches          int4                  not null
        default '0',
    count_missing          int4                  not null
        default '0',
    count_duplicates       int4                  not null
        default '0',
    count_categories       int4                  not null
        default '0',
    primary key (id)
);

  drop sequence watch_list_staging_log_id_seq;
create sequence watch_list_staging_log_id_seq;

alter table watch_list_staging_log alter column id set default nextval('watch_list_staging_log_id_seq'::text);
alter table watch_list_staging_log alter column date_added set default current_timestamp;

create table ports_check
(
    id                     int4                  not null,
    category_name          text                  not null,
    port_name              text                  not null,
    category_id            int4                          ,
    port_id                int4                          ,
    add_to_ports_table     boolean               not null
        default 'Y',
    primary key (id)
);

  drop sequence ports_check_id_seq;
create sequence ports_check_id_seq;
alter table ports_check alter column id set default nextval('ports_check_id_seq'::text);

create index ports_check_category_id on ports_check (category_id);

create table daily_refreshes
(
    refresh_date           date                  not null,
    primary key (refresh_date)
);

  drop sequence graphs_id_seq;
create sequence graphss_id_seq;
alter table graphs alter column id set default nextval('graphs_id_seq'::text);

create table graphs
(
    id                     int4                  not null,
    title                  text                  not null,
    query                  text                  not null,
    label                  text                          ,
    is_clickable           boolean                       
        default 'f',
    primary key (id)
);

  drop sequence graphs_id_seq;
create sequence graphs_id_seq;
alter table graphs alter column id set default nextval('graphs_id_seq'::text);

create table element
(
    id                     int4                  not null,
    name                   text                  not null,
    parent_id              int4                          ,
    directory_file_flag    char(1)               not null
        check (
            directory_file_flag in ('F','D')),
    status                 char(1)               not null
        check (
            status in ('A','D')),
    primary key (id)
);

  drop sequence element_id_seq;
create sequence element_id_seq;

alter table element alter column id set default nextval('element_id_seq'::text);

create index element_name on element (name);

create table watch_notice
(
    id                     int4                  not null,
    frequency              char(1)               not null
        check (
            frequency in ('Z','D','W','F','M')),
    description            text                  not null,
    last_sent              timestamp                     ,
    primary key (id)
);

  drop sequence watch_notice_id_seq;
create sequence watch_notice_id_seq;

alter table watch_notice alter column id set default nextval('watch_notice_id_seq'::text);

INSERT INTO "watch_notice" (id, frequency, description) VALUES (1,'Z','Don''t notify me');
INSERT INTO "watch_notice" (id, frequency, description) VALUES (3,'W','Week (on Tuesdays)');
INSERT INTO "watch_notice" (id, frequency, description) VALUES (4,'F','Fortnightly  (9th and 23rd)');
INSERT INTO "watch_notice" (id, frequency, description) VALUES (5,'M','Month (23rd)');
INSERT INTO "watch_notice" (id, frequency, description) VALUES (2,'D','Day');

create index watch_notice_frequency on watch_notice (frequency);

create table system
(
    id                     int4                  not null,
    name                   text                  not null,
    time_adjust            interval              not null
        default '0 seconds',
    primary key (id)
);

  drop sequence system_id_seq;
create sequence system_id_seq;

alter table system alter column id set default nextval('system_id_seq'::text);

INSERT INTO "system" VALUES (1,'FreeBSD','-03:00');

create table security_notice
(
    id                     int4                  not null,
    date_added             timestamp             not null
        default current_timestamp,
    status                 char(1)               not null,
    synopsis               text                  not null,
    primary key (id)
);

create table daily_stats
(
    id                     int4                  not null,
    title                  text                          ,
    query                  text                          ,
    primary key (id)
);

  drop sequence daily_stats_seq;
create sequence daily_stats_seq;
alter table daily_stats alter column id set default nextval('daily_stats_seq'::text);

create table reports
(
    id                     int4                  not null,
    name                   text                  not null,
    description            text                  not null,
    primary key (id)
);

insert into reports(id, name, description) values (1, 'Watch List Notification', 'Details of any changes to any items on your watch list');

insert into reports(id, name, description) values (2, 'New Ports', 'Lists the new ports which have been added to the ports tree');

  drop sequence reports_id_seq;
create sequence reports_id_seq;
alter table reports alter column id set default nextval('reports_id_seq'::text);
select setval('reports_id_seq'::text, 2);

create table report_frequency
(
    id                     int4                  not null,
    frequency              char(1)               not null,
    description            text                  not null,
    primary key (id)
);

INSERT INTO report_frequency (id, frequency, description) VALUES (1,'Z','Don''t notify me');
INSERT INTO report_frequency (id, frequency, description) VALUES (2,'D','Day');
INSERT INTO report_frequency (id, frequency, description) VALUES (3,'W','Week (on Tuesdays)');
INSERT INTO report_frequency (id, frequency, description) VALUES (4,'F','Fortnightly  (9th and 23rd)');
INSERT INTO report_frequency (id, frequency, description) VALUES (5,'M','Month (23rd)');

  drop sequence report_frequency_id_seq;
create sequence report_frequency_id_seq;
alter table report_frequency alter column id set default nextval('report_frequency_id_seq'::text);
select setval('report_frequency_id_seq'::text, 5);

create table element_revision
(
    element_id             int4                  not null,
    revision_name          text                          ,
    primary key (element_id, revision_name)
);

create table categories
(
    id                     int4                  not null,
    is_primary             boolean               not null,
    element_id             int4                  not null,
    name                   text                  not null,
    description            text                          ,
    primary key (id)
);

  drop sequence categories_id_seq;
create sequence categories_id_seq;
alter table categories alter column id set default nextval('categories_id_seq'::text);

create table ports
(
    id                     int4                  not null,
    element_id             int4                  not null,
    category_id            int4                  not null,
    short_description      text                          ,
    long_description       text                          ,
    version                text                          ,
    revision               text                          ,
    maintainer             text                          ,
    homepage               text                          ,
    master_sites           text                          ,
    extract_suffix         text                          ,
    package_exists         boolean                       ,
    depends_build          text                          ,
    depends_run            text                          ,
    last_commit_id         int4                          ,
    found_in_index         boolean                       ,
    forbidden              text                          ,
    broken                 text                          ,
    date_added             timestamp                     
        default current_timestamp,
    categories             text                          ,
    primary key (id)
);

  drop sequence ports_id_seq;
create sequence ports_id_seq;
alter table ports alter column id set default nextval('ports_id_seq'::text);

create table users
(
    id                     int4                  not null,
    name                   text                  not null,
    password               text                  not null,
    cookie                 text                  not null,
    firstlogin             timestamp                     
        default current_timestamp,
    lastlogin              timestamp                     
        default current_timestamp,
    email                  text                          ,
    watch_notice_id        int4                  not null,
    emailsitenotices_yn    boolean                       ,
    emailbouncecount       smallint                      
        default 0,
    type                   char(1)               not null
        default 'U'
        check (
            type in ('U','S')),
    status                 char(1)               not null
        default 'U'
        check (
            status in ('U','A','D')),
    ip_address             text                  not null,
    number_of_commits      smallint                      
        default 100,
    number_of_days         smallint                      
        default 9,
    primary key (id)
);

  drop sequence users_id_seq;
create sequence users_id_seq;

alter table users alter column id set default nextval('users_id_seq'::text);

create index users_cookie on users (cookie);

create index users_email on users (email);

create unique index users_name on users (name);

create table watch_list
(
    id                     int4                  not null,
    user_id                int4                  not null,
    name                   text                  not null,
    awaiting_staging       boolean               not null
        default 'N'
        check (
            awaiting_staging in ('Y','N')),
    primary key (id)
);

  drop sequence watch_list_id_seq;
create sequence watch_list_id_seq;

alter table watch_list alter column id set default nextval('watch_list_id_seq'::text);

create table system_branch
(
    id                     int4                  not null,
    system_id              int4                  not null,
    branch_name            text                          ,
    primary key (id)
);

  drop sequence system_branch_id_seq;
create sequence system_branch_id_seq;

alter table system_branch alter column id set default nextval('system_branch_id_seq'::text);


  drop sequence commit_log_id_seq;

create table commit_log
(
    id                     int4                  not null,
    message_id             text                  not null,
    message_date           timestamp             not null,
    message_subject        text                          ,
    date_added             timestamp             not null,
    commit_date            timestamp             not null,
    committer              text                  not null,
    description            text                  not null,
    system_id              int4                  not null,
    encoding_losses        boolean               not null
        default 'default 'f'::bool',
    primary key (id)
);

create sequence commit_log_id_seq;
alter table commit_log alter column id set default nextval('commit_log_id_seq'::text);

create index commit_log_commit_date on commit_log (commit_date);

create unique index commit_log_message_id on commit_log (message_id);


  drop sequence commit_log_elements_id_seq;

create table commit_log_elements
(
    id                     int4                  not null,
    commit_log_id          int4                  not null,
    element_id             int4                  not null,
    revision_name          text                          ,
    change_type            char(1)               not null
        check (
            change_type in ('A','M','R')),
    primary key (id)
);

create sequence commit_log_elements_id_seq;
alter table commit_log_elements alter column id set default nextval('commit_log_elements_id_seq'::text);

create table watch_list_element
(
    watch_list_id          int4                  not null,
    element_id             int4                  not null,
    primary key (watch_list_id, element_id)
);

create table watch_notice_log
(
    id                     int4                  not null,
    notice_date            timestamp             not null
        default current_timestamp,
    frequency_id           int4                  not null,
    msg_count              int4                  not null,
    commit_count           int4                  not null,
    primary key (id)
);

  drop sequence watch_notice_log_id_seq;
create sequence watch_notice_log_id_seq;
alter table watch_notice_log alter column id set default nextval('watch_notice_log_id_seq'::text);

create table system_branch_element_revision
(
    system_branch_id       int4                  not null,
    element_id             int4                  not null,
    revision_name          text                  not null,
    primary key (system_branch_id, element_id, revision_name)
);

create table commit_log_port_elements
(
    commit_log_id          int4                  not null,
    port_id                int4                  not null,
    commit_log_element_id  int4                  not null,
    primary key (commit_log_id, port_id, commit_log_element_id)
);

create table user_confirmations
(
    user_id                int4                  not null,
    token                  text                  not null,
    primary key (user_id, token)
);

create table commit_log_ports
(
    commit_log_id          int4                  not null,
    port_id                int4                  not null,
    needs_refresh          smallint              not null,
    port_version           text                          ,
    port_revision          text                          ,
    primary key (commit_log_id, port_id)
);

create index needs_refresh on commit_log_ports (needs_refresh);

create table security_notice_elements
(
    security_advisory_id   int4                  not null,
    element_id             int4                  not null,
    primary key (security_advisory_id, element_id)
);

create table security_notice_log
(
    id                     int4                  not null,
    security_notice_id     int4                  not null,
    user_id                int4                  not null,
    date_added             timestamp             not null
        default current_timestamp,
    change                 text                  not null,
    primary key (id)
);

create table watch_list_staging
(
    id                     int4                  not null,
    watch_list_id          int4                  not null,
    category               text                  not null,
    port                   text                  not null,
    item_count             int4                  not null,
    from_pkg_info          boolean               not null
        check (
            from_pkg_info in ('Y','N')),
    from_watch_list        boolean               not null
        check (
            from_watch_list in ('Y','N')),
    element_id             int4                          ,
    primary key (id)
);

  drop sequence watch_list_staging_id_seq;
create sequence watch_list_staging_id_seq;

alter table watch_list_staging  alter column id set default nextval('watch_list_staging_id_seq'::text);

create table daily_stats_data
(
    id                     int4                  not null,
    daily_stats_id         int4                  not null,
    date                   date                  not null,
    value                  integer               not null,
    primary key (id)
);

  drop sequence daily_stats_data_seq;
create sequence daily_stats_data_seq;
alter table daily_stats_data alter column id set default nextval('daily_stats_data_seq'::text);

create unique index daily_stats_data_unique on daily_stats_data (daily_stats_id, date);

create table report_log
(
    id                     int4                  not null,
    report_id              int4                  not null,
    frequency_id           int4                          ,
    report_date            timestamp             not null
        default current_timestamp,
    email_count            int4                  not null,
    commit_count           int4                  not null,
    port_count             int4                  not null,
    primary key (id)
);

  drop sequence report_log_id_seq;
create sequence report_log_id_seq;
alter table report_log alter column id set default nextval('report_log_id_seq'::text);

create table report_subscriptions
(
    report_id              int4                  not null,
    user_id                int4                  not null,
    report_frequency_id    int4                  not null,
    primary key (report_id, user_id)
);

create view commits_recent as
select distinct commit_log.id, commit_log.message_id, commit_log.message_date,
commit_log.message_subject, commit_log.date_added, commit_log.commit_date,
commit_log.committer, commit_log.description, commit_log.system_id, commit_log.encoding_losses
from commit_log
where exists
(select * from commit_log_elements where commit_log_elements.commit_log_id = commit_log.id)
order by commit_log.commit_date desc, commit_log.id limit 100;;


create view commits_recent_ports as
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


create view report_log_latest as
select report_log.frequency_id, report_frequency.frequency, 
max(report_log.report_date) AS last_sent
from report_log, report_frequency
where ( report_log.frequency_id = report_frequency.id )
group by report_log.frequency_id, report_frequency.frequency;;

alter table element
    add foreign key (parent_id)
       references element (id) on update restrict on delete cascade;

alter table element_revision
    add foreign key (element_id)
       references element (id) on update cascade on delete cascade;

alter table categories
    add foreign key (element_id)
       references element (id) on update cascade on delete cascade;

alter table ports
    add foreign key (element_id)
       references element (id) on update cascade on delete cascade;

alter table ports
    add foreign key (category_id)
       references categories (id) on update cascade on delete cascade;

alter table users
    add foreign key (watch_notice_id)
       references watch_notice (id) on update cascade on delete cascade;

alter table watch_list
    add foreign key (user_id)
       references users (id) on update cascade on delete cascade;

alter table system_branch
    add foreign key (system_id)
       references system (id) on update cascade on delete cascade;

alter table commit_log
    add foreign key (system_id)
       references system (id) on update cascade on delete cascade;

alter table commit_log_elements
    add foreign key (commit_log_id)
       references commit_log (id) on update cascade on delete cascade;

alter table commit_log_elements
    add foreign key (element_id, revision_name)
       references element_revision (element_id, revision_name) on update cascade on delete cascade;

alter table watch_list_element
    add foreign key (element_id)
       references element (id) on update cascade on delete cascade;

alter table watch_list_element
    add foreign key (watch_list_id)
       references watch_list (id) on update cascade on delete cascade;

alter table watch_notice_log
    add foreign key (frequency_id)
       references watch_notice (id) on update cascade on delete cascade;

alter table system_branch_element_revision
    add foreign key (system_branch_id)
       references system_branch (id) on update cascade on delete cascade;

alter table system_branch_element_revision
    add foreign key (element_id, revision_name)
       references element_revision (element_id, revision_name) on update cascade on delete cascade;

alter table commit_log_port_elements
    add foreign key (commit_log_id)
       references commit_log (id) on update cascade on delete cascade;

alter table commit_log_port_elements
    add foreign key (port_id)
       references ports (id) on update cascade on delete cascade;

alter table commit_log_port_elements
    add foreign key (commit_log_element_id)
       references commit_log_elements (id) on update cascade on delete cascade;

alter table user_confirmations
    add foreign key (user_id)
       references users (id) on update cascade on delete cascade;

alter table commit_log_ports
    add foreign key (commit_log_id)
       references commit_log (id) on update cascade on delete cascade;

alter table commit_log_ports
    add foreign key (port_id)
       references ports (id) on update cascade on delete cascade;

alter table security_notice_elements
    add foreign key (security_advisory_id)
       references security_notice (id) on update cascade on delete cascade;

alter table security_notice_elements
    add foreign key (element_id)
       references element (id) on update cascade on delete cascade;

alter table security_notice_log
    add foreign key (user_id)
       references users (id) on update cascade on delete cascade;

alter table security_notice_log
    add foreign key (security_notice_id)
       references security_notice (id) on update cascade on delete cascade;

alter table watch_list_staging
    add foreign key (watch_list_id)
       references watch_list (id) on update cascade on delete cascade;

alter table watch_list_staging
    add foreign key (element_id)
       references element (id) on update cascade on delete set null;

alter table daily_stats_data
    add foreign key (daily_stats_id)
       references daily_stats (id) on delete cascade;

alter table report_log
    add foreign key (report_id)
       references reports (id) on update cascade on delete cascade;

alter table report_log
    add foreign key (frequency_id)
       references report_frequency (id) on update cascade on delete cascade;

alter table report_subscriptions
    add foreign key (report_id)
       references reports (id) on update cascade on delete cascade;

alter table report_subscriptions
    add foreign key (user_id)
       references users (id) on update cascade on delete cascade;

alter table report_subscriptions
    add foreign key (report_frequency_id)
       references report_frequency (id) on update cascade on delete cascade;

