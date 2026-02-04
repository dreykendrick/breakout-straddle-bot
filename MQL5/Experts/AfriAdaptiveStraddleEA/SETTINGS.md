# Settings Reference

## Core Inputs
- `signal_tf` (default M15): timeframe for signal evaluation.
- `lookback_bars` (default 10): consolidation window length.
- `atr_period` (default 14)
- `adx_period` (default 14)
- `ema_period` (default 50)
- `ema_slope_bars` (default 3): number of bars for EMA slope check.
- `ema_slope_atr_mult` (default 0.10): slope threshold normalized by ATR.

## Adaptive Range & Spread Scaling
- `user_min_range_points` (default 40): absolute floor for compression range.
- `user_max_spread_points` (default 25)
- `min_range_atr_mult` / `max_range_atr_mult`
- `atr_buffer_mult` (buffer above/below range in ATR units)
- `max_spread_atr_mult`
- `spread_buffer_mult`

## Category Tuning
- `enable_auto_category_tuning` (default true)
- `allow_manual_override` (default true)

## Risk & Safety
- `risk_percent` (default 0.5)
- `max_trades_per_day` (default 3)
- `daily_max_loss_percent` (default 2.0)
- `cooldown_bars_after_loss` (default 3)
- `slippage_points` (default 10)

## Sessions
- `enable_session_filter` (default true)
- `session1_start_hour` / `session1_end_hour`
- `session2_start_hour` / `session2_end_hour`

## Order & Trade Management
- `expiry_bars` (default 6)
- `tp_mode` (fixed RR, trailing after 1R, breakeven after 1R)
- `rr_fixed_default` (default 1.5)
- `trail_atr_mult` (default 1.0)
- `breakeven_lock_points` (default 5)
- `enable_partial_close` / `partial_close_fraction`

## Multi-Symbol Mode
- `multi_symbol_mode` (default false)
- `symbols_list` (default "EURUSD,GBPUSD,XAUUSD,US30")

## Sanity Mode
- `sanity_mode` (default false)
- `sanity_log_to_csv` (default true)
