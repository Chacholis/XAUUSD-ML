//+------------------------------------------------------------------+
//|                                     XAU_USD_ML_Trading_Robot.mq5 |
//|                                                           Author |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025"
#property link      ""
#property version   "1.05"
#property strict

// Include required libraries
#include <Trade\Trade.mqh>
#include <Arrays\ArrayObj.mqh>
#include <Math\Stat\Math.mqh>
#include <Math\Stat\Normal.mqh>

// Enumeration for trading direction
enum ENUM_TRADE_DIRECTION {
   TRADE_DIRECTION_BUY,       // Buy Only
   TRADE_DIRECTION_SELL,      // Sell Only
   TRADE_DIRECTION_BOTH       // Both Buy and Sell
};

// Enumeration for lot calculation mode
enum ENUM_LOT_MODE {
   LOT_MODE_FIXED,            // Fixed Lot
   LOT_MODE_RISK_PERCENT      // Risk Percent
};

// Enumeration for trailing stop mode
enum ENUM_TRAILING_MODE {
   TRAILING_MODE_FIXED,       // Fixed Trail
   TRAILING_MODE_ATR          // ATR Based
};

// Input Parameters - General Settings
input string              GeneralSettings = "==== General Settings ===="; // General Settings
input ENUM_TRADE_DIRECTION TradeDirection = TRADE_DIRECTION_BOTH;        // Trading Direction
input int                 MagicNumber = 7845621;                         // Magic Number
input double              MaxSpread = 5.0;                               // Maximum Spread in points
input int                 Slippage = 30;                                 // Slippage in points
input bool                UseNewsFilter = true;                          // Use News Filter

// Input for Visible EA Comment
input string              EAComment = "XAU/USD ML Trading Robot";        // Visible EA Comment

// Input Parameters - Trading Hours
input string              TimeSettings = "==== Trading Hours Settings ===="; // Trading Hours Settings
input bool                UseTradingHours = true;                         // Use Trading Hours Filter
input int                 StartHour = 8;                                 // Start Hour (Server Time)
input int                 StartMinute = 0;                               // Start Minute
input int                 EndHour = 20;                                  // End Hour (Server Time)
input int                 EndMinute = 0;                                 // End Minute

// Input Parameters - Money Management
input string              MoneySettings = "==== Money Management Settings ===="; // Money Management Settings
input ENUM_LOT_MODE       LotMode = LOT_MODE_RISK_PERCENT;               // Lot Calculation Mode
input double              FixedLot = 0.01;                               // Fixed Lot Size
input double              RiskPercent = 1.0;                             // Risk Percent per Trade
input double              TakeProfit = 100.0;                            // Take Profit in points
input double              StopLoss = 100.0;                              // Stop Loss in points

// Input Parameters - Trailing Stop Settings
input string              TrailingSettings = "==== Trailing Stop Settings ===="; // Trailing Stop Settings
input bool                UseTrailingStop = true;                         // Use Trailing Stop
input ENUM_TRAILING_MODE  TrailingMode = TRAILING_MODE_FIXED;            // Trailing Stop Mode
input double              TrailingStop = 50.0;                           // Trailing Stop in points
input double              TrailingStep = 10.0;                           // Trailing Step in points
input double              BreakEvenLevel = 30.0;                         // Break Even Level in points
input double              BreakEvenProfit = 5.0;                         // Break Even Profit in points
input double              TargetProfit = 50.0;                           // Target Profit to Lock (points)
input double              LockProfit = 20.0;                             // Profit to Lock (points)

// Input Parameters - Machine Learning Settings
input string              MLSettings = "==== Machine Learning Settings ===="; // ML Settings
input int                 MLPeriod = 20;                                 // ML Lookback Period
input double              MLThreshold = 0.6;                             // ML Signal Threshold (0.0-1.0)
input int                 MLFeatureCount = 6;                            // Updated feature count to include RSI

// Input Parameters - Stochastic Settings
input string              StochasticSettings = "==== Stochastic Settings ===="; // Stochastic Settings
input int                 KPeriod = 14;                                 // %K Period
input int                 DPeriod = 3;                                  // %D Period
input int                 Slowing = 3;                                  // Slowing

// Input Parameters - RSI Settings
input string              RsiSettings = "==== RSI Settings ====";        // RSI Settings
input int                 RsiPeriod = 14;                               // RSI Period

// Input Parameters - ATR SL Finder Settings
input string              AtrSlSettings = "==== ATR SL Finder Settings ===="; // ATR SL Finder Settings
input int                 AtrLength = 14;                                // ATR Length
input double              AtrMultiplier = 1.5;                           // ATR Multiplier

// Input Parameters - Kijun Sen Envelope Settings
input string              KijunSettings = "==== Kijun Sen Envelope Settings ===="; // Kijun Sen Settings
input int                 KijunSenPeriod = 100;                          // Kijun Sen Period
input int                 EnvelopeDeviation = 230;                       // Envelope Deviation
input int                 ShiftKijun = 0;                                // Shift

// Input Parameters - Order Block Settings
input string              OrderBlockSettings = "==== Order Block Settings ===="; // Order Block Settings
input int                 OBMode = 0;                                    // Order Block Mode (0-Default, 1-FVG)

// Input Parameters - SuperTrend Settings
input string              SuperTrendSettings = "==== SuperTrend Settings ===="; // SuperTrend Settings
input int                 SuperTrendPeriod = 10;                         // SuperTrend Period
input double              SuperTrendMultiplier = 3.0;                    // SuperTrend Multiplier

// Global variables
CTrade         trade;                                                    // Trading object
MqlDateTime    dt_struct;                                                // Date time structure
bool           inTradingHours;                                           // Trading hours flag
bool           newsEventActive;                                          // News event flag
datetime       lastTradeTime;                                            // Last trade time
datetime       lastNewsCheckTime;                                        // Last news check time
string         newsXML;                                                  // News XML content

// Indicator handles
int handle_stochastic;                                                   // Stochastic Oscillator
int handle_rsi;                                                          // RSI
int handle_atr_sl;                                                       // ATR SL Finder
int handle_kijun;                                                        // Kijun Sen Envelope
int handle_ob;                                                           // Order Block
int handle_supertrend;                                                   // SuperTrend
int handle_atr;                                                          // ATR indicator

// Indicator buffers
double k_buffer[];                                                       // Stochastic %K
double d_buffer[];                                                       // Stochastic %D
double rsi_buffer[];                                                     // RSI values
double asl_upper[];                                                      // ATR SL Upper
double asl_lower[];                                                      // ATR SL Lower
double kijun_top[];                                                      // Kijun Top
double kijun_middle[];                                                   // Kijun Middle
double kijun_bottom[];                                                   // Kijun Bottom
double ob_bull_upper[];                                                  // OB Bull Upper
double ob_bull_lower[];                                                  // OB Bull Lower
double ob_bear_upper[];                                                  // OB Bear Upper
double ob_bear_lower[];                                                  // OB Bear Lower
double supertrend[];                                                     // SuperTrend
double supertrend_color[];                                               // SuperTrend Color
double atr_buffer[];                                                     // ATR values

// Machine Learning buffers
double ml_features[];                                                    // ML features array
double ml_weights[];                                                     // ML weights array
double ml_signal[];                                                      // ML signal array (0.0-1.0)

bool highImpactNewsFilterActive = false;                                 // High-impact news filter flag

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {
   // Initialize trading object
   trade.SetExpertMagicNumber(MagicNumber);
   trade.SetDeviationInPoints(Slippage);
   trade.SetTypeFilling(ORDER_FILLING_FOK);
   trade.SetAsyncMode(false);
   
   // Display EA comment
   Comment(EAComment);
   
   // Check symbol
   if(_Symbol != "XAUUSD") {
      Print("This EA is designed for XAUUSD only!");
      return INIT_PARAMETERS_INCORRECT;
   }
   
   // Check timeframe
   if(_Period != PERIOD_H1) {
      Print("This EA is designed to work on H1 timeframe only!");
      return INIT_PARAMETERS_INCORRECT;
   }
   
   // Initialize variables
   lastTradeTime = 0;
   lastNewsCheckTime = 0;
   newsEventActive = false;
   
   // Initialize ML weights (these would normally be trained separately)
   ArrayResize(ml_weights, MLFeatureCount);
   ml_weights[0] = 0.7;    // Example weight for Stochastic confirmation
   ml_weights[1] = 0.8;    // Example weight for SuperTrend direction
   ml_weights[2] = 0.6;    // Example weight for Kijun position
   ml_weights[3] = 0.5;    // Example weight for Order Block presence
   ml_weights[4] = 0.6;    // Example weight for ATR SL Finder position
   ml_weights[5] = 0.7;    // Example weight for RSI confirmation
   
   // Initialize indicator handles
   handle_stochastic = iStochastic(_Symbol, _Period, KPeriod, DPeriod, Slowing, MODE_SMA, STO_LOWHIGH);
   handle_rsi = iRSI(_Symbol, _Period, RsiPeriod, PRICE_CLOSE);
   handle_atr_sl = iCustom(_Symbol, _Period, "AtrSlFinder", AtrLength, AtrMultiplier);
   handle_kijun = iCustom(_Symbol, _Period, "KijunSenEnvelope", KijunSenPeriod, EnvelopeDeviation, ShiftKijun);
   handle_ob = iCustom(_Symbol, _Period, "OrderBlock", OBMode);
   handle_supertrend = iCustom(_Symbol, _Period, "SuperTrend", SuperTrendPeriod, SuperTrendMultiplier, true);
   handle_atr = iATR(_Symbol, _Period, AtrLength);
   
   // Check indicator handles
   if(handle_stochastic == INVALID_HANDLE) {
      Print("Cannot load Stochastic indicator.");
      return INIT_FAILED;
   }
   if(handle_rsi == INVALID_HANDLE) {
      Print("Cannot load RSI indicator.");
      return INIT_FAILED;
   }
   if(handle_atr_sl == INVALID_HANDLE || handle_kijun == INVALID_HANDLE || handle_ob == INVALID_HANDLE || 
      handle_supertrend == INVALID_HANDLE || handle_atr == INVALID_HANDLE) {
      Print("Error creating indicator handles for other indicators.");
      return INIT_FAILED;
   }
   
   // Initialize ML features array
   ArrayResize(ml_features, MLFeatureCount);
   ArrayResize(ml_signal, MLPeriod);
   
   Print("XAU/USD ML Trading Robot initialized successfully");
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
   // Release indicator handles
   if(handle_stochastic != INVALID_HANDLE) IndicatorRelease(handle_stochastic);
   if(handle_rsi != INVALID_HANDLE) IndicatorRelease(handle_rsi);
   if(handle_atr_sl != INVALID_HANDLE) IndicatorRelease(handle_atr_sl);
   if(handle_kijun != INVALID_HANDLE) IndicatorRelease(handle_kijun);
   if(handle_ob != INVALID_HANDLE) IndicatorRelease(handle_ob);
   if(handle_supertrend != INVALID_HANDLE) IndicatorRelease(handle_supertrend);
   if(handle_atr != INVALID_HANDLE) IndicatorRelease(handle_atr);
   
   // Clean up
   ArrayFree(ml_features);
   ArrayFree(ml_weights);
   ArrayFree(ml_signal);
   
   Print("XAU/USD ML Trading Robot deinitialized");
}