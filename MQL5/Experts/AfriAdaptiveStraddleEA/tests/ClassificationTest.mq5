//+------------------------------------------------------------------+
//| ClassificationTest.mq5                                           |
//| Prints symbol category and detection method                      |
//+------------------------------------------------------------------+
#property script_show_inputs
#property strict

input string test_symbol = "";

enum SymbolCategory
  {
   CATEGORY_FOREX = 0,
   CATEGORY_METAL = 1,
   CATEGORY_INDEX = 2,
   CATEGORY_CRYPTO = 3,
   CATEGORY_OTHER = 4
  };

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

SymbolCategory ClassifySymbol(const string symbol, string &method)
  {
   string base = SymbolInfoString(symbol, SYMBOL_CURRENCY_BASE);
   string profit = SymbolInfoString(symbol, SYMBOL_CURRENCY_PROFIT);
   string path = SymbolInfoString(symbol, SYMBOL_PATH);
   long calc_mode = SymbolInfoInteger(symbol, SYMBOL_TRADE_CALC_MODE);

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

void OnStart()
  {
   string symbol = test_symbol == "" ? _Symbol : test_symbol;
   string method = "";
   SymbolCategory category = ClassifySymbol(symbol, method);
   Print("[TEST] symbol=", symbol, " category=", CategoryToString(category), " method=", method);
  }
