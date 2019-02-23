elapsedtime on;
create schema ##SCHEMA##;
set schema ##SCHEMA##;

CREATE TABLE LINEITEM (
 L_ORDERKEY BIGINT NOT NULL,
 L_PARTKEY INTEGER NOT NULL,
 L_SUPPKEY INTEGER NOT NULL, 
 L_LINENUMBER INTEGER NOT NULL, 
 L_QUANTITY DECIMAL(15,2),
 L_EXTENDEDPRICE DECIMAL(15,2),
 L_DISCOUNT DECIMAL(15,2),
 L_TAX DECIMAL(15,2),
 L_RETURNFLAG VARCHAR(1), 
 L_LINESTATUS VARCHAR(1),
 L_SHIPDATE DATE,
 L_COMMITDATE DATE,
 L_RECEIPTDATE DATE,
 L_SHIPINSTRUCT VARCHAR(25),
 L_SHIPMODE VARCHAR(10),
 L_COMMENT VARCHAR(44),
 PRIMARY KEY(L_ORDERKEY,L_LINENUMBER)
 );

CREATE TABLE ORDERS (
 O_ORDERKEY BIGINT NOT NULL PRIMARY KEY,
 O_CUSTKEY INTEGER,
 O_ORDERSTATUS VARCHAR(1),
 O_TOTALPRICE DECIMAL(15,2),
 O_ORDERDATE DATE,
 O_ORDERPRIORITY VARCHAR(15),
 O_CLERK VARCHAR(15),
 O_SHIPPRIORITY INTEGER ,
 O_COMMENT VARCHAR(79)
 );

CREATE TABLE CUSTOMER (
 C_CUSTKEY INTEGER NOT NULL PRIMARY KEY,
 C_NAME VARCHAR(25),
 C_ADDRESS VARCHAR(40),
 C_NATIONKEY INTEGER NOT NULL,
 C_PHONE VARCHAR(15),
 C_ACCTBAL DECIMAL(15,2),
 C_MKTSEGMENT VARCHAR(10),
 C_COMMENT VARCHAR(117)
 );

CREATE TABLE PARTSUPP (
 PS_PARTKEY INTEGER NOT NULL ,
 PS_SUPPKEY INTEGER NOT NULL , 
 PS_AVAILQTY INTEGER,
 PS_SUPPLYCOST DECIMAL(15,2),
 PS_COMMENT VARCHAR(199),
 PRIMARY KEY(PS_PARTKEY,PS_SUPPKEY) 
 );

CREATE TABLE SUPPLIER (
 S_SUPPKEY INTEGER NOT NULL PRIMARY KEY,
 S_NAME VARCHAR(25) ,
 S_ADDRESS VARCHAR(40) ,
 S_NATIONKEY INTEGER ,
 S_PHONE VARCHAR(15) ,
 S_ACCTBAL DECIMAL(15,2),
 S_COMMENT VARCHAR(101)
 );

CREATE TABLE PART (
 P_PARTKEY INTEGER NOT NULL PRIMARY KEY,
 P_NAME VARCHAR(55) ,
 P_MFGR VARCHAR(25) ,
 P_BRAND VARCHAR(10) ,
 P_TYPE VARCHAR(25) ,
 P_SIZE INTEGER ,
 P_CONTAINER VARCHAR(10) ,
 P_RETAILPRICE DECIMAL(15,2),
 P_COMMENT VARCHAR(23)
 ); 

CREATE TABLE REGION (
 R_REGIONKEY INTEGER NOT NULL PRIMARY KEY,
 R_NAME VARCHAR(25),
 R_COMMENT VARCHAR(152)
 );

CREATE TABLE NATION (
 N_NATIONKEY INTEGER NOT NULL,
 N_NAME VARCHAR(25),
 N_REGIONKEY INTEGER NOT NULL,
 N_COMMENT VARCHAR(152),
 PRIMARY KEY (N_NATIONKEY)
 );
