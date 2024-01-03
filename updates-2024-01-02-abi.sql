-- new roles and permissions for updating the abi table

create role abi_maintenance;
create role abi_maintainer in role abi_maintenance login password 'foo';
grant insert, delete, select, update on abi to abi_maintenance;
