# Volatility Scaling

The EA adapts thresholds to the current volatility regime using ATR and timeframe normalization.

## Core Metrics
- `atr_points = ATR(atr_period) / _Point`
- `tf_multiplier = sqrt(PeriodSeconds(signal_tf) / 900)` (baseline M15)
- `spread_points = current spread in points`

## Dynamic Thresholds
- `dyn_min_range_points = max(user_min_range_points, atr_points * min_range_atr_mult) * tf_multiplier`
- `dyn_max_range_points = (atr_points * max_range_atr_mult) * tf_multiplier`
- `dyn_buffer_points = max(spread_points * spread_buffer_mult, atr_points * atr_buffer_mult) * tf_multiplier`
- `dyn_max_spread_points = max(user_max_spread_points, atr_points * max_spread_atr_mult) * tf_multiplier`

These values scale with volatility, allowing the same EA to run across symbols and timeframes without manual re-tuning.
