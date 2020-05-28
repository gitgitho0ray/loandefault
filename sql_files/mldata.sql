use bank;
select
       c.client_id c_id
     , a.account_id
     , l.loan_id
     , l.date
     , l.amount amt
     , l.duration dur
     , l.payments pmt
     , l.status
     , cc.card_id
from
loan l
left join account a on l.account_id = a.account_id
left join disp d on a.account_id = d.account_id
left join client c on d.account_id = c.client_id
left join client_cc cc on c.client_id = cc.client_id;

#CC FLAG
drop table if exists client_cc;
create table client_cc
as(select c2.card_id, loan_id, d.account_id
from client c
inner join disp d on c.client_id = d.client_id
left join card c2 on d.disp_id = c2.disp_id
right join loan l on d.account_id = l.account_id
where c2.card_id is not null and c2.issued<l.date);

select * from client_cc;

update bank.trans set k_symbol = NULL WHERE LENGTH(k_symbol) =0;



##### ACCOUNT_FEATURES

create table act_f as(
select l.loan_id
      , count(sub1.client_id) as  acholders
      , datediff(l.date, a.date) yearswbank
from loan l
join account a on l.account_id = a.account_id
join disp d on a.account_id = d.account_id
join client c on d.client_id = c.client_id
left join client_cc cc on l.loan_id = cc.loan_id
left join (select client_id, account_id
from disp
where type like 'OWNER%') as sub1 on l.account_id = sub1.account_id
group by l.loan_id, datediff(l.date, a.date));



###########################
# TABLE WITH TX BEFORE LOAN RELEASE DATE

select * from trans;
drop table if exists trxb4loan;
create table trxb4loan as
(select t.*, l.loan_id,l.date ldate, l.duration/12 dur, l.payments, l.status
from trans t
    inner join loan l on t.account_id = l.account_id
where t.date <l.date
    );

UPDATE trans set datenew = CAST(date AS DATE);

###########################

alter table trxb4loan
add column negbalflag int(1)

UPDATE trxb4loan SET negbalflag = CASE WHEN balance < 0 THEN '1' ELSE '0' END;

alter table trxb4loan
drop column account;


UPDATE trxb4loan SET status = case when status = 'A' or status = 'C' then 0 else 1 end;
select * from trxb4loan;




#neg bal counter
select loan_id,
       year(date),
       month(date),
       sum(trxb4loan.negbalflag) negc
from trxb4loan
group by loan_id, year(date), month(date)
order by negc desc;

;
select distinct k_symbol from trxb4loan;



##########################################
# CLIENT FEATURES
##########################################
create table client_f as(
select loan_id, gender, aplicant_age, d.* from(
select distinct loan_id,
                gender,
                year(l.date) - year(c.birth_date) aplicant_age,
                district_id d_id
from client c
join (select client_id c_id, account_id
from disp
where trim(type) like 'OWNER%')subq on c.client_id = subq.c_id
join loan l on subq.account_id = l.account_id) subq2
join demos d on subq2.d_id = d.district_id);



select * from district;
#demographica
select
       district_id
    , A10 urbanratio
    , A11 avgsal
    , A12 un95
    , A13 un96
    , round((A14/1000),3) selfemprate
from district;

select A12,A13 from district;

drop table if exists demos;
create table demos as
(select
       district_id
    , A10 urbanratio
    , A11 avgsal
    , A12 un95
    , A13 un96
    , round((A14/1000),3) selfemprate
from district
    );

drop table if exists client_demos;
create table client_demos as
(
select client_id, gender, birth_date, urbanratio, avgsal, un95, un96, selfemprate
from
client c
left join demos d on c.district_id = d.district_id);


########################################################################
# RATIOS FEATURES AND AVERAGE - MAYBE DROP AVG BAL, DEP and WD, leave ratios only?
########################################################################
# TO DO :
# 1. ADD CCFLAG
# 2. FILL NULL RATIOS WITH AVG in PANDAS
########################################################################

drop table if exists loanratios;
create table loanratios as(
select
    loan_id
    , max(dur) as dur
    , max(status) status
    , round(avg(loanpmtcovratio),2) loanpmtcovratio
    , round(avg(solvency),2) solvencyratio
    , round(avg(avg_dep)/avg(avg_wd),2) dpwdratio
    , max(negbalflag) negbalflag
from
(select
    loan_id
      , max(dur) dur
      ,max(status) status
      ,(max(avgmonthlybal) / max(loanpmt)) loanpmtcovratio
      ,(
          (max(avgmonthlybal) / (
              (max(avgmonthlywd)+max(loanpmt))
              )
              )
          ) solvency
     ,year
     , month
     , max(avgmonthlybal) avg_bal
     , avg(avgmonthlydep)avg_dep
     , avg(avgmonthlywd)avg_wd
     , avg(avgmonthlydep)/avg(avgmonthlywd) deptoexpratio
     , max(negbalflag) negbalflag
from
    (select
        loan_id,
        max(dur*12) dur,
        status,
        max(payments) loanpmt,
        avg(balance) avgbal,
        min(balance) min,
        max(balance) maxbal,
        avg(balance) / avg(payments)  dcovratio,
        count(case
                when operation like 'cashwith%' then amount
              end) num_cashwd,
        avg(case
                when operation like 'cashwith%' then amount
              end) avg_cashwd,
        count(case
                when operation like 'cashdep%' then amount
              end) num_cashdep,
        avg(case
                when operation like 'cashdep%' then amount
              end) avg_cashdep,

        count(case
                when k_symbol like 'sanctio%' then 1 else 0
              end) sact_int_count
        , max(negbalflag) negbalcount
    from trxb4loan
    group by loan_id, status
    ) subq
group by loan_id,
order by loan_id,year,month) subq2
group by loan_id);

select * from trxb4loan
where loan_id = 5126;


####GDS
drop table if exists distrtict_gds;
create table distrtict_gds as (
select subq.district_id
    , GDS
    , urbanratio
    , (un96+un95)/2 as avgunemprate
from
(select  a.district_id
       , round(avg(payments)/max(A11),2) GDS
from loan
join account a on loan.account_id = a.account_id
join client c on a.district_id = c.district_id
join district d on a.district_id = d.district_id
group by a.district_id
order by a.district_id asc) subq
join demos d2 on subq.district_id = d2.district_id);

select * from trxb4loan
where operation like 'transferou%';
drop table if exists loanratios1;
create table loanratios1 as(
select
        loan_id,
        status,
        max(dur*12) dur,
        max(payments) loanpmt,
        avg(balance) avgbal,
        min(balance) minbal,
        max(balance) maxbal,
        avg(balance) / avg(payments)  dcovratio,
        count(case
                when operation like 'cashwith%' then amount
              end) num_cashwd,
        avg(case
                when operation like 'cashwith%' then amount
              end) avg_cashwd,
        count(case
                when operation like 'cashdep%' then amount
              end) num_cashdep,
        avg(case
                when operation like 'cashdep%' then amount
              end) avg_cashdep,
        count(case
                when operation like 'transferi%' then amount
              end) num_trin,
        avg(case
                when operation like 'transferi%' then amount
              end) avg_trin,
        count(case
                when operation like 'transferou%' then amount
              end) num_trout,
        avg(case
                when operation like 'transferou%' then amount
              end) avg_trout,
        count(case
                when k_symbol like 'sanctio%' then 1 else 0
              end) sact_int_count
        , max(negbalflag) negbalcount
    from trxb4loan
    group by loan_id, status)

####### FINAL TABLE
drop table if exists mldataset_1;
create table mldataset_1 as(
select
    status,
    dur,
    loanpmt,
    avgbal,
    minbal,
    maxbal,
    dcovratio,
    num_cashwd,
    avg_cashwd,
    num_cashdep,
    avg_cashdep,
    num_trin,
    avg_trin,
    num_trout,
    avg_trout,
    sact_int_count,
    negbalcount,
    case when card_id is null then 0 else 1 end as ccflag,
    acholders,
    yearswbank,
    gender,
    aplicant_age,
     case
        when aplicant_age <=17 then 1
        when aplicant_age between 18 and 24 then 2
        when aplicant_age between 25 and 34 then 3
        when aplicant_age between 35 and 44 then 4
        when aplicant_age between 45 and 54 then 5
        when aplicant_age between 55 and 64 then 6
        when aplicant_age >= 65 then 7
       end agebracket,
     GDS,
     dg.urbanratio,
     avgsal,
     avgunemprate,
     selfemprate
from loanratios1 l
join act_f af on l.loan_id = af.loan_id
join client_f cf on af.loan_id = cf.loan_id
left join client_cc cc on af.loan_id = cc.loan_id
join distrtict_gds dg on cf.district_id = dg.district_id);



