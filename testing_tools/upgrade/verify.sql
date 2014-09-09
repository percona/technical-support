
use db1;

select @total1 := sum(c2) from t1;
select @total2 := sum(c2) from t2;
select @total3 := sum(c2) from t3;
select @total4 := sum(c2) from t4;
select @total5 := sum(c2) from t5;
select @total6 := sum(c2) from t6;
select @total7 := sum(c2) from t7;
select @total8 := sum(c2) from t8;
select @total9 := sum(c2) from t9;
select @total10 := sum(c2) from t10;

select @checksum := sum(@total1 + @total2 + @total3 + @total4 + @total5 + @total6 + @total7 + @total8 + @total9 + @total10);


