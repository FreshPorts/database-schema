
  drop sequence categories_id_seq;
create sequence categories_id_seq;

  drop sequence commit_log_id_seq;
create sequence commit_log_id_seq;

  drop sequence commit_log_elements_id_seq;
create sequence commit_log_elements_id_seq;

  drop sequence element_id_seq;
create sequence element_id_seq;

  drop sequence ports_id_seq;
create sequence ports_id_seq;

  drop sequence system_id_seq;
create sequence system_id_seq;

  drop sequence system_branch_id_seq;
create sequence system_branch_id_seq;

  drop sequence users_id_seq;
create sequence users_id_seq;

  drop sequence watch_list_id_seq;
create sequence watch_list_id_seq;

  drop sequence watch_notice_id_seq;
create sequence watch_notice_id_seq;

  drop sequence watch_notice_log_id_seq;
create sequence watch_notice_log_id_seq;

create table element
(
    id                     int4                  not null,
    name                   text                  not null,
    parent_id              int4                          ,
    directory_file_flag    char(1)               not null,
    status                 char(1)               not null
        check (
            status in ('A','D')),
    primary key (id)
);

create index element_name on element (name);

create table watch_notice
(
    id                     int4                  not null,
    frequency              char(1)               not null
        check (
            frequency in ('Z','D','W','F','M')),
    description            varchar(30)           not null,
    last_sent              timestamp                     ,
    primary key (id)
);

create index watch_notice_frequency on watch_notice (frequency);

create table system
(
    id                     int4                  not null,
    name                   text                          ,
    primary key (id)
);

create table categories
(
    id                     int4                  not null,
    is_primary             boolean               not null,
    element_id             int4                  not null,
    name                   varchar(30)           not null,
    description            varchar(80)                   ,
    primary key (id)
);

create table element_revision
(
    element_id             int4                  not null,
    revision_name          text                          ,
    primary key (element_id, revision_name)
);

create table ports
(
    id                     int4                  not null,
    element_id             int4                  not null,
    category_id            int4                  not null,
    short_description      text                          ,
    long_description       text                          ,
    version                text                          ,
    revision               text                          ,
    maintainer             varchar(40)                   ,
    homepage               text                          ,
    master_sites           text                          ,
    extract_suffix         varchar(10)                   ,
    package_exists         boolean                       ,
    depends_build          text                          ,
    depends_run            text                          ,
    last_commit_id         int4                          ,
    needs_refresh          smallint                      ,
    found_in_index         boolean                       ,
    forbidden              text                          ,
    broken                 text                          ,
    primary key (id)
);

create index ports_needs_refresh on ports (needs_refresh);

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

create table users
(
    id                     int4                  not null,
    name                   varchar(20)           not null,
    password               varchar(80)           not null,
    cookie                 varchar(80)           not null,
    firstlogin             timestamp                     ,
    lastlogin              timestamp                     ,
    email                  varchar(40)                   ,
    watch_notice_id        int4                  not null,
    emailsitenotices_yn    boolean                       ,
    emailbouncecount       smallint                      ,
    type                   char(1)               not null
        check (
            type in ('U','S')),
    primary key (id)
);

create index users_cookie on users (cookie);

create index users_email on users (email);

create unique index users_name on users (name);

create table watch_list
(
    id                     int4                  not null,
    user_id                int4                  not null,
    name                   varchar(60)           not null,
    primary key (id)
);

create table system_branch
(
    id                     int4                  not null,
    system_id              int4                  not null,
    branch_name            text                          ,
    primary key (id)
);

create table commit_log
(
    id                     int4                  not null,
    message_id             text                  not null,
    message_date           timestamp             not null,
    message_subject        text                          ,
    date_added             timestamp             not null,
    commit_date            timestamp             not null,
    committer              varchar(40)           not null,
    update_description     text                  not null,
    system_id              int4                  not null,
    primary key (id)
);

create index commit_log_commit_date on commit_log (commit_date);

create table watch_list_element
(
    watch_list_id          int4                  not null,
    element_id             int4                  not null,
    primary key (watch_list_id, element_id)
);

create table watch_notice_log
(
    id                     int4                  not null,
    watch_notice_id        int4                  not null,
    notice_date            timestamp             not null,
    watch_notice_count     smallint              not null,
    primary key (id)
);

create table system_branch_element_revision
(
    system_branch_id       int4                  not null,
    element_id             int4                  not null,
    revision_name          text                  not null,
    primary key (system_branch_id, element_id, revision_name)
);

create table commit_log_port
(
    commit_log_id          int4                  not null,
    port_id                int4                  not null,
    commit_log_element_id  int4                  not null,
    primary key (commit_log_id, port_id, commit_log_element_id)
);

alter table element
    add foreign key (parent_id)
       references element (id) on delete cascade;

alter table categories
    add foreign key (element_id)
       references element (id) on delete cascade;

alter table categories
    add foreign key (element_id)
       references element (id) on delete cascade;

alter table element_revision
    add foreign key (element_id)
       references element (id) on delete cascade;

alter table ports
    add foreign key (element_id)
       references element (id) on delete cascade;

alter table ports
    add foreign key (category_id)
       references categories (id) on delete cascade;

alter table ports
    add foreign key (element_id)
       references element (id) on delete cascade;

alter table ports
    add foreign key (category_id)
       references categories (id) on delete cascade;

alter table commit_log_elements
    add foreign key (commit_log_id)
       references commit_log (id) on delete cascade;

alter table commit_log_elements
    add foreign key (element_id, revision_name)
       references element_revision (element_id, revision_name) on delete restrict;

alter table users
    add foreign key (watch_notice_id)
       references watch_notice (id) on delete cascade;

alter table watch_list
    add foreign key (user_id)
       references users (id) on delete cascade;

alter table system_branch
    add foreign key (system_id)
       references system (id) on delete cascade;

alter table commit_log
    add foreign key (system_id)
       references system (id) on delete cascade;

alter table watch_list_element
    add foreign key (element_id)
       references element (id) on delete cascade;

alter table watch_list_element
    add foreign key (watch_list_id)
       references watch_list (id) on delete cascade;

alter table watch_notice_log
    add foreign key (watch_notice_id)
       references watch_notice (id) on delete cascade;

alter table watch_notice_log
    add foreign key (watch_notice_id)
       references watch_notice (id) on delete cascade;

alter table system_branch_element_revision
    add foreign key (system_branch_id)
       references system_branch (id) on delete cascade;

alter table system_branch_element_revision
    add foreign key (element_id, revision_name)
       references element_revision (element_id, revision_name) on delete restrict;

alter table commit_log_port
    add foreign key (commit_log_id)
       references commit_log (id) on delete cascade;

alter table commit_log_port
    add foreign key (port_id)
       references ports (id) on delete cascade;

alter table commit_log_port
    add foreign key (commit_log_element_id)
       references commit_log_elements (id) on delete cascade;

alter table categories                     alter column id set default nextval('categories_id_seq'::text);
alter table commit_log                     alter column id set default nextval('commit_log_id_seq'::text);
alter table commit_log_elements            alter column id set default nextval('commit_log_elements_id_seq'::text);
alter table element                        alter column id set default nextval('element_id_seq'::text);
alter table ports                          alter column id set default nextval('ports_id_seq'::text);
alter table system                         alter column id set default nextval('system_id_seq'::text);
alter table system_branch                  alter column id set default nextval('system_branch_id_seq'::text);
alter table users                          alter column id set default nextval('users_id_seq'::text);
alter table watch_list                     alter column id set default nextval('watch_list_id_seq'::text);
alter table watch_notice_log               alter column id set default nextval('watch_notice_log_id_seq'::text);
