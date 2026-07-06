#property copyright "Antigravity"
#property link      "https://google.com"
#property version   "1.60"
#property description "Interactive MT5 Position Sizer with draggable chart lines."
#property description "Supports Market, Limit, and Stop orders with dynamic Risk/Reward."
#property description "Includes a toggle button to show or hide the SL/TP lines instantly."
#property strict

#include <Trade\Trade.mqh>

//--- UI Colors
#define COLOR_BG C'20,24,33'          // Darker rich charcoal background
#define COLOR_BORDER C'38,45,59'      // Slate-blue border
#define COLOR_TEXT C'230,235,245'     // Bright white/gray text
#define COLOR_LABEL C'150,155,168'    // Soft gray for labels
#define COLOR_BUY C'46,204,113'       // Emerald green for Buy
#define COLOR_SELL C'231,76,60'       // Crimson red for Sell
#define COLOR_BTN_BG C'30,35,46'      // Button background
#define COLOR_EXECUTE C'41,128,185'    // Soft electric blue
#define COLOR_EXECUTE_TEXT C'255,255,255'
#define COLOR_INVALID C'50,30,30'      // Dark muted red for errors

//--- UI Coordinates
#define PANEL_X 15
#define PANEL_Y 35
#define PANEL_WIDTH 240
#define PANEL_HEIGHT 450

//--- Risk Mode Enum
enum ENUM_RISK_MODE {
   RISK_PERCENT = 0, // Percentage Risk
   RISK_CASH = 1     // Fixed Cash Risk
};

//--- UI Order Type Enum
enum ENUM_UI_ORDER_TYPE {
   ORDER_TYPE_MARKET = 0, // Market Position
   ORDER_TYPE_LIMIT = 1,  // Limit Position
   ORDER_TYPE_STOP = 2    // Stop Position
};

//--- Direction Enum
enum ENUM_DIR {
   DIR_BUY = 0,
   DIR_SELL = 1
};

//--- Inputs
input group "=== General Settings ==="
input ulong MagicNumberInput = 123456;               // Magic Number
input ENUM_RISK_MODE RiskModeInput = RISK_PERCENT;   // Default Risk Mode
input double RiskValueInput = 1.0;                  // Default Risk Value (e.g. 1.0% or 100.0 Cash)
input int SLPointsInput = 200;                      // Default SL (in Points)
input int TPPointsInput = 400;                      // Default TP (in Points)
input int SlippageInput = 3;                        // Slippage (in Points)

//--- Global Variables
ulong gMagicNumber;
double gRiskValue;
bool gRiskInPct;
int gDefaultSLPoints;
int gDefaultTPPoints;
int gSlippage;

ENUM_DIR gDirection = DIR_BUY;
ENUM_UI_ORDER_TYPE gOrderType = ORDER_TYPE_MARKET;

double gEntryPrice = 0;
double gSLPrice = 0;
double gTPPrice = 0;

bool gIsMinimized = false;      // Minimized panel state
bool gIsEditingRisk = false;    // Editing state to prevent focus loss
bool gMouseOverPanel = false;   // Mouse hovering state to block tick redraws
bool gLinesVisible = true;      // Option to show or hide the visual lines

//--- Forward Declarations
void InitInputs();
void InitPrices();
void CreateGUI();
void DeleteGUI();
void UpdateVisibility();
void UpdateLinesVisibility();
void Recalculate();
double CalculateLotSize(double entryPrice, double slPrice, double riskAmount);
bool ValidateOrder(string &outErrorMsg);
void ToggleDirection();
void ToggleOrderType();
void ToggleRiskMode();
void ExecuteTrade();
string GetOrderTypeName();
double NormalizePrice(double price);
bool CreatePanelBg(string name, int x, int y, int w, int h, color bgClr, color borderClr);
bool CreateLabel(string name, string text, int x, int y, color textColor, int fontSize = 9);
bool CreateButton(string name, string text, int x, int y, int width, int height, color backColor, color textColor);
bool CreateEdit(string name, string text, int x, int y, int width, int height, color backColor, color textColor);
bool CreateDivider(string name, int x, int y, int w);
bool CreateHLine(string name, double price, color clr, int style, int width);

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   // Enable mouse events to capture coordinates and hover state
   ChartSetInteger(0, CHART_EVENT_MOUSE_MOVE, true);
   
   // Sync settings and UI states
   InitInputs();
   
   // Setup prices
   InitPrices();
   
   // Create UI panel
   CreateGUI();
   
   // Calculate & update panel
   Recalculate();
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   ObjectsDeleteAll(0, "PS_");
   ChartRedraw(0);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   // Do not recalculate/redraw while user is typing or mouse is hovering panel!
   if(gIsEditingRisk || gMouseOverPanel) return;

   if(gOrderType == ORDER_TYPE_MARKET)
   {
      double currentPrice = (gDirection == DIR_BUY) ? SymbolInfoDouble(Symbol(), SYMBOL_ASK) : SymbolInfoDouble(Symbol(), SYMBOL_BID);
      
      // Update only on actual price change
      if(currentPrice != gEntryPrice)
      {
         gEntryPrice = currentPrice;
         if(ObjectFind(0, "PS_EntryLine") >= 0)
         {
            ObjectSetDouble(0, "PS_EntryLine", OBJPROP_PRICE, gEntryPrice);
         }
         Recalculate();
      }
   }
}

//+------------------------------------------------------------------+
//| ChartEvent function                                              |
//+------------------------------------------------------------------+
void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
{
   //--- Handle mouse hover to pause tick redraw focus interruption
   if(id == CHARTEVENT_MOUSE_MOVE)
   {
      int mouseX = (int)lparam;
      int mouseY = (int)dparam;
      
      if(mouseX >= PANEL_X && mouseX <= PANEL_X + PANEL_WIDTH &&
         mouseY >= PANEL_Y && mouseY <= PANEL_Y + (gIsMinimized ? 35 : PANEL_HEIGHT))
      {
         gMouseOverPanel = true;
      }
      else
      {
         gMouseOverPanel = false;
      }
   }

   //--- Handle line drag events
   else if(id == CHARTEVENT_OBJECT_DRAG)
   {
      // Block processing drag prices if lines are supposedly hidden
      if(!gLinesVisible) return;

      if(sparam == "PS_EntryLine" && gOrderType != ORDER_TYPE_MARKET)
      {
         double price = ObjectGetDouble(0, "PS_EntryLine", OBJPROP_PRICE);
         gEntryPrice = NormalizePrice(price);
         ObjectSetDouble(0, "PS_EntryLine", OBJPROP_PRICE, gEntryPrice);
         Recalculate();
      }
      else if(sparam == "PS_SLLine")
      {
         double price = ObjectGetDouble(0, "PS_SLLine", OBJPROP_PRICE);
         gSLPrice = NormalizePrice(price);
         ObjectSetDouble(0, "PS_SLLine", OBJPROP_PRICE, gSLPrice);
         Recalculate();
      }
      else if(sparam == "PS_TPLine")
      {
         double price = ObjectGetDouble(0, "PS_TPLine", OBJPROP_PRICE);
         gTPPrice = NormalizePrice(price);
         ObjectSetDouble(0, "PS_TPLine", OBJPROP_PRICE, gTPPrice);
         Recalculate();
      }
   }
   
   //--- Handle button click events
   else if(id == CHARTEVENT_OBJECT_CLICK)
   {
      if(sparam == "PS_BtnMin")
      {
         gIsMinimized = !gIsMinimized;
         UpdateVisibility();
      }
      else if(sparam == "PS_BtnDir")
      {
         ToggleDirection();
      }
      else if(sparam == "PS_BtnType")
      {
         ToggleOrderType();
      }
      else if(sparam == "PS_BtnRiskMode")
      {
         ToggleRiskMode();
      }
      else if(sparam == "PS_BtnLinesToggle")
      {
         gLinesVisible = !gLinesVisible;
         
         if(ObjectFind(0, "PS_BtnLinesToggle") >= 0)
         {
            ObjectSetString(0, "PS_BtnLinesToggle", OBJPROP_TEXT, gLinesVisible ? "VISIBLE" : "HIDDEN");
            ObjectSetInteger(0, "PS_BtnLinesToggle", OBJPROP_BGCOLOR, gLinesVisible ? COLOR_BUY : COLOR_BTN_BG);
         }
         
         UpdateLinesVisibility();
      }
      else if(sparam == "PS_BtnExecute")
      {
         ExecuteTrade();
      }
      else if(sparam == "PS_EdtRiskVal")
      {
         gIsEditingRisk = true;
      }
   }
   
   //--- Handle input/edit events (Press Enter or click away)
   else if(id == CHARTEVENT_OBJECT_ENDEDIT)
   {
      if(sparam == "PS_EdtRiskVal")
      {
         gIsEditingRisk = false;
         string text = ObjectGetString(0, "PS_EdtRiskVal", OBJPROP_TEXT);
         double val = StringToDouble(text);
         if(val < 0) val = 0;
         gRiskValue = val;
         
         ObjectSetString(0, "PS_EdtRiskVal", OBJPROP_TEXT, DoubleToString(gRiskValue, 2));
         Recalculate();
      }
   }
}

//+------------------------------------------------------------------+
//| Initialize Inputs (Restores values on timeframe changes)        |
//+------------------------------------------------------------------+
void InitInputs()
{
   gMagicNumber = MagicNumberInput;
   gSlippage = SlippageInput;
   gDefaultSLPoints = SLPointsInput;
   gDefaultTPPoints = TPPointsInput;

   bool editExists = (ObjectFind(0, "PS_EdtRiskVal") >= 0);
   bool modeBtnExists = (ObjectFind(0, "PS_BtnRiskMode") >= 0);
   bool minBtnExists = (ObjectFind(0, "PS_BtnMin") >= 0);
   bool linesBtnExists = (ObjectFind(0, "PS_BtnLinesToggle") >= 0);
   
   // Preserve minimize state
   if(minBtnExists)
   {
      string minText = ObjectGetString(0, "PS_BtnMin", OBJPROP_TEXT);
      gIsMinimized = (minText == "[+]");
   }
   else
   {
      gIsMinimized = false;
   }

   // Preserve Lines Visibility state
   if(linesBtnExists)
   {
      string linesText = ObjectGetString(0, "PS_BtnLinesToggle", OBJPROP_TEXT);
      gLinesVisible = (linesText == "VISIBLE");
   }
   else
   {
      gLinesVisible = true;
   }

   // Preserve inputs
   if(editExists && modeBtnExists)
   {
      string text = ObjectGetString(0, "PS_EdtRiskVal", OBJPROP_TEXT);
      double val = StringToDouble(text);
      if(val > 0) gRiskValue = val;
      
      string modeText = ObjectGetString(0, "PS_BtnRiskMode", OBJPROP_TEXT);
      if(StringFind(modeText, "%") >= 0)
      {
         gRiskInPct = true;
      }
      else
      {
         gRiskInPct = false;
      }
   }
   else
   {
      gRiskValue = RiskValueInput;
      gRiskInPct = (RiskModeInput == RISK_PERCENT);
   }
}

//+------------------------------------------------------------------+
//| Initialize Prices (Handles persistence on timeframe changes)    |
//+------------------------------------------------------------------+
void InitPrices()
{
   double currentAsk = SymbolInfoDouble(Symbol(), SYMBOL_ASK);
   double currentBid = SymbolInfoDouble(Symbol(), SYMBOL_BID);
   double currentPrice = (gDirection == DIR_BUY) ? currentAsk : currentBid;
   
   bool entryExists = (ObjectFind(0, "PS_EntryLine") >= 0);
   bool slExists = (ObjectFind(0, "PS_SLLine") >= 0);
   bool tpExists = (ObjectFind(0, "PS_TPLine") >= 0);
   
   if(entryExists && slExists && tpExists)
   {
      gEntryPrice = ObjectGetDouble(0, "PS_EntryLine", OBJPROP_PRICE);
      gSLPrice = ObjectGetDouble(0, "PS_SLLine", OBJPROP_PRICE);
      gTPPrice = ObjectGetDouble(0, "PS_TPLine", OBJPROP_PRICE);
      
      if(gOrderType == ORDER_TYPE_MARKET)
      {
         gEntryPrice = currentPrice;
      }
   }
   else
   {
      gEntryPrice = currentPrice;
      double slDist = gDefaultSLPoints * Point();
      double tpDist = gDefaultTPPoints * Point();
      
      if(gDirection == DIR_BUY)
      {
         gSLPrice = gEntryPrice - slDist;
         gTPPrice = gEntryPrice + tpDist;
      }
      else
      {
         gSLPrice = gEntryPrice + slDist;
         gTPPrice = gEntryPrice - tpDist;
      }
   }
   
   gEntryPrice = NormalizePrice(gEntryPrice);
   gSLPrice = NormalizePrice(gSLPrice);
   gTPPrice = NormalizePrice(gTPPrice);
   
   int entryStyle = (gOrderType == ORDER_TYPE_MARKET) ? STYLE_DOT : STYLE_SOLID;
   color entryColor = (gOrderType == ORDER_TYPE_MARKET) ? COLOR_LABEL : COLOR_EXECUTE;
   bool entrySelectable = (gOrderType != ORDER_TYPE_MARKET);
   
   if(!entryExists) CreateHLine("PS_EntryLine", gEntryPrice, entryColor, entryStyle, 1);
   else
   {
      ObjectSetInteger(0, "PS_EntryLine", OBJPROP_COLOR, entryColor);
      ObjectSetInteger(0, "PS_EntryLine", OBJPROP_STYLE, entryStyle);
      ObjectSetDouble(0, "PS_EntryLine", OBJPROP_PRICE, gEntryPrice);
   }
   ObjectSetInteger(0, "PS_EntryLine", OBJPROP_SELECTABLE, entrySelectable);
   ObjectSetInteger(0, "PS_EntryLine", OBJPROP_SELECTED, false);
   
   if(!slExists) CreateHLine("PS_SLLine", gSLPrice, COLOR_SELL, STYLE_SOLID, 2);
   else ObjectSetDouble(0, "PS_SLLine", OBJPROP_PRICE, gSLPrice);
   
   if(!tpExists) CreateHLine("PS_TPLine", gTPPrice, COLOR_BUY, STYLE_SOLID, 2);
   else ObjectSetDouble(0, "PS_TPLine", OBJPROP_PRICE, gTPPrice);
}

//+------------------------------------------------------------------+
//| Create UI Control Panel                                          |
//+------------------------------------------------------------------+
void CreateGUI()
{
   DeleteGUI();

   // 1. Background Panel (Z-order 0)
   CreatePanelBg("PS_Bg", PANEL_X, PANEL_Y, PANEL_WIDTH, PANEL_HEIGHT, COLOR_BG, COLOR_BORDER);
   
   // 2. Header Accent Bar (Z-order 1)
   color headerBg = (gDirection == DIR_BUY) ? COLOR_BUY : COLOR_SELL;
   CreatePanelBg("PS_HeaderBg", PANEL_X, PANEL_Y, PANEL_WIDTH, 35, headerBg, headerBg);
   ObjectSetInteger(0, "PS_HeaderBg", OBJPROP_ZORDER, 1);
   
   // 3. Header Title Label (Z-order 2)
   string titleText = (gDirection == DIR_BUY) ? "▲ BUY POSITION SIZER" : "▼ SELL POSITION SIZER";
   CreateLabel("PS_Title", titleText, PANEL_X + 15, PANEL_Y + 10, COLOR_EXECUTE_TEXT, 10);
   ObjectSetInteger(0, "PS_Title", OBJPROP_FONTSIZE, 10);
   
   // 4. Minimize/Maximize Button (Z-order 3)
   string minText = gIsMinimized ? "[+]" : "[-]";
   CreateButton("PS_BtnMin", minText, PANEL_X + PANEL_WIDTH - 30, PANEL_Y + 8, 20, 18, COLOR_BTN_BG, COLOR_TEXT);
   ObjectSetInteger(0, "PS_BtnMin", OBJPROP_FONTSIZE, 8);
   
   // 5. Divider 1 (below header) (Z-order 1)
   CreateDivider("PS_Div1", PANEL_X + 10, PANEL_Y + 45, PANEL_WIDTH - 20);
   
   // 6. Direction Row (Y = PANEL_Y + 55) (Z-order 3)
   CreateLabel("PS_LblDir", "Order Direction:", PANEL_X + 15, PANEL_Y + 58, COLOR_LABEL, 9);
   string dirText = (gDirection == DIR_BUY) ? "▲ BUY" : "▼ SELL";
   CreateButton("PS_BtnDir", dirText, PANEL_X + 120, PANEL_Y + 55, 105, 24, headerBg, COLOR_EXECUTE_TEXT);
   
   // 7. Order Type Row (Y = PANEL_Y + 85) (Z-order 3)
   CreateLabel("PS_LblType", "Execution Type:", PANEL_X + 15, PANEL_Y + 88, COLOR_LABEL, 9);
   CreateButton("PS_BtnType", GetOrderTypeName(), PANEL_X + 120, PANEL_Y + 85, 105, 24, COLOR_BTN_BG, COLOR_TEXT);
   
   // 8. Risk Mode Row (Y = PANEL_Y + 115) (Z-order 3)
   CreateLabel("PS_LblRiskMode", "Risk Mode:", PANEL_X + 15, PANEL_Y + 118, COLOR_LABEL, 9);
   string riskModeText = gRiskInPct ? "% BALANCE" : "$ CASH VALUE";
   CreateButton("PS_BtnRiskMode", riskModeText, PANEL_X + 120, PANEL_Y + 115, 105, 24, COLOR_BTN_BG, COLOR_TEXT);
   
   // 9. Risk Value Row (Y = PANEL_Y + 145) (Z-order 3)
   string riskValLbl = gRiskInPct ? "Risk Value (%):" : "Risk Value ($):";
   CreateLabel("PS_LblRiskVal", riskValLbl, PANEL_X + 15, PANEL_Y + 148, COLOR_LABEL, 9);
   CreateEdit("PS_EdtRiskVal", DoubleToString(gRiskValue, 2), PANEL_X + 120, PANEL_Y + 145, 105, 24, COLOR_BTN_BG, COLOR_TEXT);
   
   // 10. Lines Visibility Toggle Row (Y = PANEL_Y + 175) (Z-order 3)
   CreateLabel("PS_LblLinesToggle", "Chart Lines:", PANEL_X + 15, PANEL_Y + 178, COLOR_LABEL, 9);
   string linesToggleText = gLinesVisible ? "VISIBLE" : "HIDDEN";
   color linesToggleBg = gLinesVisible ? COLOR_BUY : COLOR_BTN_BG;
   CreateButton("PS_BtnLinesToggle", linesToggleText, PANEL_X + 120, PANEL_Y + 175, 105, 24, linesToggleBg, COLOR_TEXT);
   
   // 11. Divider 2 (below inputs) (Z-order 1)
   CreateDivider("PS_Div2", PANEL_X + 10, PANEL_Y + 210, PANEL_WIDTH - 20);
   
   // 12. Metrics Rows (Y = PANEL_Y + 220 to PANEL_Y + 280) (Z-order 2)
   CreateLabel("PS_LblBalance", "Account Balance: " + DoubleToString(AccountInfoDouble(ACCOUNT_BALANCE), 2) + " " + AccountInfoString(ACCOUNT_CURRENCY), PANEL_X + 15, PANEL_Y + 220, COLOR_LABEL, 9);
   CreateLabel("PS_LblRiskCash", "Cash at Risk: --", PANEL_X + 15, PANEL_Y + 240, COLOR_TEXT, 9);
   CreateLabel("PS_LblSldist", "SL Distance: --", PANEL_X + 15, PANEL_Y + 260, COLOR_LABEL, 9);
   CreateLabel("PS_LblTPdist", "TP Distance: --", PANEL_X + 15, PANEL_Y + 280, COLOR_LABEL, 9);
   
   // 13. Divider 3 (below metrics) (Z-order 1)
   CreateDivider("PS_Div3", PANEL_X + 10, PANEL_Y + 310, PANEL_WIDTH - 20);
   
   // 14. Lots Readout Box (Z-order 1 / 2)
   CreatePanelBg("PS_LotsBg", PANEL_X + 15, PANEL_Y + 320, PANEL_WIDTH - 30, 42, C'14,17,23', COLOR_BORDER);
   ObjectSetInteger(0, "PS_LotsBg", OBJPROP_ZORDER, 1);
   CreateLabel("PS_LotsTitle", "CALCULATED LOTS", PANEL_X + 25, PANEL_Y + 323, COLOR_LABEL, 7);
   CreateLabel("PS_LblLots", "LOT SIZE: --", PANEL_X + 25, PANEL_Y + 333, COLOR_TEXT, 11);
   ObjectSetInteger(0, "PS_LblLots", OBJPROP_FONTSIZE, 11);
   
   // 15. Status line (Z-order 2)
   CreateLabel("PS_LblStatus", "● Setup is valid", PANEL_X + 15, PANEL_Y + 370, COLOR_BUY, 8);
   
   // 16. Place Order Button (Z-order 3)
   CreateButton("PS_BtnExecute", "PLACE BUY ORDER", PANEL_X + 15, PANEL_Y + 390, PANEL_WIDTH - 30, 40, headerBg, COLOR_EXECUTE_TEXT);
   ObjectSetInteger(0, "PS_BtnExecute", OBJPROP_FONTSIZE, 10);
   
   // Set visibility and shift elements based on minimized state
   UpdateVisibility();
}

//+------------------------------------------------------------------+
//| Delete only the GUI objects, preserving the chart lines          |
//+------------------------------------------------------------------+
void DeleteGUI()
{
   ObjectDelete(0, "PS_Bg");
   ObjectDelete(0, "PS_HeaderBg");
   ObjectDelete(0, "PS_Title");
   ObjectDelete(0, "PS_BtnMin");
   ObjectDelete(0, "PS_LblDir");
   ObjectDelete(0, "PS_BtnDir");
   ObjectDelete(0, "PS_LblType");
   ObjectDelete(0, "PS_BtnType");
   ObjectDelete(0, "PS_LblRiskMode");
   ObjectDelete(0, "PS_BtnRiskMode");
   ObjectDelete(0, "PS_LblRiskVal");
   ObjectDelete(0, "PS_EdtRiskVal");
   ObjectDelete(0, "PS_LblLinesToggle");
   ObjectDelete(0, "PS_BtnLinesToggle");
   ObjectDelete(0, "PS_LblBalance");
   ObjectDelete(0, "PS_LblRiskCash");
   ObjectDelete(0, "PS_LblSldist");
   ObjectDelete(0, "PS_LblTPdist");
   
   ObjectDelete(0, "PS_LotsBg");
   ObjectDelete(0, "PS_LotsTitle");
   ObjectDelete(0, "PS_LblLots");
   ObjectDelete(0, "PS_LblStatus");
   ObjectDelete(0, "PS_BtnExecute");
   ObjectDelete(0, "PS_Div1");
   ObjectDelete(0, "PS_Div2");
   ObjectDelete(0, "PS_Div3");
}

//+------------------------------------------------------------------+
//| Update Visibility based on Minimize State                        |
//+------------------------------------------------------------------+
void UpdateVisibility()
{
   long visibility = gIsMinimized ? OBJ_NO_PERIODS : OBJ_ALL_PERIODS;
   
   if(ObjectFind(0, "PS_Bg") >= 0)
   {
      ObjectSetInteger(0, "PS_Bg", OBJPROP_YSIZE, gIsMinimized ? 35 : PANEL_HEIGHT);
   }
   
   if(ObjectFind(0, "PS_BtnMin") >= 0)
   {
      ObjectSetString(0, "PS_BtnMin", OBJPROP_TEXT, gIsMinimized ? "[+]" : "[-]");
   }
   
   // Base UI components visibility
   ObjectSetInteger(0, "PS_Div1", OBJPROP_TIMEFRAMES, visibility);
   ObjectSetInteger(0, "PS_LblDir", OBJPROP_TIMEFRAMES, visibility);
   ObjectSetInteger(0, "PS_BtnDir", OBJPROP_TIMEFRAMES, visibility);
   ObjectSetInteger(0, "PS_LblType", OBJPROP_TIMEFRAMES, visibility);
   ObjectSetInteger(0, "PS_BtnType", OBJPROP_TIMEFRAMES, visibility);
   ObjectSetInteger(0, "PS_LblRiskMode", OBJPROP_TIMEFRAMES, visibility);
   ObjectSetInteger(0, "PS_BtnRiskMode", OBJPROP_TIMEFRAMES, visibility);
   ObjectSetInteger(0, "PS_LblRiskVal", OBJPROP_TIMEFRAMES, visibility);
   ObjectSetInteger(0, "PS_EdtRiskVal", OBJPROP_TIMEFRAMES, visibility);
   ObjectSetInteger(0, "PS_LblLinesToggle", OBJPROP_TIMEFRAMES, visibility);
   ObjectSetInteger(0, "PS_BtnLinesToggle", OBJPROP_TIMEFRAMES, visibility);
   ObjectSetInteger(0, "PS_Div2", OBJPROP_TIMEFRAMES, visibility);
   ObjectSetInteger(0, "PS_LblBalance", OBJPROP_TIMEFRAMES, visibility);
   ObjectSetInteger(0, "PS_LblRiskCash", OBJPROP_TIMEFRAMES, visibility);
   ObjectSetInteger(0, "PS_LblSldist", OBJPROP_TIMEFRAMES, visibility);
   ObjectSetInteger(0, "PS_LblTPdist", OBJPROP_TIMEFRAMES, visibility);
   ObjectSetInteger(0, "PS_Div3", OBJPROP_TIMEFRAMES, visibility);
   
   // Lots readout and execution button positioning
   int lotsY = PANEL_Y + 320;
   int statusY = PANEL_Y + 370;
   int executeY = PANEL_Y + 390;
   
   if(ObjectFind(0, "PS_LotsBg") >= 0) {
      ObjectSetInteger(0, "PS_LotsBg", OBJPROP_YDISTANCE, lotsY);
      ObjectSetInteger(0, "PS_LotsBg", OBJPROP_TIMEFRAMES, visibility);
   }
   if(ObjectFind(0, "PS_LotsTitle") >= 0) {
      ObjectSetInteger(0, "PS_LotsTitle", OBJPROP_YDISTANCE, lotsY + 3);
      ObjectSetInteger(0, "PS_LotsTitle", OBJPROP_TIMEFRAMES, visibility);
   }
   if(ObjectFind(0, "PS_LblLots") >= 0) {
      ObjectSetInteger(0, "PS_LblLots", OBJPROP_YDISTANCE, lotsY + 13);
      ObjectSetInteger(0, "PS_LblLots", OBJPROP_TIMEFRAMES, visibility);
   }
   if(ObjectFind(0, "PS_LblStatus") >= 0) {
      ObjectSetInteger(0, "PS_LblStatus", OBJPROP_YDISTANCE, statusY);
      ObjectSetInteger(0, "PS_LblStatus", OBJPROP_TIMEFRAMES, visibility);
   }
   if(ObjectFind(0, "PS_BtnExecute") >= 0) {
      ObjectSetInteger(0, "PS_BtnExecute", OBJPROP_YDISTANCE, executeY);
      ObjectSetInteger(0, "PS_BtnExecute", OBJPROP_TIMEFRAMES, visibility);
   }
   
   // Sync lines visibility
   UpdateLinesVisibility();
   
   ChartRedraw(0);
}

//+------------------------------------------------------------------+
//| Update Lines Visibility on the Chart                             |
//+------------------------------------------------------------------+
void UpdateLinesVisibility()
{
   long visibility = gLinesVisible ? OBJ_ALL_PERIODS : OBJ_NO_PERIODS;
   
   if(ObjectFind(0, "PS_EntryLine") >= 0)
   {
      ObjectSetInteger(0, "PS_EntryLine", OBJPROP_TIMEFRAMES, visibility);
   }
   if(ObjectFind(0, "PS_SLLine") >= 0)
   {
      ObjectSetInteger(0, "PS_SLLine", OBJPROP_TIMEFRAMES, visibility);
   }
   if(ObjectFind(0, "PS_TPLine") >= 0)
   {
      ObjectSetInteger(0, "PS_TPLine", OBJPROP_TIMEFRAMES, visibility);
   }
   
   ChartRedraw(0);
}

//+------------------------------------------------------------------+
//| Perform Calculations and Update visual indicators                |
//+------------------------------------------------------------------+
void Recalculate()
{
   string errorMsg = "";
   bool isValid = ValidateOrder(errorMsg);
   
   // Update Header background color & Title text dynamically
   color headerBg = (gDirection == DIR_BUY) ? COLOR_BUY : COLOR_SELL;
   if(ObjectFind(0, "PS_HeaderBg") >= 0)
   {
      ObjectSetInteger(0, "PS_HeaderBg", OBJPROP_BGCOLOR, headerBg);
      ObjectSetInteger(0, "PS_HeaderBg", OBJPROP_BORDER_COLOR, headerBg);
   }
   
   string titleText = (gDirection == DIR_BUY) ? "▲ BUY POSITION SIZER" : "▼ SELL POSITION SIZER";
   if(ObjectFind(0, "PS_Title") >= 0)
   {
      ObjectSetString(0, "PS_Title", OBJPROP_TEXT, titleText);
   }
   
   // Update Direction button
   string dirText = (gDirection == DIR_BUY) ? "▲ BUY" : "▼ SELL";
   if(ObjectFind(0, "PS_BtnDir") >= 0)
   {
      ObjectSetString(0, "PS_BtnDir", OBJPROP_TEXT, dirText);
      ObjectSetInteger(0, "PS_BtnDir", OBJPROP_BGCOLOR, headerBg);
   }
   
   // Update Risk Mode button
   string riskModeText = gRiskInPct ? "% BALANCE" : "$ CASH VALUE";
   if(ObjectFind(0, "PS_BtnRiskMode") >= 0)
   {
      ObjectSetString(0, "PS_BtnRiskMode", OBJPROP_TEXT, riskModeText);
   }
   
   // Update Risk Value label
   string riskValLbl = gRiskInPct ? "Risk Value (%):" : "Risk Value ($):";
   if(ObjectFind(0, "PS_LblRiskVal") >= 0)
   {
      ObjectSetString(0, "PS_LblRiskVal", OBJPROP_TEXT, riskValLbl);
   }
   
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskAmount = 0;
   
   if(gRiskInPct)
   {
      riskAmount = balance * gRiskValue / 100.0;
      ObjectSetString(0, "PS_LblRiskCash", OBJPROP_TEXT, "Cash at Risk: " + DoubleToString(riskAmount, 2) + " " + AccountInfoString(ACCOUNT_CURRENCY));
   }
   else
   {
      riskAmount = gRiskValue;
      double pct = (balance > 0) ? (riskAmount / balance) * 100.0 : 0;
      ObjectSetString(0, "PS_LblRiskCash", OBJPROP_TEXT, "Risk %: " + DoubleToString(pct, 2) + "% of Balance");
   }
   
   double tickSize = SymbolInfoDouble(Symbol(), SYMBOL_TRADE_TICK_SIZE);
   double tickValue = SymbolInfoDouble(Symbol(), SYMBOL_TRADE_TICK_VALUE);
   
   double slDist = MathAbs(gEntryPrice - gSLPrice);
   int slPoints = (int)MathRound(slDist / Point());
   double slCash = 0;
   
   double tpDist = MathAbs(gEntryPrice - gTPPrice);
   int tpPoints = (int)MathRound(tpDist / Point());
   double tpCash = 0;
   
   double calculatedLots = 0;
   
   if(isValid)
   {
      calculatedLots = CalculateLotSize(gEntryPrice, gSLPrice, riskAmount);
      
      if(calculatedLots > 0 && tickSize > 0)
      {
         double slTicks = slDist / tickSize;
         slCash = slTicks * tickValue * calculatedLots;
         
         double tpTicks = tpDist / tickSize;
         tpCash = tpTicks * tickValue * calculatedLots;
      }
      
      ObjectSetString(0, "PS_LblLots", OBJPROP_TEXT, "LOT SIZE: " + DoubleToString(calculatedLots, 2) + " Lots");
      ObjectSetInteger(0, "PS_LblLots", OBJPROP_COLOR, C'241,196,15'); // Gold Readout color
      
      ObjectSetString(0, "PS_LblStatus", OBJPROP_TEXT, "● Ready to place trade");
      ObjectSetInteger(0, "PS_LblStatus", OBJPROP_COLOR, COLOR_BUY);
      
      ObjectSetString(0, "PS_BtnExecute", OBJPROP_TEXT, "PLACE " + ((gDirection == DIR_BUY) ? "BUY " : "SELL ") + GetOrderTypeName() + " ORDER");
      ObjectSetInteger(0, "PS_BtnExecute", OBJPROP_BGCOLOR, headerBg);
   }
   else
   {
      ObjectSetString(0, "PS_LblLots", OBJPROP_TEXT, "LOT SIZE: --");
      ObjectSetInteger(0, "PS_LblLots", OBJPROP_COLOR, COLOR_TEXT);
      
      ObjectSetString(0, "PS_LblStatus", OBJPROP_TEXT, "● " + errorMsg);
      ObjectSetInteger(0, "PS_LblStatus", OBJPROP_COLOR, COLOR_SELL);
      
      ObjectSetString(0, "PS_BtnExecute", OBJPROP_TEXT, "INVALID SETUP");
      ObjectSetInteger(0, "PS_BtnExecute", OBJPROP_BGCOLOR, COLOR_INVALID);
   }
   
   // Update details label
   double rr = (slDist > 0) ? (tpDist / slDist) : 0;
   ObjectSetString(0, "PS_LblSldist", OBJPROP_TEXT, "SL Distance: " + IntegerToString(slPoints) + " pts (-" + DoubleToString(slCash, 2) + " " + AccountInfoString(ACCOUNT_CURRENCY) + ")");
   ObjectSetString(0, "PS_LblTPdist", OBJPROP_TEXT, "TP Distance: " + IntegerToString(tpPoints) + " pts (+" + DoubleToString(tpCash, 2) + " " + AccountInfoString(ACCOUNT_CURRENCY) + ") R:R " + DoubleToString(rr, 2));
   
   // Redraw chart lines descriptions
   ChartSetInteger(0, CHART_SHOW_OBJECT_DESCR, true);
   
   string entryDesc = "Entry Price: " + DoubleToString(gEntryPrice, _Digits);
   if(gOrderType == ORDER_TYPE_MARKET) entryDesc += " (Market)";
   else if(gOrderType == ORDER_TYPE_LIMIT) entryDesc += " (Limit)";
   else entryDesc += " (Stop)";
   if (ObjectFind(0, "PS_EntryLine") >= 0)
   {
      ObjectSetString(0, "PS_EntryLine", OBJPROP_TEXT, entryDesc);
   }
   
   string slDesc = "Stop Loss: " + DoubleToString(gSLPrice, _Digits) + " (" + IntegerToString(slPoints) + " pts) Risk: -" + DoubleToString(slCash, 2) + " " + AccountInfoString(ACCOUNT_CURRENCY);
   if (ObjectFind(0, "PS_SLLine") >= 0)
   {
      ObjectSetString(0, "PS_SLLine", OBJPROP_TEXT, slDesc);
   }
   
   string tpDesc = "Take Profit: " + DoubleToString(gTPPrice, _Digits) + " (" + IntegerToString(tpPoints) + " pts) Reward: +" + DoubleToString(tpCash, 2) + " " + AccountInfoString(ACCOUNT_CURRENCY);
   if (ObjectFind(0, "PS_TPLine") >= 0)
   {
      ObjectSetString(0, "PS_TPLine", OBJPROP_TEXT, tpDesc);
   }
   
   ChartRedraw(0);
}

//+------------------------------------------------------------------+
//| Calculate Lot Size based on entry, stoploss, and risk amount    |
//+------------------------------------------------------------------+
double CalculateLotSize(double entryPrice, double slPrice, double riskAmount)
{
   if(entryPrice == slPrice) return 0.0;
   
   double tickSize = SymbolInfoDouble(Symbol(), SYMBOL_TRADE_TICK_SIZE);
   double tickValue = SymbolInfoDouble(Symbol(), SYMBOL_TRADE_TICK_VALUE);
   double lotStep = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_STEP);
   double lotMin = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MIN);
   double lotMax = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MAX);
   
   if(tickSize <= 0 || tickValue <= 0 || lotStep <= 0) return 0.0;
   
   double slDist = MathAbs(entryPrice - slPrice);
   double slTicks = slDist / tickSize;
   
   if(slTicks <= 0) return 0.0;
   
   // Risk per 1 standard lot
   double riskPerLot = slTicks * tickValue;
   if(riskPerLot <= 0) return 0.0;
   
   double lotSize = riskAmount / riskPerLot;
   
   // Normalize to lot step size
   lotSize = MathRound(lotSize / lotStep) * lotStep;
   
   if(lotSize < lotMin) lotSize = lotMin;
   if(lotSize > lotMax) lotSize = lotMax;
   
   return lotSize;
}

//+------------------------------------------------------------------+
//| Validate order setup                                             |
//+------------------------------------------------------------------+
bool ValidateOrder(string &outErrorMsg)
{
   if(gEntryPrice <= 0 || gSLPrice <= 0 || gTPPrice <= 0)
   {
      outErrorMsg = "Prices must be positive.";
      return false;
   }
   
   if(gDirection == DIR_BUY)
   {
      if(gSLPrice >= gEntryPrice)
      {
         outErrorMsg = "Buy SL must be below Entry.";
         return false;
      }
      if(gTPPrice <= gEntryPrice)
      {
         outErrorMsg = "Buy TP must be above Entry.";
         return false;
      }
      
      double ask = SymbolInfoDouble(Symbol(), SYMBOL_ASK);
      if(gOrderType == ORDER_TYPE_LIMIT)
      {
         if(gEntryPrice >= ask)
         {
            outErrorMsg = "Buy Limit Entry must be < Ask.";
            return false;
         }
      }
      else if(gOrderType == ORDER_TYPE_STOP)
      {
         if(gEntryPrice <= ask)
         {
            outErrorMsg = "Buy Stop Entry must be > Ask.";
            return false;
         }
      }
   }
   else // DIR_SELL
   {
      if(gSLPrice <= gEntryPrice)
      {
         outErrorMsg = "Sell SL must be above Entry.";
         return false;
      }
      if(gTPPrice >= gEntryPrice)
      {
         outErrorMsg = "Sell TP must be below Entry.";
         return false;
      }
      
      double bid = SymbolInfoDouble(Symbol(), SYMBOL_BID);
      if(gOrderType == ORDER_TYPE_LIMIT)
      {
         if(gEntryPrice <= bid)
         {
            outErrorMsg = "Sell Limit Entry must be > Bid.";
            return false;
          }
      }
      else if(gOrderType == ORDER_TYPE_STOP)
      {
         if(gEntryPrice >= bid)
         {
            outErrorMsg = "Sell Stop Entry must be < Bid.";
            return false;
         }
      }
   }
   
   outErrorMsg = "";
   return true;
}

//+------------------------------------------------------------------+
//| Toggle direction BUY/SELL                                        |
//+------------------------------------------------------------------+
void ToggleDirection()
{
   if(gDirection == DIR_BUY)
   {
      gDirection = DIR_SELL;
   }
   else
   {
      gDirection = DIR_BUY;
   }
   
   // Mirror SL and TP distance around Entry
   double slDist = MathAbs(gEntryPrice - gSLPrice);
   double tpDist = MathAbs(gEntryPrice - gTPPrice);
   
   if(gDirection == DIR_BUY)
   {
      gSLPrice = gEntryPrice - slDist;
      gTPPrice = gEntryPrice + tpDist;
   }
   else
   {
      gSLPrice = gEntryPrice + slDist;
      gTPPrice = gEntryPrice - tpDist;
   }
   
   if(ObjectFind(0, "PS_SLLine") >= 0)
      ObjectSetDouble(0, "PS_SLLine", OBJPROP_PRICE, gSLPrice);
      
   if(ObjectFind(0, "PS_TPLine") >= 0)
      ObjectSetDouble(0, "PS_TPLine", OBJPROP_PRICE, gTPPrice);
   
   Recalculate();
}

//+------------------------------------------------------------------+
//| Toggle order type Market/Limit/Stop                              |
//+------------------------------------------------------------------+
void ToggleOrderType()
{
   if(gOrderType == ORDER_TYPE_MARKET)
   {
      gOrderType = ORDER_TYPE_LIMIT;
      ObjectSetString(0, "PS_BtnType", OBJPROP_TEXT, "LIMIT");
      
      if(ObjectFind(0, "PS_EntryLine") >= 0)
      {
         ObjectSetInteger(0, "PS_EntryLine", OBJPROP_SELECTABLE, true);
         ObjectSetInteger(0, "PS_EntryLine", OBJPROP_STYLE, STYLE_SOLID);
         ObjectSetInteger(0, "PS_EntryLine", OBJPROP_COLOR, COLOR_EXECUTE);
      }
   }
   else if(gOrderType == ORDER_TYPE_LIMIT)
   {
      gOrderType = ORDER_TYPE_STOP;
      ObjectSetString(0, "PS_BtnType", OBJPROP_TEXT, "STOP");
      
      if(ObjectFind(0, "PS_EntryLine") >= 0)
      {
         ObjectSetInteger(0, "PS_EntryLine", OBJPROP_SELECTABLE, true);
         ObjectSetInteger(0, "PS_EntryLine", OBJPROP_STYLE, STYLE_SOLID);
         ObjectSetInteger(0, "PS_EntryLine", OBJPROP_COLOR, COLOR_EXECUTE);
      }
   }
   else if(gOrderType == ORDER_TYPE_STOP)
   {
      gOrderType = ORDER_TYPE_MARKET;
      ObjectSetString(0, "PS_BtnType", OBJPROP_TEXT, "MARKET");
      
      if(ObjectFind(0, "PS_EntryLine") >= 0)
      {
         ObjectSetInteger(0, "PS_EntryLine", OBJPROP_SELECTABLE, false);
         ObjectSetInteger(0, "PS_EntryLine", OBJPROP_SELECTED, false);
         ObjectSetInteger(0, "PS_EntryLine", OBJPROP_STYLE, STYLE_DOT);
         ObjectSetInteger(0, "PS_EntryLine", OBJPROP_COLOR, COLOR_LABEL);
      }
      
      double currentPrice = (gDirection == DIR_BUY) ? SymbolInfoDouble(Symbol(), SYMBOL_ASK) : SymbolInfoDouble(Symbol(), SYMBOL_BID);
      gEntryPrice = currentPrice;
      if(ObjectFind(0, "PS_EntryLine") >= 0)
      {
         ObjectSetDouble(0, "PS_EntryLine", OBJPROP_PRICE, gEntryPrice);
      }
   }
   
   Recalculate();
}

//+------------------------------------------------------------------+
//| Toggle Risk Mode Percentage vs Cash                              |
//+------------------------------------------------------------------+
void ToggleRiskMode()
{
   gRiskInPct = !gRiskInPct;
   
   if(gRiskInPct)
   {
      gRiskValue = 1.0;
   }
   else
   {
      gRiskValue = 100.0;
   }
   
   if(ObjectFind(0, "PS_EdtRiskVal") >= 0)
   {
      ObjectSetString(0, "PS_EdtRiskVal", OBJPROP_TEXT, DoubleToString(gRiskValue, 2));
   }
   Recalculate();
}

//+------------------------------------------------------------------+
//| Place Order executing on MT5 Terminal                            |
//+------------------------------------------------------------------+
void ExecuteTrade()
{
   string errorMsg = "";
   if(!ValidateOrder(errorMsg))
   {
      Alert("Cannot execute trade: " + errorMsg);
      return;
   }
   
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskAmount = 0;
   
   if(gRiskInPct)
   {
      riskAmount = balance * gRiskValue / 100.0;
   }
   else
   {
      riskAmount = gRiskValue;
   }
   
   double lots = CalculateLotSize(gEntryPrice, gSLPrice, riskAmount);
   if(lots <= 0)
   {
      Alert("Calculated lot size is invalid.");
      return;
   }
   
   string msg = "Confirm Trade Placement:\n\n" +
                "Symbol: " + Symbol() + "\n" +
                "Direction: " + ((gDirection == DIR_BUY) ? "BUY" : "SELL") + "\n" +
                "Order Type: " + GetOrderTypeName() + "\n" +
                "Lots: " + DoubleToString(lots, 2) + "\n" +
                "Entry Price: " + DoubleToString(gEntryPrice, _Digits) + "\n" +
                "Stop Loss: " + DoubleToString(gSLPrice, _Digits) + "\n" +
                "Take Profit: " + DoubleToString(gTPPrice, _Digits) + "\n\n" +
                "Risk Amount: " + DoubleToString(riskAmount, 2) + " " + AccountInfoString(ACCOUNT_CURRENCY);
   
   if(!MQLInfoInteger(MQL_TESTER))
   {
      int response = MessageBox(msg, "Place MT5 Order Confirmation", MB_YESNO | MB_ICONQUESTION);
      if(response != IDYES) return;
   }
   
   CTrade trade;
   trade.SetDeviationInPoints(gSlippage);
   trade.SetExpertMagicNumber(gMagicNumber);
   
   bool success = false;
   
   if(gOrderType == ORDER_TYPE_MARKET)
   {
      if(gDirection == DIR_BUY)
      {
         success = trade.Buy(lots, Symbol(), 0, gSLPrice, gTPPrice, "MT5 Position Sizer");
      }
      else
      {
         success = trade.Sell(lots, Symbol(), 0, gSLPrice, gTPPrice, "MT5 Position Sizer");
      }
   }
   else if(gOrderType == ORDER_TYPE_LIMIT)
   {
      if(gDirection == DIR_BUY)
      {
         success = trade.BuyLimit(lots, gEntryPrice, Symbol(), gSLPrice, gTPPrice, ORDER_TIME_GTC, 0, "MT5 Position Sizer");
      }
      else
      {
         success = trade.SellLimit(lots, gEntryPrice, Symbol(), gSLPrice, gTPPrice, ORDER_TIME_GTC, 0, "MT5 Position Sizer");
      }
   }
   else if(gOrderType == ORDER_TYPE_STOP)
   {
      if(gDirection == DIR_BUY)
      {
         success = trade.BuyStop(lots, gEntryPrice, Symbol(), gSLPrice, gTPPrice, ORDER_TIME_GTC, 0, "MT5 Position Sizer");
      }
      else
      {
         success = trade.SellStop(lots, gEntryPrice, Symbol(), gSLPrice, gTPPrice, ORDER_TIME_GTC, 0, "MT5 Position Sizer");
      }
   }
   
   if(success)
   {
      uint retCode = trade.ResultRetcode();
      if(retCode == 10008 || retCode == 10009)
      {
         Print("Trade placed successfully! Ticket: ", trade.ResultOrder());
      }
      else
      {
         Alert("Request sent, but result code is: " + IntegerToString(retCode) + " (" + trade.ResultRetcodeDescription() + ")");
      }
   }
   else
   {
      Alert("Execution failed: " + trade.ResultRetcodeDescription());
   }
}

//+------------------------------------------------------------------+
//| Helpers                                                          |
//+------------------------------------------------------------------+
string GetOrderTypeName()
{
   if(gOrderType == ORDER_TYPE_MARKET) return "MARKET";
   if(gOrderType == ORDER_TYPE_LIMIT)  return "LIMIT";
   return "STOP";
}

double NormalizePrice(double price)
{
   double tickSize = SymbolInfoDouble(Symbol(), SYMBOL_TRADE_TICK_SIZE);
   if(tickSize <= 0) return NormalizeDouble(price, _Digits);
   return MathRound(price / tickSize) * tickSize;
}

bool CreatePanelBg(string name, int x, int y, int w, int h, color bgClr, color borderClr)
{
   if(ObjectCreate(0, name, OBJ_RECTANGLE_LABEL, 0, 0, 0))
   {
      ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
      ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
      ObjectSetInteger(0, name, OBJPROP_XSIZE, w);
      ObjectSetInteger(0, name, OBJPROP_YSIZE, h);
      ObjectSetInteger(0, name, OBJPROP_BGCOLOR, bgClr);
      ObjectSetInteger(0, name, OBJPROP_BORDER_COLOR, borderClr);
      ObjectSetInteger(0, name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
      ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, name, OBJPROP_SELECTED, false);
      ObjectSetInteger(0, name, OBJPROP_ZORDER, 0); // Background level
      ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
      return true;
   }
   return false;
}

bool CreateLabel(string name, string text, int x, int y, color textColor, int fontSize = 9)
{
   if(ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0))
   {
      ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
      ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
      ObjectSetString(0, name, OBJPROP_TEXT, text);
      ObjectSetInteger(0, name, OBJPROP_COLOR, textColor);
      ObjectSetInteger(0, name, OBJPROP_FONTSIZE, fontSize);
      ObjectSetString(0, name, OBJPROP_FONT, "Segoe UI");
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, name, OBJPROP_SELECTED, false);
      ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, name, OBJPROP_ZORDER, 2); // Text level
      ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
      return true;
   }
   return false;
}

bool CreateButton(string name, string text, int x, int y, int width, int height, color backColor, color textColor)
{
   if(ObjectCreate(0, name, OBJ_BUTTON, 0, 0, 0))
   {
      ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
      ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
      ObjectSetInteger(0, name, OBJPROP_XSIZE, width);
      ObjectSetInteger(0, name, OBJPROP_YSIZE, height);
      ObjectSetString(0, name, OBJPROP_TEXT, text);
      ObjectSetInteger(0, name, OBJPROP_COLOR, textColor);
      ObjectSetInteger(0, name, OBJPROP_BGCOLOR, backColor);
      ObjectSetInteger(0, name, OBJPROP_BORDER_COLOR, COLOR_BORDER);
      ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 9);
      ObjectSetString(0, name, OBJPROP_FONT, "Segoe UI");
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, name, OBJPROP_SELECTED, false);
      ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, name, OBJPROP_ZORDER, 3); // Interactive level
      ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
      return true;
   }
   return false;
}

bool CreateEdit(string name, string text, int x, int y, int width, int height, color backColor, color textColor)
{
   if(ObjectCreate(0, name, OBJ_EDIT, 0, 0, 0))
   {
      ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
      ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
      ObjectSetInteger(0, name, OBJPROP_XSIZE, width);
      ObjectSetInteger(0, name, OBJPROP_YSIZE, height);
      ObjectSetString(0, name, OBJPROP_TEXT, text);
      ObjectSetInteger(0, name, OBJPROP_COLOR, textColor);
      ObjectSetInteger(0, name, OBJPROP_BGCOLOR, backColor);
      ObjectSetInteger(0, name, OBJPROP_BORDER_COLOR, COLOR_BORDER);
      ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 9);
      ObjectSetString(0, name, OBJPROP_FONT, "Segoe UI");
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false); // Must be false to direct click/edit
      ObjectSetInteger(0, name, OBJPROP_READONLY, false);   // Must be false to input text
      ObjectSetInteger(0, name, OBJPROP_ALIGN, ALIGN_CENTER);
      ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, name, OBJPROP_ZORDER, 3); // Interactive level
      ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
      return true;
   }
   return false;
}

bool CreateDivider(string name, int x, int y, int w)
{
   if(ObjectCreate(0, name, OBJ_RECTANGLE_LABEL, 0, 0, 0))
   {
      ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
      ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
      ObjectSetInteger(0, name, OBJPROP_XSIZE, w);
      ObjectSetInteger(0, name, OBJPROP_YSIZE, 1);
      ObjectSetInteger(0, name, OBJPROP_BGCOLOR, COLOR_BORDER);
      ObjectSetInteger(0, name, OBJPROP_BORDER_COLOR, COLOR_BORDER);
      ObjectSetInteger(0, name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
      ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, name, OBJPROP_SELECTED, false);
      ObjectSetInteger(0, name, OBJPROP_ZORDER, 1); // Divider level
      ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
      return true;
   }
   return false;
}

bool CreateHLine(string name, double price, color clr, int style, int width)
{
   if(ObjectFind(0, name) >= 0)
   {
      ObjectDelete(0, name);
   }
   if(ObjectCreate(0, name, OBJ_HLINE, 0, 0, price))
   {
      ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
      ObjectSetInteger(0, name, OBJPROP_STYLE, style);
      ObjectSetInteger(0, name, OBJPROP_WIDTH, width);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, true);
      ObjectSetInteger(0, name, OBJPROP_SELECTED, false);
      ObjectSetInteger(0, name, OBJPROP_BACK, false);
      ObjectSetInteger(0, name, OBJPROP_HIDDEN, false);
      return true;
   }
   return false;
}
