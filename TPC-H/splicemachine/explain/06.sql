SET SCHEMA TPCH;
maximumdisplaywidth 0;
elapsedtime on;
-- EXPLAIN 06
explain select
	sum(l_extendedprice * l_discount) as revenue
from
	lineitem
where
	l_shipdate >= date('1994-01-01')
	and l_shipdate < date({fn TIMESTAMPADD(SQL_TSI_YEAR, 1, cast('1994-01-01 00:00:00' as timestamp))})
	and l_discount between .06 - 0.01 and .06 + 0.01
	and l_quantity < 24
-- END OF QUERY
;
