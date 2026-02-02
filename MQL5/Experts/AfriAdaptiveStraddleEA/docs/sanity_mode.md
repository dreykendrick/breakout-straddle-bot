# Sanity Mode

Sanity mode is a dry-run diagnostics mode that **never sends orders**.

## Behavior
When `sanity_mode=true`:
- No positions are opened or modified.
- No pending orders are created or cancelled.
- All calculations still run: ATR, spread, range, thresholds, filters.
- A structured decision report prints once per symbol per new bar.

## CSV Logging
If `sanity_log_to_csv=true`, the EA appends to:
```
/MQL5/Files/AfriAdaptiveStraddle_sanity.csv
```
Columns:
```
time,symbol,category,tf,atr_points,spread_points,range_points,dyn_min_range,dyn_max_range,dyn_buffer,dyn_max_spread,filters_pass,decision,reason
```

## Recommended Workflow
1. Enable sanity mode in backtests or a demo account.
2. Review filter outcomes and thresholds.
3. Only disable sanity mode after validating behavior.
