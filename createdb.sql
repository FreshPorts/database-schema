
  drop sequence categories_id_seq;
create sequence categories_id_seq;

  drop sequence commit_log_id_seq;
create sequence commit_log_id_seq;

  drop sequence commit_log_elements_id_seq;
create sequence commit_log_elements_id_seq;

  drop sequence element_id_seq;
create sequence element_id_seq;

  drop sequence element_revision_id_seq;
create sequence element_revision_id_seq;

  drop sequence ports_id_seq;
create sequence ports_id_seq;

  drop sequence system_id_seq;
create sequence system_id_seq;

  drop sequence system_version_id_seq;
create sequence system_version_id_seq;

  drop sequence system_version_element_id_seq;
create sequence system_version_element_id_seq;

  drop sequence users_id_seq;
create sequence users_id_seq;

  drop sequence watch_list_id_seq;
create sequence watch_list_id_seq;

  drop sequence watch_notice_id_seq;
create sequence watch_notice_id_seq;

  drop sequence watch_notice_log_id_seq;
create sequence watch_notice_log_id_seq;

create table commit_log
(
    id                   int4                  not null,
    message_id           text                  not null,
    message_date         timestamp             not null,
    message_subject      text                          ,
    date_added           timestamp             not null,
    commit_date          timestamp             not null,
    committer            varchar(40)           not null,
    description          text                  not null,
    primary key (id)
);

create index commit_log_commit_date on commit_log (commit_date asc);

create table watch_notice
(
    id                   int4                  not null,
    frequency            char(1)               not null
        check (
            frequency in ('Z','D','W','F','M')),
    description          varchar(30)           not null,
    last_sent            timestamp                     ,
    primary key (id)
);

create index watch_notice_frequency on watch_notice (frequency asc);

create table system
(
    id                   int4                  not null,
    name                 text                          ,
    primary key (id)
);

create table element
(
    id                   int4                  not null,
    name                 text                  not null,
    parent_id            int4                          ,
    directory_file_flag  char(1)               not null,
    status               char(1)               not null
        check (
            status in ('A','D')),
    primary key (id)
);

create index element_name on element (name asc);

create table users
(
    id                   int4                  not null,
    name                 varchar(20)           not null,
    password             varchar(80)           not null,
    cookie               varchar(80)           not null,
    firstlogin           timestamp                     ,
    lastlogin            timestamp                     ,
    email                varchar(40)                   ,
    watch_notice_id      int4                  not null,
    emailsitenotices_yn  boolean                       ,
    emailbouncecount     smallint                      ,
    type                 char(1)               not null
        check (
            type in ('U','S')),
    primary key (id)
);

create index users_cookie on users (cookie asc);

create index users_email on users (email asc);

create unique index users_name on users (name asc);

create table watch_list
(
    id                   int4                  not null,
    user_id              int4                  not null,
    name                 varchar(60)           not null,
    primary key (id)
);

create table system_version
(
    id                   int4                  not null,
    system_id            int4                  not null,
    version_name         text                          ,
    primary key (id)
);

create table categories
(
    id                   int4                  not null,
    is_primary           boolean               not null,
    element_id           int4                  not null,
    name                 varchar(30)           not null,
    description          varchar(80)                   ,
    primary key (id)
);

create table element_revision
(
    element_id           int4                  not null,
    revision_name        text                  not null,
    primary key (element_id, revision_name)
);

create table commit_log_elements
(
    id                   int4                  not null,
    commit_log_id        int4                  not null,
    element_id           int4                  not null,
    revision_name        text                          ,
    change_type          char(1)               not null
        check (
            change_type in ('A','M','R')),
    primary key (id)
);

create table watch_list_element
(
    watch_list_id        int4                  not null,
    element_id           int4                  not null,
    primary key (watch_list_id, element_id)
);

create table watch_notice_log
(
    id                   int4                  not null,
    watch_notice_id      int4                  not null,
    notice_date          timestamp             not null,
    watch_notice_count   smallint              not null,
    primary key (id)
);

create table ports
(
    id                   int4                  not null,
    element_id           int4                  not null,
    category_id          int4                  not null,
    short_description    text                          ,
    long_description     text                          ,
    version              text                          ,
    maintainer           varchar(40)                   ,
    homepage             text                          ,
    master_sites         text                          ,
    extract_suffix       varchar(10)                   ,
    package_exists       boolean                       ,
    depends_build        text                          ,
    depends_run          text                          ,
    last_commit_id       int4                          ,
    needs_refresh        smallint                      ,
    found_in_index       boolean                       ,
    forbidden            boolean                       ,
    broken               boolean                       ,
    primary key (id)
);

create index ports_needs_refresh on ports (needs_refresh asc);

create table system_version_element
(
    system_version_id    int4                  not null,
    element_id           int4                  not null,
    revision_name        text                  not null,
    primary key (system_version_id, element_id, revision_name)
);

alter table element
    add foreign key fk_parent_id_element (parent_id)
       references element (id) on delete cascade;

alter table users
    add foreign key fk_users_watch_notice (watch_notice_id)
       references watch_notice (id) on delete cascade;

alter table watch_list
    add foreign key FK_WATCH_LI_FK_WATCH__USERS (user_id)
       references users (id) on delete cascade;

alter table system_version
    add foreign key fk_system_version_system (system_id)
       references system (id) on delete cascade;

alter table categories
    add foreign key FK_CATEGORI_FK_CATEGO_ELEMENT (element_id)
       references element (id) on delete cascade;

alter table categories
    add foreign key fk_categories_element (element_id)
       references element (id) on delete cascade;

alter table element_revision
    add foreign key FK_ELEMENT__FK_ELEMEN_ELEMENT (element_id)
       references element (id) on delete cascade;

alter table commit_log_elements
    add foreign key commit_log (commit_log_id)
       references commit_log (id) on delete cascade;

alter table commit_log_elements
    add foreign key FK_COMMIT_L_REF_1100_ELEMENT_ (element_id, revision_name)
       references element_revision (element_id, revision_name) on delete restrict;

alter table watch_list_element
    add foreign key watch_list_element_element (element_id)
       references element (id) on delete cascade;

alter table watch_list_element
    add foreign key watch_list_element_watch_list (watch_list_id)
       references watch_list (id) on delete cascade;

alter table watch_notice_log
    add foreign key watch_list_fk (watch_notice_id)
       references watch_notice (id) on delete cascade;

alter table watch_notice_log
    add foreign key FK_WATCH_NO_FK_WATCH__WATCH_NO (watch_notice_id)
       references watch_notice (id) on delete cascade;

alter table ports
    add foreign key ports_element_fk (element_id)
       references element (id) on delete cascade;

alter table ports
    add foreign key FK_PORTS_FK_PORTS__CATEGORI (category_id)
       references categories (id) on delete cascade;

alter table ports
    add foreign key fk_ports_element (element_id)
       references element (id) on delete cascade;

alter table ports
    add foreign key fk_ports_categories (category_id)
       references categories (id) on delete cascade;

alter table system_version_element
    add foreign key FK_SYSTEM_V_FK_SYSTEM_SYSTEM_V (system_version_id)
       references system_version (id) on delete cascade;

alter table system_version_element
    add foreign key FK_SYSTEM_V_FK_SYSTEM_ELEMENT_ (element_id, revision_name)
       references element_revision (element_id, revision_name) on delete cascade;

alter table categories             alter column id set default nextval('categories_id_seq'::text);
alter table commit_log             alter column id set default nextval('commit_log_id_seq'::text);
alter table commit_log_elements    alter column id set default nextval('commit_log_elements_id_seq'::text);
alter table element                alter column id set default nextval('element_id_seq'::text);
alter table element_revision       alter column id set default nextval('element_revision_id_seq'::text);
alter table ports                  alter column id set default nextval('ports_id_seq'::text);
alter table system                 alter column id set default nextval('system_id_seq'::text);
alter table system_version         alter column id set default nextval('system_version_id_seq'::text);
alter table system_version_element alter column id set default nextval('system_version_element_id_seq'::text);
alter table users                  alter column id set default nextval('users_id_seq'::text);
alter table watch_list             alter column id set default nextval('watch_list_id_seq'::text);
alter table watch_list_element     alter column id set default nextval('watch_notice_id_seq'::text);
alter table watch_notice_log       alter column id set default nextval('watch_notice_log_id_seq'::text);

