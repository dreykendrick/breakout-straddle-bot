//+------------------------------------------------------------------+
//| OCOTestEA.mq5                                                    |
//| Places two pending orders and cancels opposite on fill           |
//+------------------------------------------------------------------+
#property strict

#include <Trade/Trade.mqh>

input double distance_points = 100;
input int magic = 20251101;

CTrade trade;

void CancelOpposite(const string symbol, ENUM_ORDER_TYPE filled_type)
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
            trade.OrderDelete(OrderGetTicket(i));
            Print("[TEST] Cancelled opposite pending order.");
           }
        }
     }
  }

int OnInit()
  {
   trade.SetExpertMagicNumber(magic);
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   double buy_stop = ask + (distance_points * point);
   double sell_stop = bid - (distance_points * point);
   trade.BuyStop(0.1, buy_stop, _Symbol, 0, 0, ORDER_TIME_GTC, 0, "OCO buy");
   trade.SellStop(0.1, sell_stop, _Symbol, 0, 0, ORDER_TIME_GTC, 0, "OCO sell");

   Print("[TEST] OCO pending orders placed.");
   return INIT_SUCCEEDED;
  }

void OnTradeTransaction(const MqlTradeTransaction &trans, const MqlTradeRequest &request, const MqlTradeResult &result)
  {
   if(trans.type != TRADE_TRANSACTION_DEAL_ADD)
      return;

   long entry = HistoryDealGetInteger(trans.deal, DEAL_ENTRY);
   if(entry != DEAL_ENTRY_IN)
      return;

   ENUM_ORDER_TYPE order_type = (ENUM_ORDER_TYPE)HistoryDealGetInteger(trans.deal, DEAL_TYPE);
   if(order_type == ORDER_TYPE_BUY)
      CancelOpposite(_Symbol, ORDER_TYPE_BUY_STOP);
   else if(order_type == ORDER_TYPE_SELL)
      CancelOpposite(_Symbol, ORDER_TYPE_SELL_STOP);
  }
