# Symbol Classification

The EA auto-classifies symbols to choose baseline volatility multipliers.

## Signals Used
1. `SYMBOL_CURRENCY_BASE` and `SYMBOL_CURRENCY_PROFIT`
2. `SYMBOL_PATH`
3. Name heuristics:
   - **METAL:** XAU, XAG, GOLD, SILVER
   - **INDEX:** US30, DJI, SPX, NAS, DE40, GER, UK100, JP225
   - **CRYPTO:** BTC, ETH, USDT, XRP, SOL
4. Trade calculation mode (CFD/Futures hints).

## Categories
- **FOREX**
- **METAL**
- **INDEX**
- **CRYPTO**
- **OTHER**

If `enable_auto_category_tuning=true`, the EA loads category defaults, then applies manual overrides if allowed.
