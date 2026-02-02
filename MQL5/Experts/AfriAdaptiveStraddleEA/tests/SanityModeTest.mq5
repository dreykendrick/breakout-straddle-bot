//+------------------------------------------------------------------+
//| SanityModeTest.mq5                                               |
//| Confirms sanity mode should prevent order actions (by logs).     |
//+------------------------------------------------------------------+
#property script_show_inputs
#property strict

input string info = "Attach AfriAdaptiveStraddleEA with sanity_mode=true and verify logs show WOULD_SKIP/Would place without sending orders.";

void OnStart()
  {
   int orders_before = OrdersTotal();
   int positions_before = PositionsTotal();
   Print("[TEST] Sanity mode verification: orders_before=", orders_before, " positions_before=", positions_before);
   Print("[TEST] ", info);
   Print("[TEST] After running EA with sanity mode, there should be no new orders or positions.");
  }
