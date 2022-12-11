-- DO THIS BEFORE YOU LOAD THE DATA

create group www;
create user www with password '[redacted]';

alter group www add user www;


create user commits with password '[redacted]';
create group commits;
alter group commits add user commits;

create group reading;
create user  reading with password '[redacted]';

alter group reading add user reading;

create role freshsource_ro;
create user freshsource_dev with password '[redacted]' IN ROLE freshsource_ro;
create group reporting;
CREATE GROUP listening;
ALTER USER   listening PASSWORD '[redacted]';
ALTER USER   listening LOGIN;

CREATE USER packager_dev WITH PASSWORD '[redacted]' IN ROLE packaging;
