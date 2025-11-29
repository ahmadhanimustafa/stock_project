WITH latest AS ( SELECT symbol, MAX(date) AS d FROM fact_daily_ohlcv GROUP BY symbol ),
base AS (
  SELECT d.symbol, d.date, d.close, d.volume, ti.atr_14, ti.sma_20, ti.sma_50, ti.bb_up, ti.bb_dn,
         LAG(d.close,5) OVER (PARTITION BY d.symbol ORDER BY d.date) AS close_5ago,
         AVG(d.volume) OVER (PARTITION BY d.symbol ORDER BY d.date ROWS BETWEEN 20 PRECEDING AND 1 PRECEDING) AS vol20
  FROM fact_daily_ohlcv d
  JOIN fact_tech_indicators ti USING(symbol,date)
  JOIN latest l ON d.symbol=l.symbol AND d.date=l.d
),
norm AS (
  SELECT symbol,
         date_trunc('week', date)::date AS week_start,
         LEAST(GREATEST(((close - close_5ago)/NULLIF(atr_14,0) + 5)/10,0),1) AS mom_norm,
         LEAST(GREATEST(((sma_20 - sma_50)/NULLIF(sma_50,0) + 0.1)/0.3,0),1) AS trend_norm,
         LEAST(GREATEST(((close - bb_dn)/NULLIF(bb_up - bb_dn,0)),0),1) AS bb_norm,
         LEAST(GREATEST(((volume/NULLIF(vol20,1)) - 1)/1.5,0),1) AS vol_norm,
         0.5::numeric AS sector_norm -- fallback; overridden when sector rotation table exists
  FROM base
)
INSERT INTO fact_weekly_reward(symbol, week_start, mom_norm, trend_norm, bb_norm, vol_norm, sector_norm, reward_score)
SELECT symbol, week_start, mom_norm, trend_norm, bb_norm, vol_norm, sector_norm,
       (0.25*mom_norm + 0.25*trend_norm + 0.20*bb_norm + 0.15*sector_norm + 0.15*vol_norm)
FROM norm
ON CONFLICT (symbol, week_start) DO UPDATE SET
  mom_norm=EXCLUDED.mom_norm, trend_norm=EXCLUDED.trend_norm, bb_norm=EXCLUDED.bb_norm,
  vol_norm=EXCLUDED.vol_norm, sector_norm=EXCLUDED.sector_norm, reward_score=EXCLUDED.reward_score;
