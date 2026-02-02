//+------------------------------------------------------------------+
//| AdaptiveThresholdsTest.mq5                                       |
//| Prints dynamic thresholds across two timeframes                  |
//+------------------------------------------------------------------+
#property script_show_inputs
#property strict

input string test_symbol = "";
input ENUM_TIMEFRAMES tf1 = PERIOD_M5;
input ENUM_TIMEFRAMES tf2 = PERIOD_H1;
input int atr_period = 14;
input double min_range_atr_mult = 0.25;
input double max_range_atr_mult = 0.90;
input double atr_buffer_mult = 0.10;
input double max_spread_atr_mult = 0.08;
input double spread_buffer_mult = 2.0;
input double user_min_range_points = 40;
input double user_max_spread_points = 25;

void PrintThresholds(const string symbol, ENUM_TIMEFRAMES tf)
  {
   int handle = iATR(symbol, tf, atr_period);
   if(handle == INVALID_HANDLE)
      return;
   double atr[];
   if(CopyBuffer(handle, 0, 1, 1, atr) != 1)
     {
      IndicatorRelease(handle);
      return;
     }
   IndicatorRelease(handle);

   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   double atr_points = atr[0] / point;
   double spread_points = SymbolInfoInteger(symbol, SYMBOL_SPREAD);
   double tf_multiplier = MathSqrt((double)PeriodSeconds(tf) / 900.0);

   double dyn_min_range = MathMax(user_min_range_points, atr_points * min_range_atr_mult) * tf_multiplier;
   double dyn_max_range = (atr_points * max_range_atr_mult) * tf_multiplier;
   double dyn_buffer = MathMax(spread_points * spread_buffer_mult, atr_points * atr_buffer_mult) * tf_multiplier;
   double dyn_max_spread = MathMax(user_max_spread_points, atr_points * max_spread_atr_mult) * tf_multiplier;

   Print("[TEST] symbol=", symbol, " tf=", EnumToString(tf), " atr_points=", DoubleToString(atr_points, 2),
         " dyn_min=", DoubleToString(dyn_min_range, 2), " dyn_max=", DoubleToString(dyn_max_range, 2),
         " dyn_buffer=", DoubleToString(dyn_buffer, 2), " dyn_max_spread=", DoubleToString(dyn_max_spread, 2));
  }

void OnStart()
  {
   string symbol = test_symbol == "" ? _Symbol : test_symbol;
   PrintThresholds(symbol, tf1);
   PrintThresholds(symbol, tf2);
  }
