-- reset-all.sql
BEGIN;

-- 1) Drop views dulu (biar dependency nggak rewel)
DROP VIEW IF EXISTS v_risk_reward_score;
DROP VIEW IF EXISTS v_active_risk_weights;
DROP VIEW IF EXISTS v_active_norm_params;

-- 2) Drop tables (anak -> induk). IF EXISTS biar idempotent.
DROP TABLE IF EXISTS fact_sector_rotation_weekly;
DROP TABLE IF EXISTS fact_breadth_daily;
DROP TABLE IF EXISTS trade_log;
DROP TABLE IF EXISTS fact_weekly_plan;
DROP TABLE IF EXISTS fact_weekly_reward;
DROP TABLE IF EXISTS fact_weekly_risk;
DROP TABLE IF EXISTS fact_tech_indicators;
DROP TABLE IF EXISTS fact_daily_ohlcv;
DROP TABLE IF EXISTS dim_fundamentals;
DROP TABLE IF EXISTS model_config_norm_params;
DROP TABLE IF EXISTS model_config_risk_weights;
DROP TABLE IF EXISTS dim_symbol;

COMMIT;

-- 3) Recreate schema (tables + views)
-- Dimensi
CREATE TABLE IF NOT EXISTS dim_symbol(
  symbol text PRIMARY KEY,
  name   text,
  sector text
);

CREATE TABLE IF NOT EXISTS dim_fundamentals(
  symbol  text PRIMARY KEY REFERENCES dim_symbol(symbol),
  payload jsonb
);

-- Harga harian
CREATE TABLE IF NOT EXISTS fact_daily_ohlcv(
  symbol text REFERENCES dim_symbol(symbol),
  date   date,
  open   numeric,
  high   numeric,
  low    numeric,
  close  numeric,
  volume numeric,
  PRIMARY KEY(symbol,date)
);

-- Indikator teknikal
CREATE TABLE IF NOT EXISTS fact_tech_indicators(
  symbol   text REFERENCES dim_symbol(symbol),
  date     date,
  rsi_14   numeric,
  atr_14   numeric,
  sma_20   numeric,
  sma_50   numeric,
  ema_12   numeric,
  ema_26   numeric,
  macd     numeric,
  macd_sig numeric,
  bb_mid   numeric,
  bb_up    numeric,
  bb_dn    numeric,
  beta_1y  numeric,
  PRIMARY KEY(symbol,date)
);

-- Konfigurasi bobot risk dinamis
CREATE TABLE IF NOT EXISTS model_config_risk_weights(
  effective_from date PRIMARY KEY,
  w_rsi  numeric NOT NULL,
  w_atr  numeric NOT NULL,
  w_beta numeric NOT NULL,
  w_der  numeric NOT NULL,
  note   text,
  created_at timestamptz DEFAULT now()
);

CREATE OR REPLACE VIEW v_active_risk_weights AS
SELECT w.*
FROM model_config_risk_weights w
WHERE w.effective_from = (
  SELECT MAX(effective_from)
  FROM model_config_risk_weights
  WHERE effective_from <= CURRENT_DATE
);

-- Parameter normalisasi dinamis
CREATE TABLE IF NOT EXISTS model_config_norm_params(
  effective_from date PRIMARY KEY,
  rsi_low  numeric DEFAULT 30,
  rsi_high numeric DEFAULT 70,
  atrp_low numeric DEFAULT 1.5,
  atrp_high numeric DEFAULT 10,
  beta_low numeric DEFAULT 0.6,
  beta_high numeric DEFAULT 1.4,
  der_low  numeric DEFAULT 0.3,
  der_high numeric DEFAULT 1.5,
  note     text,
  created_at timestamptz DEFAULT now()
);

CREATE OR REPLACE VIEW v_active_norm_params AS
SELECT p.*
FROM model_config_norm_params p
WHERE p.effective_from = (
  SELECT MAX(effective_from)
  FROM model_config_norm_params
  WHERE effective_from <= CURRENT_DATE
);

-- Skor risk mingguan
CREATE TABLE IF NOT EXISTS fact_weekly_risk(
  symbol     text REFERENCES dim_symbol(symbol),
  week_start date,
  rsi_norm   numeric,
  atrp_norm  numeric,
  beta_norm  numeric,
  der_norm   numeric,
  score      numeric,
  bucket     text,
  PRIMARY KEY(symbol,week_start)
);

-- Skor reward mingguan
CREATE TABLE IF NOT EXISTS fact_weekly_reward(
  symbol       text REFERENCES dim_symbol(symbol),
  week_start   date,
  mom_norm     numeric,
  trend_norm   numeric,
  bb_norm      numeric,
  vol_norm     numeric,
  sector_norm  numeric,
  reward_score numeric,
  PRIMARY KEY(symbol,week_start)
);

-- View gabungan risk+reward
CREATE OR REPLACE VIEW v_risk_reward_score AS
SELECT r.symbol,
       r.week_start,
       r.score AS risk_score,
       COALESCE(w.reward_score,0) AS reward_score,
       CASE WHEN r.score > 0
            THEN COALESCE(w.reward_score,0)/r.score
       END AS rr_ratio,
       ROW_NUMBER() OVER (
         PARTITION BY r.week_start
         ORDER BY COALESCE(w.reward_score,0) DESC, r.score ASC, r.symbol
       ) AS rr_rank
FROM fact_weekly_risk r
LEFT JOIN fact_weekly_reward w
  ON w.symbol = r.symbol
 AND w.week_start = r.week_start;

-- Trading plan & trade log
CREATE TABLE IF NOT EXISTS fact_weekly_plan(
  symbol     text REFERENCES dim_symbol(symbol),
  week_start date,
  thesis     text,
  entry_min  numeric,
  entry_max  numeric,
  stop_loss  numeric,
  target_1   numeric,
  target_2   numeric,
  position_sz integer,
  notes      text,
  PRIMARY KEY(symbol,week_start)
);

CREATE TABLE IF NOT EXISTS trade_log(
  id          bigserial PRIMARY KEY,
  symbol      text REFERENCES dim_symbol(symbol),
  ts_open     timestamptz,
  ts_close    timestamptz,
  entry_price numeric,
  exit_price  numeric,
  qty         integer
);

-- Breadth & sektor rotation
CREATE TABLE IF NOT EXISTS fact_breadth_daily(
  date            date PRIMARY KEY,
  adv             integer,
  dec             integer,
  no_change       integer,
  adv_dec_ratio   numeric,
  pct_above_ma20  numeric,
  pct_above_ma50  numeric,
  created_at      timestamptz DEFAULT now()
);

CREATE TABLE IF NOT EXISTS fact_sector_rotation_weekly(
  week_start     date,
  sector         text,
  pct_above_ma20 numeric,
  pct_above_ma50 numeric,
  momentum_1w    numeric,
  momentum_4w    numeric,
  PRIMARY KEY(week_start,sector)
);

-- 4) Seeds default
INSERT INTO model_config_risk_weights(effective_from,w_rsi,w_atr,w_beta,w_der,note)
VALUES (CURRENT_DATE,0.3,0.3,0.2,0.2,'seed')
ON CONFLICT DO NOTHING;

INSERT INTO model_config_norm_params(effective_from)
VALUES (CURRENT_DATE)
ON CONFLICT DO NOTHING;
