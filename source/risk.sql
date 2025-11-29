WITH params AS ( SELECT * FROM v_active_norm_params ),
     weights AS ( SELECT * FROM v_active_risk_weights ),
base AS (
  SELECT ti.symbol, d.date, ti.rsi_14,
         CASE WHEN d.close=0 THEN NULL ELSE ti.atr_14/d.close*100 END AS atr_pct,
         COALESCE((dim_fundamentals.payload->'Highlights'->>'DebtEquity')::numeric,1.0) AS der,
         COALESCE(ti.beta_1y,1.0) AS beta_1y
  FROM fact_tech_indicators ti
  JOIN fact_daily_ohlcv d USING(symbol,date)
  LEFT JOIN dim_fundamentals USING(symbol)
  WHERE d.date = (SELECT MAX(date) FROM fact_daily_ohlcv dd WHERE dd.symbol=ti.symbol)
),
norm AS (
  SELECT b.symbol, b.date,
         LEAST(GREATEST((b.rsi_14 - p.rsi_low) / NULLIF(p.rsi_high - p.rsi_low,0), 0), 1) AS rsi_norm,
         LEAST(GREATEST((b.atr_pct - p.atrp_low) / NULLIF(p.atrp_high - p.atrp_low,0), 0), 1) AS atrp_norm,
         LEAST(GREATEST((b.beta_1y - p.beta_low) / NULLIF(p.beta_high - p.beta_low,0), 0), 1) AS beta_norm,
         LEAST(GREATEST((b.der - p.der_low) / NULLIF(p.der_high - p.der_low,0), 0), 1) AS der_norm
  FROM base b CROSS JOIN params p
)
INSERT INTO fact_weekly_risk(symbol,week_start,rsi_norm,atrp_norm,beta_norm,der_norm,score,bucket)
SELECT n.symbol, date_trunc('week', n.date)::date,
       n.rsi_norm, n.atrp_norm, n.beta_norm, n.der_norm,
       (w.w_rsi*n.rsi_norm + w.w_atr*n.atrp_norm + w.w_beta*n.beta_norm + w.w_der*n.der_norm) AS score,
       CASE
         WHEN (w.w_rsi*n.rsi_norm + w.w_atr*n.atrp_norm + w.w_beta*n.beta_norm + w.w_der*n.der_norm) < 0.30 THEN 'LOW'
         WHEN (w.w_rsi*n.rsi_norm + w.w_atr*n.atrp_norm + w.w_beta*n.beta_norm + w.w_der*n.der_norm) < 0.60 THEN 'MED'
         ELSE 'HIGH'
       END
FROM norm n CROSS JOIN weights w
ON CONFLICT (symbol,week_start) DO UPDATE SET
  rsi_norm=EXCLUDED.rsi_norm, atrp_norm=EXCLUDED.atrp_norm, beta_norm=EXCLUDED.beta_norm, der_norm=EXCLUDED.der_norm,
  score=EXCLUDED.score, bucket=EXCLUDED.bucket;
