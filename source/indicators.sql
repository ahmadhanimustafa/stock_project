WITH base AS (
  SELECT d.symbol, d.date, d.open, d.high, d.low, d.close, d.volume,
         LAG(d.close) OVER (PARTITION BY d.symbol ORDER BY d.date) AS prev_close
  FROM fact_daily_ohlcv d
),
tr_calc AS (
  SELECT symbol, date,
         GREATEST(high-low,
                  ABS(high - COALESCE(prev_close,open)),
                  ABS(low  - COALESCE(prev_close,open))) AS tr
  FROM base
),
atr14 AS (
  SELECT symbol, date,
         AVG(tr) OVER (PARTITION BY symbol ORDER BY date ROWS BETWEEN 13 PRECEDING AND CURRENT ROW) AS atr_14
  FROM tr_calc
),
sma AS (
  SELECT symbol, date,
         AVG(close) OVER (PARTITION BY symbol ORDER BY date ROWS BETWEEN 19 PRECEDING AND CURRENT ROW) AS sma_20,
         AVG(close) OVER (PARTITION BY symbol ORDER BY date ROWS BETWEEN 49 PRECEDING AND CURRENT ROW) AS sma_50,
         STDDEV_SAMP(close) OVER (PARTITION BY symbol ORDER BY date ROWS BETWEEN 19 PRECEDING AND CURRENT ROW) AS sd20,
         close
  FROM base
),
bb AS (
  SELECT symbol, date,
         sma_20 AS bb_mid,
         sma_20 + 2*sd20 AS bb_up,
         sma_20 - 2*sd20 AS bb_dn
  FROM sma
),
chg AS (
  SELECT symbol, date,
         GREATEST(close - LAG(close) OVER (PARTITION BY symbol ORDER BY date), 0) AS gain,
         GREATEST(LAG(close) OVER (PARTITION BY symbol ORDER BY date) - close, 0) AS loss
  FROM base
),
rsi14 AS (
  SELECT symbol, date,
         CASE WHEN AVG(loss) OVER (PARTITION BY symbol ORDER BY date ROWS BETWEEN 13 PRECEDING AND CURRENT ROW)=0
           THEN 100
           ELSE 100 - 100 / (1 + (AVG(gain) OVER (PARTITION BY symbol ORDER BY date ROWS BETWEEN 13 PRECEDING AND CURRENT ROW)
                                   / NULLIF(AVG(loss) OVER (PARTITION BY symbol ORDER BY date ROWS BETWEEN 13 PRECEDING AND CURRENT ROW),0)))
         END AS rsi_14
  FROM chg
)
INSERT INTO fact_tech_indicators(symbol,date,rsi_14,atr_14,sma_20,sma_50,bb_mid,bb_up,bb_dn)
SELECT b.symbol, b.date, r.rsi_14, a.atr_14, s.sma_20, s.sma_50, bb.bb_mid, bb.bb_up, bb.bb_dn
FROM (SELECT DISTINCT symbol,date FROM fact_daily_ohlcv) b
LEFT JOIN rsi14 r ON r.symbol=b.symbol AND r.date=b.date
LEFT JOIN atr14 a ON a.symbol=b.symbol AND a.date=b.date
LEFT JOIN sma s ON s.symbol=b.symbol AND s.date=b.date
LEFT JOIN bb  ON bb.symbol=b.symbol AND bb.date=b.date
ON CONFLICT (symbol,date) DO UPDATE SET
  rsi_14=EXCLUDED.rsi_14, atr_14=EXCLUDED.atr_14,
  sma_20=EXCLUDED.sma_20, sma_50=EXCLUDED.sma_50,
  bb_mid=EXCLUDED.bb_mid, bb_up=EXCLUDED.bb_up, bb_dn=EXCLUDED.bb_dn;
