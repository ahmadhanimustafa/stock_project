WITH last AS ( SELECT MAX(date) AS d FROM fact_daily_ohlcv ),
today AS (
  SELECT d.symbol, d.date, d.close,
         LAG(d.close) OVER (PARTITION BY d.symbol ORDER BY d.date) AS prev_close
  FROM fact_daily_ohlcv d, last
  WHERE d.date = last.d
),
moves AS (
  SELECT
    SUM(CASE WHEN close>prev_close THEN 1 ELSE 0 END) AS adv,
    SUM(CASE WHEN close<prev_close THEN 1 ELSE 0 END) AS dec,
    SUM(CASE WHEN close=prev_close THEN 1 ELSE 0 END) AS no_change
  FROM today
),
ma_flags AS (
  SELECT t.symbol, t.date, d.close,
         CASE WHEN d.close>ti.sma_20 THEN 1 ELSE 0 END AS above20,
         CASE WHEN d.close>ti.sma_50 THEN 1 ELSE 0 END AS above50
  FROM fact_daily_ohlcv d
  JOIN fact_tech_indicators ti USING(symbol,date)
  JOIN today t ON t.symbol=d.symbol AND t.date=d.date
),
agg AS (
  SELECT (SELECT d FROM last) AS date,
         (SELECT adv FROM moves) AS adv, (SELECT dec FROM moves) AS dec, (SELECT no_change FROM moves) AS no_change,
         (SELECT adv::numeric/NULLIF(dec,0) FROM moves) AS adv_dec_ratio,
         AVG(above20)::numeric AS pct_above_ma20, AVG(above50)::numeric AS pct_above_ma50
  FROM ma_flags
)
INSERT INTO fact_breadth_daily(date,adv,dec,no_change,adv_dec_ratio,pct_above_ma20,pct_above_ma50)
SELECT date,adv,dec,no_change,adv_dec_ratio,pct_above_ma20,pct_above_ma50 FROM agg
ON CONFLICT (date) DO UPDATE SET
  adv=EXCLUDED.adv, dec=EXCLUDED.dec, no_change=EXCLUDED.no_change,
  adv_dec_ratio=EXCLUDED.adv_dec_ratio, pct_above_ma20=EXCLUDED.pct_above_ma20, pct_above_ma50=EXCLUDED.pct_above_ma50;

-- Weekly sector rotation snapshot (runs fine even if sector missing; then momentum becomes NULL and ignored downstream)
WITH wk AS ( SELECT date_trunc('week', (SELECT MAX(date) FROM fact_daily_ohlcv))::date AS ws ),
flags AS (
  SELECT d.symbol, ds.sector, d.date, d.close,
         CASE WHEN d.close>ti.sma_20 THEN 1 ELSE 0 END AS above20,
         CASE WHEN d.close>ti.sma_50 THEN 1 ELSE 0 END AS above50,
         LAG(d.close,5) OVER (PARTITION BY d.symbol ORDER BY d.date) AS close_5ago
  FROM fact_daily_ohlcv d
  JOIN fact_tech_indicators ti USING(symbol,date)
  LEFT JOIN dim_symbol ds USING(symbol)
  WHERE d.date BETWEEN (SELECT ws FROM wk) AND (SELECT ws FROM wk) + INTERVAL '4 day'
),
per_sec AS (
  SELECT (SELECT ws FROM wk) AS week_start, sector,
         AVG(above20)::numeric AS pct_above_ma20,
         AVG(above50)::numeric AS pct_above_ma50,
         PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY (close/NULLIF(close_5ago,0)-1)) AS momentum_1w,
         NULL::numeric AS momentum_4w
  FROM flags
  GROUP BY sector
)
INSERT INTO fact_sector_rotation_weekly(week_start,sector,pct_above_ma20,pct_above_ma50,momentum_1w,momentum_4w)
SELECT * FROM per_sec
ON CONFLICT (week_start,sector) DO UPDATE SET
  pct_above_ma20=EXCLUDED.pct_above_ma20, pct_above_ma50=EXCLUDED.pct_above_ma50,
  momentum_1w=EXCLUDED.momentum_1w, momentum_4w=EXCLUDED.momentum_4w;
