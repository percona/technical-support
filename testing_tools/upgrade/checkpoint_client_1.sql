
create database db1;

use db1;

-- standard boring table
select 't1';
create table t1
  (c1 bigint not null,
   c2 bigint not null)
engine=tokudb;

-- start transaction
begin;
insert into t1 (c1,c2) values (1,1),(2,2),(3,3);
insert into t1 (c1,c2) values (11,11),(12,12),(13,13);
insert into t1 (c1,c2) values (14,14),(15,15),(16,16);
insert into t1 (c1,c2) values (17,17),(18,18),(19,19);
insert into t1 (c1,c2) values (20,20),(21,21),(22,22);
select sleep(10);

-- end transaction
commit;
