create database db1;
create database db2;

use db1;

-- standard boring table
select 't1';
create table t1 
  (c1 bigint not null, 
   c2 bigint not null)
engine=innodb;

insert into t1 (c1,c2) values (1,1),(2,2),(3,3);
insert into t1 (c1,c2) values (11,11),(12,12),(13,13);


-- table plus secondaries
select 't2';
create table t2 
  (c1 bigint not null, 
   c2 bigint not null,
   key key_c2 (c2),
   key key_c1_c2 (c1, c2)
)
engine=innodb;

insert into t2 (c1,c2) values (1,1),(2,2),(3,3);
insert into t2 (c1,c2) values (11,11),(12,12),(13,13);


-- table plus clustering secondaries
select 't3';
create table t3 
  (c1 bigint not null, 
   c2 bigint not null,
   key key_c2 (c2),
   clustering key key_c1_c2 (c1, c2)
)
engine=innodb;

insert into t3 (c1,c2) values (1,1),(2,2),(3,3);
insert into t3 (c1,c2) values (11,11),(12,12),(13,13);


-- Alter table add/drop/expand column, hot
select 't4';
set local tokudb_disable_slow_alter=1;
set local tokudb_disable_hot_alter=0;

create table t4 
  (c1 bigint not null, 
   c2 bigint not null,
   c3 int not null,
   key key_c2 (c2)
)
engine=innodb;

insert into t4 (c1,c2,c3) values (1,1,1),(2,2,2),(3,3,3);
insert into t4 (c1,c2,c3) values (11,11,11),(12,12,12),(13,13,13);

alter table t4 drop column c1;
alter table t4 add column c4 int default 1001 not null;
alter table t4 modify column c3 bigint not null;


-- Alter table add/drop/expand column, cold
select 't5';
set local tokudb_disable_slow_alter=0;
set local tokudb_disable_hot_alter=1;

create table t5 
  (c1 bigint not null, 
   c2 bigint not null,
   c3 int not null,
   key key_c2 (c2)
)
engine=innodb;

insert into t5 (c1,c2,c3) values (1,1,1),(2,2,2),(3,3,3);
insert into t5 (c1,c2,c3) values (11,11,11),(12,12,12),(13,13,13);

alter table t5 drop column c1, add column c4 int default 1001 not null, modify column c3 bigint not null;


set local tokudb_disable_slow_alter=0;
set local tokudb_disable_hot_alter=0;


-- Hot index
select 't6';
set local tokudb_create_index_online=1;

create table t6 
  (c1 bigint not null, 
   c2 bigint not null
)
engine=innodb;

insert into t6 (c1,c2) values (1,1),(2,2),(3,3);
insert into t6 (c1,c2) values (11,11),(12,12),(13,13);

create index key_c2 on t6 (c2);


-- Blocking index
select 't7';
set local tokudb_create_index_online=0;

create table t7 
  (c1 bigint not null, 
   c2 bigint not null
)
engine=innodb;

insert into t7 (c1,c2) values (1,1),(2,2),(3,3);
insert into t7 (c1,c2) values (11,11),(12,12),(13,13);

create index key_c2 on t7 (c2);


-- Rewrite myself
select 't8';
create table t8 
  (c1 bigint not null, 
   c2 bigint not null,
   key key_c2 (c2)
)
engine=innodb;

insert into t8 (c1,c2) values (1,1),(2,2),(3,3);
insert into t8 (c1,c2) values (11,11),(12,12),(13,13);

alter table t8 engine=innodb;


-- Optimize
select 't9';
create table t9 
  (c1 bigint not null, 
   c2 bigint not null,
   key key_c2 (c2)
)
engine=innodb;

insert into t9 (c1,c2) values (1,1),(2,2),(3,3);
insert into t9 (c1,c2) values (11,11),(12,12),(13,13);

optimize table t9;


-- Change compression to lzma
select 't10';
create table t10 
  (c1 bigint not null, 
   c2 bigint not null,
   key key_c2 (c2)
)
engine=innodb;

insert into t10 (c1,c2) values (1,1),(2,2),(3,3);
insert into t10 (c1,c2) values (11,11),(12,12),(13,13);

alter table t10 row_format=tokudb_lzma;
optimize table t10;


-- Change compression to zlib
select 't11';
create table t11 
  (c1 bigint not null, 
   c2 bigint not null,
   key key_c2 (c2)
)
engine=innodb;

insert into t11 (c1,c2) values (1,1),(2,2),(3,3);
insert into t11 (c1,c2) values (11,11),(12,12),(13,13);

alter table t11;
optimize table t11;


-- Change compression to uncompressed
select 't12';
create table t12 
  (c1 bigint not null, 
   c2 bigint not null,
   key key_c2 (c2)
)
engine=innodb row_format=tokudb_quicklz;

insert into t12 (c1,c2) values (1,1),(2,2),(3,3);
insert into t12 (c1,c2) values (11,11),(12,12),(13,13);

alter table t12;
optimize table t12;


-- Rename table, same db
select 't13';
create table t13 
  (c1 bigint not null, 
   c2 bigint not null,
   key key_c2 (c2)
)
engine=innodb;

insert into t13 (c1,c2) values (1,1),(2,2),(3,3);
insert into t13 (c1,c2) values (11,11),(12,12),(13,13);

alter table t13 rename t14;


-- Rename table, new db and same name
select 't15';
create table t15 
  (c1 bigint not null, 
   c2 bigint not null,
   key key_c2 (c2)
)
engine=innodb;

insert into t15 (c1,c2) values (1,1),(2,2),(3,3);
insert into t15 (c1,c2) values (11,11),(12,12),(13,13);

alter table t15 rename db2.t15;


-- Rename table, new db and new name
select 't16';
create table t16 
  (c1 bigint not null, 
   c2 bigint not null,
   key key_c2 (c2)
)
engine=innodb;

insert into t16 (c1,c2) values (1,1),(2,2),(3,3);
insert into t16 (c1,c2) values (11,11),(12,12),(13,13);

alter table t16 rename db2.t17;


-- Big table, used for next bulk-load step
select 't18';
create table t18 
  (pk bigint not null auto_increment primary key,
   c1 bigint not null, 
   c2 bigint not null
)
engine=innodb;

insert into t18 (c1,c2) values (0,0),(1,1),(2,2),(3,3),(4,4),(5,5),(6,6),(7,7),(8,8),(9,9);
insert into t18 (c1,c2) select c1, c2 from t18;
insert into t18 (c1,c2) select c1, c2 from t18;
insert into t18 (c1,c2) select c1, c2 from t18;
insert into t18 (c1,c2) select c1, c2 from t18;
insert into t18 (c1,c2) select c1, c2 from t18;
insert into t18 (c1,c2) select c1, c2 from t18;
insert into t18 (c1,c2) select c1, c2 from t18;
insert into t18 (c1,c2) select c1, c2 from t18;
insert into t18 (c1,c2) select c1, c2 from t18;
insert into t18 (c1,c2) select c1, c2 from t18;
insert into t18 (c1,c2) select c1, c2 from t18;
insert into t18 (c1,c2) select c1, c2 from t18;
insert into t18 (c1,c2) select c1, c2 from t18;
insert into t18 (c1,c2) select c1, c2 from t18;
insert into t18 (c1,c2) select c1, c2 from t18;


-- Drop table
select 't19';
create table t19 
  (c1 bigint not null, 
   c2 bigint not null
)
engine=innodb;

insert into t19 (c1,c2) select c1, c2 from t18;
create index idx_c2 on t19 (c2,c1);
drop table t19;


-- Partitioning
select 't20';
create table t20 
  (pk bigint not null auto_increment primary key,
   c1 bigint not null, 
   c2 bigint not null
)
engine=innodb
partition by hash (pk)
partitions 4;

insert into t20 (pk,c1,c2) select pk, c1, c2 from t18;
create index idx_c2 on t20 (c2,c1);


-- create user
select 'create user';
create user user1 identified by 'user1';


