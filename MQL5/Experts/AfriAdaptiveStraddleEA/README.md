# AfriAdaptiveStraddleEA

AfriAdaptiveStraddleEA is a production-grade MT5 Expert Advisor that trades a **filtered, adaptive breakout straddle**. It is designed to work across symbols (FX, metals, indices, crypto), timeframes, and volatility regimes by dynamically scaling thresholds. The EA focuses on **non-gambling** behavior with strict filters, risk limits, and optional **SANITY MODE** (dry-run diagnostics).

## Features
- **Adaptive volatility scaling** using ATR and timeframe normalization.
- **Auto symbol classification** (FOREX, METAL, INDEX, CRYPTO, OTHER) with category defaults.
- **Compression → breakout** straddle with OCO (one-cancels-other).
- **Conservative filters**: ADX, EMA slope, spread, sessions, cooldowns, max trades/day, daily loss limit.
- **Risk-based position sizing** based on stop distance.
- **SANITY MODE** for diagnostics: no orders sent, structured logs + optional CSV output.

## Quick Start (Recommended: Sanity Mode)
1. Attach the EA to a chart and set `sanity_mode=true`.
2. Watch the **Experts** log for the decision report. You can also enable CSV logging (`sanity_log_to_csv=true`).
3. Once filters behave as expected, disable sanity mode to allow trading.

## Switching Pairs / Timeframes
- **Single symbol:** by default the EA trades the chart symbol.
- **Multi-symbol mode:** set `multi_symbol_mode=true` and update `symbols_list`.
- Change the signal timeframe via `signal_tf`.

## Auto Category Tuning
- Enable `enable_auto_category_tuning=true` to apply category defaults.
- To override, keep `allow_manual_override=true` and set the manual inputs (ATR multipliers, RR, etc.).

## Backtesting & Optimization Guidance
- Use **sanity mode** first to validate filters and scaling.
- Optimize only a few multipliers (e.g., `min_range_atr_mult`, `max_range_atr_mult`, `atr_buffer_mult`) instead of all parameters.
- Keep `risk_percent` small and maintain strict daily loss limits.

## File Structure
```
MQL5/Experts/AfriAdaptiveStraddleEA/
  AfriAdaptiveStraddleEA.mq5
  README.md
  SETTINGS.md
  CHANGELOG.md
  docs/
    volatility_scaling.md
    symbol_classification.md
    sanity_mode.md
  tests/
    ClassificationTest.mq5
    AdaptiveThresholdsTest.mq5
    SanityModeTest.mq5
    OCOTestEA.mq5
```

## Notes
- The EA **never trades** in sanity mode.
- The OCO logic is handled in `OnTradeTransaction`.
- Spread spikes can cancel pending orders to prevent bad fills.

- MT5 mobile apps do **not** run EAs; use the desktop terminal or a VPS for live execution.

