truncate fact_daily_ohlcv

select count(distinct(symbol)) 
from fact_daily_ohlcv


select count(*)
from fact_daily_ohlcv

select count(symbol)
from dim_symbol

with base as(
select symbol,min(date),max(date), count(*),count(distinct(date_trunc('day',date))),max(date_trunc('day',date))date
from fact_daily_ohlcv
group by 1
)
select a.symbol
from dim_symbol a
left join base b on a.symbol=b.symbol
where date_trunc('day',b.date)<'2025-11-03'
b.symbol is null

select symbol,min(date),max(date), count(*),count(distinct(date_trunc('day',date))),max(date_trunc('day',date))date
from fact_daily_ohlcv
group by 1


  SELECT symbol, week_start, risk_score, reward_score, rr_ratio
  FROM v_risk_reward_score


  select *
  from fact_weekly_plan
  order by week_start desc

  select date_trunc('week', CURRENT_DATE)::date

  select *
  from v_risk_reward_score
  order by week_start desc

  select *
  from fact_weekly_reward
  where symbol='BBCA.JK'

