create database db1;
create database db2;

use db1;

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


