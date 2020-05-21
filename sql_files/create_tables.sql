SET GLOBAL local_infile = true;
SET GLOBAL local_infile = 1;

create database bank;

use bank;
/*
 ACCOUNT TABLE
 */
drop table if exists bank.account;
create table bank.account
(
    account_id         int,
    district_id      int,
    frequency          varchar(25),
    datedate     varchar(6)

);

truncate bank.account;

#load from file
load data local infile '/Users/kvsteau/GoogleDrive/WCD_DS/W6/MidTerm/bank_loan/account.asc'
into table bank.account
fields terminated by ';' ENCLOSED BY '"'
lines terminated by '\n'
ignore 1 lines
;
select * from bank.account;

alter table account
add column datenew DATE;

UPDATE account set datenew = CAST(datedate AS DATE);

ALTER TABLE account
DROP datedate;

ALTER TABLE account CHANGE datenew date DATE;

UPDATE account SET frequency = CASE
    WHEN frequency = 'POPLATEK MESICNE' then 'monthly'
    WHEN frequency = 'POPLATEK TYDNE' then 'monthly'
    ELSE 'aftertrx'
END


select  * from account;


/*
  CLIENT TABLE
*/

drop table if exists bank.client;
create table bank.client
(
    client_id         int,
    birth_date         varchar(8),
    district_id     int,
    gender  varchar(1)
);

truncate bank.client;

#load from file
load data local infile '/Users/kvsteau/GoogleDrive/WCD_DS/W6/MidTerm/bank_loan/client.asc'
into table bank.client
fields terminated by ';' ENCLOSED BY '"'
lines terminated by '\n'
ignore 1 lines
;

alter table client add column year varchar(4);
alter table client add column month varchar(2);
alter table client add column day varchar(2);

UPDATE client set day = substring(birth_date,5,2);
UPDATE client set month = substring(birth_date,3,2);
UPDATE client set year = concat('19',substring(birth_date,1,2));


select CAST(birth_date as date) from client;


UPDATE client SET gender = CASE WHEN month > 12 THEN 'f' ELSE 'm' END;
UPDATE client SET month = CASE WHEN gender ='f' THEN month-50 else month END

alter table client add column bdtemp varchar(10);
UPDATE client set bdtemp = concat(year,'-',month,'-',day);

alter table client add column bddate date;
UPDATE client set bddate = CAST(bdtemp as date);

ALTER TABLE client DROP month;
ALTER TABLE client DROP day;
ALTER TABLE client DROP year;
ALTER TABLE client DROP bdtemp;
ALTER TABLE client DROP birth_date;

ALTER TABLE client CHANGE bddate birth_date DATE;


ALTER TABLE client MODIFY gender varchar(1 )AFTER client_id;
ALTER TABLE client MODIFY birth_date date AFTER gender;


select * from client;

/*
  DISP TABLE
*/
drop table if exists bank.disp;
create table bank.disp
(
    disp_id         int,
    client_id        int,
    account_id     int,
    type  varchar(11)
);

truncate bank.disp;

#load from file
load data local infile '/Users/kvsteau/GoogleDrive/WCD_DS/W6/MidTerm/bank_loan/disp.asc'
into table bank.disp
fields terminated by ';'
lines terminated by '\n'
ignore 1 lines
;

UPDATE disp SET type = replace(type,'"','') ;

select * from disp;

/*
  CARD TABLE
*/
drop table if exists bank.card;
create table bank.card
(
    card_id         int,
    disp_id      int,
    type          varchar(20),
    issued     varchar(20)

);

truncate bank.card;

#load from file
load data local infile '/Users/kvsteau/GoogleDrive/WCD_DS/W6/MidTerm/bank_loan/card.asc'
into table bank.card
fields terminated by ';' ENCLOSED BY '"'
lines terminated by '\n'
ignore 1 lines
;
select * from bank.card;

UPDATE card set issued = substring(issued,1,6);

alter table card add column datetemp DATE;
UPDATE card set datetemp = cast(issued as date);
ALTER TABLE card DROP issued;
ALTER TABLE card CHANGE datetemp issued DATE;

/*
  NEW WORLD ORDER TABLE /o\
*/
drop table if exists bank.order;
create table bank.order
(
    order_id         int,
    account_id      int,
    bank_to           varchar(25),
    account_to          varchar(25),
    amount    decimal(12,2),
    k_symbol     varchar(25)

);

truncate bank.order;

#load from file
load data local infile '/Users/kvsteau/GoogleDrive/WCD_DS/W6/MidTerm/bank_loan/order.asc'
into table bank.order
fields terminated by ';'
lines terminated by '\n'
ignore 1 lines
;

use bank;
update bank.order set k_symbol= replace(k_symbol,'"','');
update bank.order set k_symbol= replace(trim(trim('\r'from k_symbol)),'SIPO','household');
update bank.order set k_symbol= replace(trim(k_symbol),'UVER','loan');
update bank.order set k_symbol= replace(trim(k_symbol),'POJISTNE','insurance');
update bank.order set k_symbol= replace(trim(k_symbol),'LEASING','leasing')
update bank.order set k_symbol = NULL WHERE LENGTH(k_symbol) =1;


update bank.order set bank_to= replace(bank_to,'"','');
update bank.order set account_to=cast(replace(account_to,'"','') AS decimal(20,0));


select k_symbol from bank.order
where k_symbol like 'household'

select substring(k_symbol,10) from bank.order;
select length(k_symbol) from bank.order;


/*
  LOAN TABLE
*/

drop table if exists bank.loan;
create table bank.loan
(
    loan_id         int,
    account_id      int,
    date          varchar(6),
    amount     int,
    duration int,
    payments decimal(12,2),
    status varchar(3)

);

truncate bank.loan;

#load from file
load data local infile '/Users/kvsteau/GoogleDrive/WCD_DS/W6/MidTerm/bank_loan/loan.asc'
into table bank.loan
fields terminated by ';'
lines terminated by '\n'
ignore 1 lines
;
select * from bank.loan;

update bank.loan set status= replace(status,'"','');

alter table loan
add column datenew DATE;

UPDATE loan set datenew = CAST(date AS DATE);

ALTER TABLE loan
DROP date;

ALTER TABLE loan CHANGE datenew date DATE;

ALTER TABLE loan MODIFY date date AFTER account_id;


/*
  TRANS TABLE - NE FORMATIROVANO
*/

drop table if exists bank.trans;
create table bank.trans
(
    trans_id         int,
    account_id      int,
    date          varchar(6),
    type varchar(25),
    operation varchar(25),
    amount     int,
    balance int,
    k_symbol varchar(25),
    bank varchar(25),
    account varchar(25)

);

truncate bank.trans;

#load from file
load data local infile '/Users/kvsteau/GoogleDrive/WCD_DS/W6/MidTerm/bank_loan/trans.asc'
into table bank.trans
fields terminated by ';'
lines terminated by '\n'
ignore 1 lines
;
select * from trans
where operation is null;

select * from bank.trans ;

UPDATE trans SET type = CASE
    WHEN type ='"PRIJEM"' THEN 'deposit'
    WHEN type = '"VYBER"' THEN 'cashwithdrawal'
    else 'withdrawal' END;
UPDATE trans SET operation = CASE
    WHEN operation ='"VKLAD"' THEN 'cashdeposit'
    WHEN operation ='"PREVOD Z UCTU"' THEN 'transferin'
    WHEN operation ='"VYBER"' THEN 'cashwithdrawal'
    WHEN operation ='"VYBER KARTOU"' THEN 'ccwithdrawal'
    WHEN operation ='"PREVOD NA UCET"' THEN 'transferout'
    END;

update bank.trans set account=replace(account,'"','')
update bank.trans set account = NULL WHERE LENGTH(account) =1;
update bank.trans set account=case
    when account is not null then cast(account as decimal(20,0))
    end;

update bank.trans set bank=replace(bank,'"','');
update bank.trans set bank = NULL WHERE LENGTH(bank) =0;

update bank.trans set k_symbol=replace(k_symbol,'"','');
UPDATE trans SET k_symbol = CASE
    WHEN k_symbol ='DUCHOD' THEN 'pension'
    WHEN k_symbol ='UVER' THEN 'loanpmt'
    WHEN k_symbol ='SIPO' THEN 'household'
    WHEN k_symbol ='UROK' THEN 'interest'
    WHEN k_symbol ='SANKC. UROK' THEN 'sanctionint'
    WHEN k_symbol ='POJISTNE' THEN 'insurance'
    WHEN k_symbol ='SLUZBY' THEN 'pmtforstt'
    END;
update bank.trans set k_symbol = NULL WHERE LENGTH(k_symbol) =0;

select distinct k_symbol from trans;

alter table trans
add column datenew DATE;

UPDATE trans set datenew = CAST(date AS DATE);

ALTER TABLE trans
DROP date;

ALTER TABLE trans CHANGE datenew date DATE;

ALTER TABLE trans MODIFY date date AFTER account_id;

select *from trans;

#################################

/*
  DISTRICT TABLE - NE FORMATIROVANO
*/


drop table if exists bank.district;
create table bank.district
(
    district_id int,
    A2   varchar(25),
    A3          varchar(25),
    A4 int,
    A5 int,
    A6     int,
    A7 int,
    A8 int,
    A9 int,
    A10 decimal(12,2),
    A11 int,
    A12 decimal(12,2),
    A13 decimal(12,2),
    A14     int,
    A15 int,
    A16 int

);

truncate bank.district;

#load from file
load data local infile '/Users/kvsteau/GoogleDrive/WCD_DS/W6/MidTerm/bank_loan/district.asc'
into table bank.district
fields terminated by ';'
lines terminated by '\n'
ignore 1 lines
;

select* from bank.district;

update bank.district set A2= replace(A2,'"','');
update bank.district set A3= replace(A3,'"','');


