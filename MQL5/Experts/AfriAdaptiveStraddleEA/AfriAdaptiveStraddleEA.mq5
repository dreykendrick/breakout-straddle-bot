//+------------------------------------------------------------------+
//|                                            AfriAdaptiveStraddleEA|
//|                        Adaptive breakout straddle (non-gambling) |
//+------------------------------------------------------------------+
#property copyright ""

#property version   "1.0.0"

#property strict

#include <Trade/Trade.mqh>

enum TpMode
  {
   TP_FIXED_RR = 0,
   TP_TRAIL_AFTER_1R = 1,
   TP_BREAKEVEN_1R = 2
  };

enum SymbolCategory
  {
   CATEGORY_FOREX = 0,
   CATEGORY_METAL = 1,
   CATEGORY_INDEX = 2,
   CATEGORY_CRYPTO = 3,
   CATEGORY_OTHER = 4
  };

struct CategoryDefaults
  {
   double min_range_atr_mult;
   double max_range_atr_mult;
   double atr_buffer_mult;
   double max_spread_atr_mult;
   double spread_buffer_mult;
   double adx_max;
   double rr_default;
  };

struct SymbolState
  {
   string symbol;
   datetime last_bar_time;
   long magic;
  };

input ENUM_TIMEFRAMES signal_tf = PERIOD_M15;
input int lookback_bars = 10;
input int atr_period = 14;
input int adx_period = 14;
input int ema_period = 50;
input int ema_slope_bars = 3;
input double ema_slope_atr_mult = 0.10;
input double user_min_range_points = 40;
input double user_max_spread_points = 25;
input double min_range_atr_mult = 0.25;
input double max_range_atr_mult = 0.90;
input double atr_buffer_mult = 0.10;
input double max_spread_atr_mult = 0.08;
input double spread_buffer_mult = 2.0;
input double rr_fixed_default = 1.5;
input bool enable_auto_category_tuning = true;
input bool allow_manual_override = true;
input bool enable_ema_slope_filter = true;
input bool enable_session_filter = true;
input int session1_start_hour = 7;
input int session1_start_minute = 0;
input int session1_end_hour = 11;
input int session1_end_minute = 0;
input int session2_start_hour = 13;
input int session2_start_minute = 0;
input int session2_end_hour = 17;
input int session2_end_minute = 0;
input int expiry_bars = 6;
input double risk_percent = 0.5;
input int max_trades_per_day = 3;
input double daily_max_loss_percent = 2.0;
input int cooldown_bars_after_loss = 3;
input int slippage_points = 10;
input int base_magic = 20251001;
input TpMode tp_mode = TP_FIXED_RR;
input double trail_atr_mult = 1.0;
input double breakeven_lock_points = 5;
input bool enable_partial_close = false;
input double partial_close_fraction = 0.5;
input bool multi_symbol_mode = false;
input string symbols_list = "EURUSD,GBPUSD,XAUUSD,US30";
input bool sanity_mode = false;
input bool sanity_log_to_csv = true;

CTrade trade;
SymbolState states[];

//+------------------------------------------------------------------+
//| Utility helpers                                                  |
//+------------------------------------------------------------------+
string Trim(const string value)
  {
   string result = value;
   StringTrimLeft(result);
   StringTrimRight(result);
   return result;
  }

string CategoryToString(SymbolCategory category)
  {
   switch(category)
     {
      case CATEGORY_FOREX: return "FOREX";
      case CATEGORY_METAL: return "METAL";
      case CATEGORY_INDEX: return "INDEX";
      case CATEGORY_CRYPTO: return "CRYPTO";
      default: return "OTHER";
     }
  }

int MinutesOfDay(int hour, int minute)
  {
   return (hour * 60) + minute;
  }

bool IsWithinSession(datetime t)
  {
   if(!enable_session_filter)
      return true;

   MqlDateTime dt;
   TimeToStruct(t, dt);
   int now_minutes = MinutesOfDay(dt.hour, dt.min);
   int s1_start = MinutesOfDay(session1_start_hour, session1_start_minute);
   int s1_end = MinutesOfDay(session1_end_hour, session1_end_minute);
   int s2_start = MinutesOfDay(session2_start_hour, session2_start_minute);
   int s2_end = MinutesOfDay(session2_end_hour, session2_end_minute);

   bool in_s1 = (now_minutes >= s1_start && now_minutes <= s1_end);
   bool in_s2 = (now_minutes >= s2_start && now_minutes <= s2_end);
   return (in_s1 || in_s2);
  }

long HashSymbol(const string symbol)
  {
   long hash = 0;
   for(int i = 0; i < StringLen(symbol); i++)
      hash = (hash * 31) + StringGetCharacter(symbol, i);
   if(hash < 0)
      hash = -hash;
   return hash % 100000;
  }

bool GetRatesCount(const string symbol, ENUM_TIMEFRAMES tf, int bars)
  {
   int available = Bars(symbol, tf);
   return (available >= bars + 2);
  }

bool GetRange(const string symbol, ENUM_TIMEFRAMES tf, int bars, double &range_high, double &range_low)
  {
   if(!GetRatesCount(symbol, tf, bars))
      return false;

   int start = 1;
   int highest = iHighest(symbol, tf, MODE_HIGH, bars, start);
   int lowest = iLowest(symbol, tf, MODE_LOW, bars, start);

   if(highest < 0 || lowest < 0)
      return false;

   range_high = iHigh(symbol, tf, highest);
   range_low = iLow(symbol, tf, lowest);
   return true;
  }

double GetIndicatorValue(int handle, int buffer_index, int shift)
  {
   double values[];
   if(CopyBuffer(handle, buffer_index, shift, 1, values) != 1)
      return EMPTY_VALUE;
   return values[0];
  }

SymbolCategory ClassifySymbol(const string symbol, string &method)
  {
   string base = SymbolInfoString(symbol, SYMBOL_CURRENCY_BASE);
   string profit = SymbolInfoString(symbol, SYMBOL_CURRENCY_PROFIT);
   string path = SymbolInfoString(symbol, SYMBOL_PATH);
   long calc_mode = SymbolInfoInteger(symbol, SYMBOL_TRADE_CALC_MODE);


   string name_upper = symbol;
   string path_upper = path;
   StringToUpper(name_upper);
   StringToUpper(path_upper);


   string name_upper = StringToUpper(symbol);
   string path_upper = StringToUpper(path);

   string name_upper = StringUpper(symbol);
   string path_upper = StringUpper(path);


   if(StringFind(path_upper, "FOREX") >= 0 || (StringLen(base) == 3 && StringLen(profit) == 3))
     {
      method = "PATH/BASE";
      return CATEGORY_FOREX;
     }

   if(StringFind(path_upper, "METAL") >= 0 || StringFind(name_upper, "XAU") >= 0 || StringFind(name_upper, "XAG") >= 0 || StringFind(name_upper, "GOLD") >= 0 || StringFind(name_upper, "SILVER") >= 0)
     {
      method = "PATH/NAME";
      return CATEGORY_METAL;
     }

   if(StringFind(path_upper, "INDEX") >= 0 || StringFind(name_upper, "US30") >= 0 || StringFind(name_upper, "DJI") >= 0 || StringFind(name_upper, "SPX") >= 0 || StringFind(name_upper, "NAS") >= 0 || StringFind(name_upper, "DE40") >= 0 || StringFind(name_upper, "GER") >= 0 || StringFind(name_upper, "UK100") >= 0 || StringFind(name_upper, "JP225") >= 0)
     {
      method = "PATH/NAME";
      return CATEGORY_INDEX;
     }

   if(StringFind(path_upper, "CRYPTO") >= 0 || StringFind(name_upper, "BTC") >= 0 || StringFind(name_upper, "ETH") >= 0 || StringFind(name_upper, "USDT") >= 0 || StringFind(name_upper, "XRP") >= 0 || StringFind(name_upper, "SOL") >= 0)
     {
      method = "PATH/NAME";
      return CATEGORY_CRYPTO;
     }

   if(calc_mode == SYMBOL_TRADE_CALC_MODE_CFD || calc_mode == SYMBOL_TRADE_CALC_MODE_EXCH_FUTURES)
     {
      method = "CALC_MODE";
      return CATEGORY_INDEX;
     }

   method = "FALLBACK";
   return CATEGORY_OTHER;
  }

CategoryDefaults DefaultsForCategory(SymbolCategory category)
  {
   CategoryDefaults def;
   switch(category)
     {
      case CATEGORY_FOREX:
         def.min_range_atr_mult = 0.25;
         def.max_range_atr_mult = 0.90;
         def.atr_buffer_mult = 0.10;
         def.max_spread_atr_mult = 0.08;
         def.spread_buffer_mult = 2.0;
         def.adx_max = 25;
         def.rr_default = 1.5;
         break;
      case CATEGORY_METAL:
         def.min_range_atr_mult = 0.30;
         def.max_range_atr_mult = 1.00;
         def.atr_buffer_mult = 0.14;
         def.max_spread_atr_mult = 0.12;
         def.spread_buffer_mult = 2.5;
         def.adx_max = 23;
         def.rr_default = 1.3;
         break;
      case CATEGORY_INDEX:
         def.min_range_atr_mult = 0.35;
         def.max_range_atr_mult = 1.05;
         def.atr_buffer_mult = 0.16;
         def.max_spread_atr_mult = 0.15;
         def.spread_buffer_mult = 2.5;
         def.adx_max = 22;
         def.rr_default = 1.3;
         break;
      case CATEGORY_CRYPTO:
         def.min_range_atr_mult = 0.40;
         def.max_range_atr_mult = 1.20;
         def.atr_buffer_mult = 0.20;
         def.max_spread_atr_mult = 0.20;
         def.spread_buffer_mult = 3.0;
         def.adx_max = 20;
         def.rr_default = 1.2;
         break;
      default:
         def.min_range_atr_mult = min_range_atr_mult;
         def.max_range_atr_mult = max_range_atr_mult;
         def.atr_buffer_mult = atr_buffer_mult;
         def.max_spread_atr_mult = max_spread_atr_mult;
         def.spread_buffer_mult = spread_buffer_mult;
         def.adx_max = 25;
         def.rr_default = rr_fixed_default;
         break;
     }
   return def;
  }

void ApplyOverrides(CategoryDefaults &def)
  {
   if(allow_manual_override)
     {
      def.min_range_atr_mult = min_range_atr_mult;
      def.max_range_atr_mult = max_range_atr_mult;
      def.atr_buffer_mult = atr_buffer_mult;
      def.max_spread_atr_mult = max_spread_atr_mult;
      def.spread_buffer_mult = spread_buffer_mult;
      def.rr_default = rr_fixed_default;
     }
  }

void ResolveCategoryParams(SymbolCategory category, CategoryDefaults &out)
  {
   if(enable_auto_category_tuning)
      out = DefaultsForCategory(category);
   else
     {
      out.min_range_atr_mult = min_range_atr_mult;
      out.max_range_atr_mult = max_range_atr_mult;
      out.atr_buffer_mult = atr_buffer_mult;
      out.max_spread_atr_mult = max_spread_atr_mult;
      out.spread_buffer_mult = spread_buffer_mult;
      out.adx_max = 25;
      out.rr_default = rr_fixed_default;
     }

   ApplyOverrides(out);
  }

bool HasOpenPosition(const string symbol, long magic)
  {
   for(int i = 0; i < PositionsTotal(); i++)
     {
      if(PositionGetTicket(i) > 0)
        {
         if(PositionGetString(POSITION_SYMBOL) == symbol && PositionGetInteger(POSITION_MAGIC) == magic)
            return true;
        }
     }
   return false;
  }

bool HasPendingOrders(const string symbol, long magic)
  {
   for(int i = 0; i < OrdersTotal(); i++)
     {
      if(OrderGetTicket(i) > 0)
        {
         if(OrderGetString(ORDER_SYMBOL) == symbol && OrderGetInteger(ORDER_MAGIC) == magic)
            return true;
        }
     }
   return false;
  }

int CountDealsToday(const string symbol, long magic)
  {
   datetime day_start = iTime(symbol, PERIOD_D1, 0);
   datetime now = TimeCurrent();
   if(!HistorySelect(day_start, now))
      return 0;

   int count = 0;
   uint deals = HistoryDealsTotal();
   for(uint i = 0; i < deals; i++)
     {
      ulong ticket = HistoryDealGetTicket(i);
      if(HistoryDealGetString(ticket, DEAL_SYMBOL) != symbol)
         continue;
      if(HistoryDealGetInteger(ticket, DEAL_MAGIC) != magic)
         continue;
      long entry = HistoryDealGetInteger(ticket, DEAL_ENTRY);
      if(entry == DEAL_ENTRY_IN)
         count++;
     }
   return count;
  }

bool DailyLossLimitHit(const string symbol, long magic)
  {
   datetime day_start = iTime(symbol, PERIOD_D1, 0);
   datetime now = TimeCurrent();
   if(!HistorySelect(day_start, now))
      return false;

   double profit = 0.0;
   uint deals = HistoryDealsTotal();
   for(uint i = 0; i < deals; i++)
     {
      ulong ticket = HistoryDealGetTicket(i);
      if(HistoryDealGetString(ticket, DEAL_SYMBOL) != symbol)
         continue;
      if(HistoryDealGetInteger(ticket, DEAL_MAGIC) != magic)
         continue;
      profit += HistoryDealGetDouble(ticket, DEAL_PROFIT);
     }

   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double max_loss = -balance * (daily_max_loss_percent / 100.0);
   return (profit <= max_loss);
  }

bool CooldownActive(const string symbol, long magic)
  {
   if(cooldown_bars_after_loss <= 0)
      return false;

   datetime now = TimeCurrent();
   if(!HistorySelect(0, now))
      return false;

   uint deals = HistoryDealsTotal();
   for(int i = (int)deals - 1; i >= 0; i--)
     {
      ulong ticket = HistoryDealGetTicket(i);
      if(HistoryDealGetString(ticket, DEAL_SYMBOL) != symbol)
         continue;
      if(HistoryDealGetInteger(ticket, DEAL_MAGIC) != magic)
         continue;
      long entry = HistoryDealGetInteger(ticket, DEAL_ENTRY);
      if(entry != DEAL_ENTRY_OUT)
         continue;
      double profit = HistoryDealGetDouble(ticket, DEAL_PROFIT);
      if(profit >= 0)
         return false;
      datetime exit_time = (datetime)HistoryDealGetInteger(ticket, DEAL_TIME);
      datetime cooldown_time = iTime(symbol, signal_tf, 0) - (cooldown_bars_after_loss * PeriodSeconds(signal_tf));
      return exit_time >= cooldown_time;
     }
   return false;
  }

bool SanityLog(const string line)
  {
   if(!sanity_log_to_csv)
      return false;

   int handle = FileOpen("AfriAdaptiveStraddle_sanity.csv", FILE_READ | FILE_WRITE | FILE_CSV | FILE_SHARE_READ | FILE_SHARE_WRITE);
   if(handle == INVALID_HANDLE)
     {
      Print("[SANITY] Failed to open CSV: ", GetLastError());
      return false;
     }

   if(FileSize(handle) == 0)
     {
      FileWrite(handle, "time", "symbol", "category", "tf", "atr_points", "spread_points", "range_points", "dyn_min_range", "dyn_max_range", "dyn_buffer", "dyn_max_spread", "filters_pass", "decision", "reason");
     }

   FileSeek(handle, 0, SEEK_END);
   FileWriteString(handle, line + "\n");
   FileClose(handle);
   return true;
  }

void LogDecision(const string symbol, const string category, ENUM_TIMEFRAMES tf, double atr_points, double spread_points, double range_points,
                 double dyn_min_range, double dyn_max_range, double dyn_buffer, double dyn_max_spread,
                 bool filters_pass, const string decision, const string reason)
  {
   string header = StringFormat("[SANITY] symbol=%s category=%s tf=%s time=%s", symbol, category, EnumToString(tf), TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS));
   string metrics = StringFormat("atr_points=%.2f spread_points=%.2f range_points=%.2f dyn_min_range=%.2f dyn_max_range=%.2f dyn_buffer=%.2f dyn_max_spread=%.2f",
                                 atr_points, spread_points, range_points, dyn_min_range, dyn_max_range, dyn_buffer, dyn_max_spread);
   string filters = StringFormat("filters_pass=%s decision=%s reason=%s", filters_pass ? "YES" : "NO", decision, reason);

   Print(header);
   Print(metrics);
   Print(filters);

   if(sanity_log_to_csv)
     {
      string csv = StringFormat("%s,%s,%s,%s,%.2f,%.2f,%.2f,%.2f,%.2f,%.2f,%.2f,%s,%s,%s",
                                TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS), symbol, category, EnumToString(tf), atr_points, spread_points,
                                range_points, dyn_min_range, dyn_max_range, dyn_buffer, dyn_max_spread,
                                filters_pass ? "TRUE" : "FALSE", decision, reason);
      SanityLog(csv);
     }
  }

bool PlacePendingOrders(const string symbol, long magic, double buy_stop, double sell_stop, double sl_buy, double sl_sell, double tp_buy, double tp_sell, datetime expiry_time)
  {
   trade.SetDeviationInPoints(slippage_points);
   trade.SetExpertMagicNumber(magic);
   trade.SetTypeFillingBySymbol(symbol);

   double buy_lots = GetPositionSize(symbol, buy_stop, sl_buy);
   double sell_lots = GetPositionSize(symbol, sell_stop, sl_sell);
   if(buy_lots <= 0 || sell_lots <= 0)
     {
      Print("[ORDER] Invalid lot size for ", symbol, " buy=", buy_lots, " sell=", sell_lots);
      return false;
     }

   ENUM_ORDER_TYPE_TIME time_type = (expiry_bars > 0) ? ORDER_TIME_SPECIFIED : ORDER_TIME_GTC;
   bool buy_ok = trade.BuyStop(buy_lots, buy_stop, symbol, sl_buy, tp_buy, time_type, expiry_time, "AfriStraddle buy");
   if(!buy_ok)
      Print("[ORDER] Buy stop failed: ", trade.ResultRetcode(), " ", trade.ResultRetcodeDescription());

   bool sell_ok = trade.SellStop(sell_lots, sell_stop, symbol, sl_sell, tp_sell, time_type, expiry_time, "AfriStraddle sell");
   if(!sell_ok)
      Print("[ORDER] Sell stop failed: ", trade.ResultRetcode(), " ", trade.ResultRetcodeDescription());

   return (buy_ok && sell_ok);
  }

void CancelPendingOrders(const string symbol, long magic, const string reason)
  {
   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(OrderGetTicket(i) > 0)
        {
         if(OrderGetString(ORDER_SYMBOL) != symbol)
            continue;
         if(OrderGetInteger(ORDER_MAGIC) != magic)
            continue;
         ulong ticket = OrderGetTicket(i);
         if(trade.OrderDelete(ticket))
            Print("[OCO] Cancelled order ", ticket, " reason=", reason);
         else
            Print("[OCO] Failed cancel order ", ticket, " reason=", reason, " ret=", trade.ResultRetcode());
        }
     }
  }

void CancelOpposite(const string symbol, long magic, ENUM_ORDER_TYPE filled_type)
  {
   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(OrderGetTicket(i) > 0)
        {
         if(OrderGetString(ORDER_SYMBOL) != symbol)
            continue;
         if(OrderGetInteger(ORDER_MAGIC) != magic)
            continue;
         ENUM_ORDER_TYPE type = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
         if((filled_type == ORDER_TYPE_BUY_STOP && type == ORDER_TYPE_SELL_STOP) ||
            (filled_type == ORDER_TYPE_SELL_STOP && type == ORDER_TYPE_BUY_STOP))
           {
            ulong ticket = OrderGetTicket(i);
            if(trade.OrderDelete(ticket))
               Print("[OCO] Cancelled opposite pending order ", ticket);
            else
               Print("[OCO] Failed to cancel opposite order ", ticket, " ret=", trade.ResultRetcode());
           }
        }
     }
  }

//+------------------------------------------------------------------+
//| Risk and sizing                                                  |
//+------------------------------------------------------------------+
double GetPositionSize(const string symbol, double entry_price, double stop_price)
  {
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double risk_amount = balance * (risk_percent / 100.0);
   double tick_value = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
   double tick_size = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   double stop_points = MathAbs(entry_price - stop_price) / point;

   if(stop_points <= 0 || tick_size <= 0 || tick_value <= 0)
      return 0.0;

   double value_per_point = tick_value / (tick_size / point);
   double lots = risk_amount / (stop_points * value_per_point);

   double min_lot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   double max_lot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
   double step = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);

   lots = MathMax(min_lot, MathMin(max_lot, lots));
   lots = MathFloor(lots / step) * step;
   return NormalizeDouble(lots, 2);
  }

//+------------------------------------------------------------------+
//| Strategy evaluation                                              |
//+------------------------------------------------------------------+
void EvaluateSymbol(SymbolState &state)
  {
   string symbol = state.symbol;
   if(!SymbolSelect(symbol, true))
     {
      Print("[INIT] Failed to select symbol ", symbol);
      return;
     }

   if(!GetRatesCount(symbol, signal_tf, lookback_bars))
      return;

   datetime current_bar = iTime(symbol, signal_tf, 0);
   if(current_bar == state.last_bar_time)
      return;

   state.last_bar_time = current_bar;

   double range_high = 0.0;
   double range_low = 0.0;
   if(!GetRange(symbol, signal_tf, lookback_bars, range_high, range_low))
      return;

   string method = "";
   SymbolCategory category = ClassifySymbol(symbol, method);
   CategoryDefaults def;
   ResolveCategoryParams(category, def);

   int atr_handle = iATR(symbol, signal_tf, atr_period);
   int adx_handle = iADX(symbol, signal_tf, adx_period);
   int ema_handle = iMA(symbol, signal_tf, ema_period, 0, MODE_EMA, PRICE_CLOSE);

   if(atr_handle == INVALID_HANDLE || adx_handle == INVALID_HANDLE || ema_handle == INVALID_HANDLE)
     {
      Print("[IND] Indicator handle error for ", symbol);
      return;
     }

   double atr = GetIndicatorValue(atr_handle, 0, 1);
   double adx = GetIndicatorValue(adx_handle, 0, 1);
   double ema1 = GetIndicatorValue(ema_handle, 0, 1);
   double ema3 = GetIndicatorValue(ema_handle, 0, ema_slope_bars);

   IndicatorRelease(atr_handle);
   IndicatorRelease(adx_handle);
   IndicatorRelease(ema_handle);

   if(atr == EMPTY_VALUE || adx == EMPTY_VALUE || ema1 == EMPTY_VALUE || ema3 == EMPTY_VALUE)
      return;

   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   double atr_points = atr / point;

   double spread_points = (double)SymbolInfoInteger(symbol, SYMBOL_SPREAD);


   double spread_points = (double)SymbolInfoInteger(symbol, SYMBOL_SPREAD);

   double spread_points = SymbolInfoInteger(symbol, SYMBOL_SPREAD);


   double range_points = (range_high - range_low) / point;
   double tf_multiplier = MathSqrt((double)PeriodSeconds(signal_tf) / 900.0);

   double dyn_min_range = MathMax(user_min_range_points, atr_points * def.min_range_atr_mult) * tf_multiplier;
   double dyn_max_range = (atr_points * def.max_range_atr_mult) * tf_multiplier;
   double dyn_buffer = MathMax(spread_points * def.spread_buffer_mult, atr_points * def.atr_buffer_mult) * tf_multiplier;
   double dyn_max_spread = MathMax(user_max_spread_points, atr_points * def.max_spread_atr_mult) * tf_multiplier;
   double ema_slope_points = MathAbs(ema1 - ema3) / point;
   double ema_slope_threshold = atr_points * ema_slope_atr_mult;

   bool compression_ok = (range_points <= dyn_max_range);
   bool min_range_ok = (range_points >= dyn_min_range);
   bool adx_ok = (adx <= def.adx_max);
   bool ema_ok = (!enable_ema_slope_filter) || (ema_slope_points <= ema_slope_threshold);
   bool spread_ok = (spread_points <= dyn_max_spread);
   bool session_ok = IsWithinSession(TimeCurrent());
   bool trades_ok = (CountDealsToday(symbol, state.magic) < max_trades_per_day);
   bool daily_loss_ok = !DailyLossLimitHit(symbol, state.magic);
   bool cooldown_ok = !CooldownActive(symbol, state.magic);
   bool has_setup = !(HasOpenPosition(symbol, state.magic) || HasPendingOrders(symbol, state.magic));

   bool filters_pass = compression_ok && min_range_ok && adx_ok && ema_ok && spread_ok && session_ok && trades_ok && daily_loss_ok && cooldown_ok && has_setup;

   string reason = "";
   if(!compression_ok) reason += "range>max;";
   if(!min_range_ok) reason += "range<min;";
   if(!adx_ok) reason += "adx;";
   if(!ema_ok) reason += "ema_slope;";
   if(!spread_ok) reason += "spread;";
   if(!session_ok) reason += "session;";
   if(!trades_ok) reason += "max_trades;";
   if(!daily_loss_ok) reason += "daily_loss;";
   if(!cooldown_ok) reason += "cooldown;";
   if(!has_setup) reason += "open_or_pending;";

   string decision = filters_pass ? "WOULD_PLACE_STRADDLE" : "WOULD_SKIP";
   if(sanity_mode)
     {
      LogDecision(symbol, CategoryToString(category), signal_tf, atr_points, spread_points, range_points,
                  dyn_min_range, dyn_max_range, dyn_buffer, dyn_max_spread, filters_pass, decision, reason);
      return;
     }

   if(!filters_pass)
     {
      Print("[FILTER] ", symbol, " blocked: ", reason);
      return;
     }

   double buffer_price = dyn_buffer * point;
   double buy_stop = range_high + buffer_price;
   double sell_stop = range_low - buffer_price;
   double sl_buy = range_low - buffer_price;
   double sl_sell = range_high + buffer_price;
   datetime expiry_time = current_bar + (expiry_bars * PeriodSeconds(signal_tf));

   double rr = def.rr_default;
   double tp_buy = buy_stop + (buy_stop - sl_buy) * rr;
   double tp_sell = sell_stop - (sl_sell - sell_stop) * rr;

   if(tp_mode == TP_FIXED_RR)
     {
      // already set
     }
   else if(tp_mode == TP_TRAIL_AFTER_1R)
     {
      tp_buy = 0.0;
      tp_sell = 0.0;
     }
   else if(tp_mode == TP_BREAKEVEN_1R)
     {
      tp_buy = 0.0;
      tp_sell = 0.0;
     }

   if(!PlacePendingOrders(symbol, state.magic, buy_stop, sell_stop, sl_buy, sl_sell, tp_buy, tp_sell, expiry_time))
     {
      Print("[ORDER] Failed placing straddle for ", symbol);
      return;
     }

   Print("[ORDER] Straddle placed on ", symbol, " range=", range_points, " atr=", atr_points, " category=", CategoryToString(category), " method=", method);
  }

void ManageOpenPositions()
  {
   if(tp_mode == TP_FIXED_RR)
      return;

   for(int i = 0; i < PositionsTotal(); i++)
     {
      if(PositionGetTicket(i) <= 0)
         continue;

      string symbol = PositionGetString(POSITION_SYMBOL);
      long magic = PositionGetInteger(POSITION_MAGIC);
      if(multi_symbol_mode)
        {
         bool match = false;
         for(int s = 0; s < ArraySize(states); s++)
           {
            if(states[s].symbol == symbol && states[s].magic == magic)
              {
               match = true;
               break;
              }
           }
         if(!match)
            continue;
        }

      double entry = PositionGetDouble(POSITION_PRICE_OPEN);
      double sl = PositionGetDouble(POSITION_SL);
      double volume = PositionGetDouble(POSITION_VOLUME);
      int type = (int)PositionGetInteger(POSITION_TYPE);
      double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
      int atr_handle = iATR(symbol, signal_tf, atr_period);
      if(atr_handle == INVALID_HANDLE)
         continue;
      double atr_value = GetIndicatorValue(atr_handle, 0, 1);
      IndicatorRelease(atr_handle);
      if(atr_value == EMPTY_VALUE)
         continue;

      double risk = MathAbs(entry - sl);
      double one_r = risk;
      double current_price = (type == POSITION_TYPE_BUY) ? SymbolInfoDouble(symbol, SYMBOL_BID) : SymbolInfoDouble(symbol, SYMBOL_ASK);
      double gain = (type == POSITION_TYPE_BUY) ? (current_price - entry) : (entry - current_price);

      if(tp_mode == TP_BREAKEVEN_1R && gain >= one_r)
        {
         double new_sl = (type == POSITION_TYPE_BUY) ? (entry + breakeven_lock_points * point) : (entry - breakeven_lock_points * point);
         if((type == POSITION_TYPE_BUY && new_sl > sl) || (type == POSITION_TYPE_SELL && new_sl < sl))
            trade.PositionModify(symbol, new_sl, 0.0);
        }

      if(tp_mode == TP_TRAIL_AFTER_1R && gain >= one_r)
        {
         double trail = atr_value * trail_atr_mult;
         double new_sl = (type == POSITION_TYPE_BUY) ? (current_price - trail) : (current_price + trail);
         if((type == POSITION_TYPE_BUY && new_sl > sl) || (type == POSITION_TYPE_SELL && new_sl < sl))
            trade.PositionModify(symbol, new_sl, 0.0);
        }

      if(enable_partial_close && gain >= one_r && volume > SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN))
        {
         double close_volume = volume * partial_close_fraction;
         trade.PositionClosePartial(symbol, close_volume);
        }
     }
  }

//+------------------------------------------------------------------+
//| Expert initialization                                            |
//+------------------------------------------------------------------+
int OnInit()
  {
   string symbol = _Symbol;
   trade.SetExpertMagicNumber(base_magic);

   if(!multi_symbol_mode)
     {
      ArrayResize(states, 1);
      states[0].symbol = symbol;
      states[0].last_bar_time = 0;
      states[0].magic = base_magic + HashSymbol(symbol);
     }
   else
     {
      string parts[];
      int count = StringSplit(symbols_list, ',', parts);
      if(count <= 0)
        {
         ArrayResize(states, 1);
         states[0].symbol = symbol;
         states[0].last_bar_time = 0;
         states[0].magic = base_magic + HashSymbol(symbol);
        }
      else
        {
         ArrayResize(states, count);
         for(int i = 0; i < count; i++)
           {
            string sym = Trim(parts[i]);
            states[i].symbol = sym;
            states[i].last_bar_time = 0;
            states[i].magic = base_magic + HashSymbol(sym);
           }
        }
     }

   Print("[INIT] AfriAdaptiveStraddleEA initialized. Sanity mode=", sanity_mode ? "ON" : "OFF");
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   Print("[DEINIT] AfriAdaptiveStraddleEA stopped. reason=", reason);
  }

void OnTick()
  {
   if(!sanity_mode)
      ManageOpenPositions();

   for(int i = 0; i < ArraySize(states); i++)
     {
      EvaluateSymbol(states[i]);

      if(!sanity_mode)
        {
         if(HasPendingOrders(states[i].symbol, states[i].magic))
           {

            double spread_points = (double)SymbolInfoInteger(states[i].symbol, SYMBOL_SPREAD);


            double spread_points = (double)SymbolInfoInteger(states[i].symbol, SYMBOL_SPREAD);

            double spread_points = SymbolInfoInteger(states[i].symbol, SYMBOL_SPREAD);


            int handle = iATR(states[i].symbol, signal_tf, atr_period);
            if(handle != INVALID_HANDLE)
              {
               double atr = GetIndicatorValue(handle, 0, 1);
               IndicatorRelease(handle);
               if(atr != EMPTY_VALUE)
                 {
                  string method = "";
                  SymbolCategory category = ClassifySymbol(states[i].symbol, method);
                  CategoryDefaults def;
                  ResolveCategoryParams(category, def);
                  double point = SymbolInfoDouble(states[i].symbol, SYMBOL_POINT);
                  double atr_points = atr / point;
                  double dyn_max_spread = MathMax(user_max_spread_points, atr_points * def.max_spread_atr_mult) * MathSqrt((double)PeriodSeconds(signal_tf) / 900.0);
                  if(spread_points > dyn_max_spread)
                     CancelPendingOrders(states[i].symbol, states[i].magic, "spread_spike");
                 }
              }
           }
        }
     }
  }

void OnTradeTransaction(const MqlTradeTransaction &trans, const MqlTradeRequest &request, const MqlTradeResult &result)
  {
   if(sanity_mode)
      return;

   if(trans.type != TRADE_TRANSACTION_DEAL_ADD)
      return;

   long entry = HistoryDealGetInteger(trans.deal, DEAL_ENTRY);
   if(entry != DEAL_ENTRY_IN)
      return;

   string symbol = trans.symbol;
   long magic = HistoryDealGetInteger(trans.deal, DEAL_MAGIC);
   ENUM_ORDER_TYPE order_type = (ENUM_ORDER_TYPE)HistoryDealGetInteger(trans.deal, DEAL_TYPE);

   if(order_type == ORDER_TYPE_BUY || order_type == ORDER_TYPE_SELL)
     {
      ENUM_ORDER_TYPE pending_type = (order_type == ORDER_TYPE_BUY) ? ORDER_TYPE_BUY_STOP : ORDER_TYPE_SELL_STOP;
      CancelOpposite(symbol, magic, pending_type);
     }
  }
//+------------------------------------------------------------------+
