//+------------------------------------------------------------------+
//| MultiTimeframeCandles_MT4.mq4                                    |
//| Magasabb idősík gyertyák overlay MT4-re                          |
//+------------------------------------------------------------------+
#property indicator_chart_window

//--- Paraméterek
input string HigherTimeframes = "H1,H4,D1"; // Magasabb idősíkok vesszővel
input int    BarsBack         = 30;         // Hány gyertyát mutasson visszamenőleg
input int    RefreshSeconds   = 60;          // Frissítési időköz másodpercben

// H1 beállítások
input bool   ShowH1           = false;      // H1 gyertyák mutatása
input color  ColorH1Bullish   = clrLime;    // H1 emelkedő gyertya színe
input color  ColorH1Bearish   = clrRed;     // H1 csökkenő gyertya színe
input int    LineWidthH1      = 1;          // H1 körvonal vastagsága
input ENUM_LINE_STYLE LineStyleH1 = STYLE_DOT; // H1 körvonal stílusa

// H4 beállítások
input bool   ShowH4           = true;       // H4 gyertyák mutatása
input color  ColorH4Bullish   = clrGreen;   // H4 emelkedő gyertya színe
input color  ColorH4Bearish   = clrFireBrick; // H4 csökkenő gyertya színe
input int    LineWidthH4      = 2;          // H4 körvonal vastagsága
input ENUM_LINE_STYLE LineStyleH4 = STYLE_SOLID; // H4 körvonal stílusa

// D1 beállítások
input bool   ShowD1           = false;      // D1 gyertyák mutatása
input color  ColorD1Bullish   = C'189,255,0'; // D1 emelkedő gyertya színe (YellowGreen)
input color  ColorD1Bearish   = clrOrange;  // D1 csökkenő gyertya színe
input int    LineWidthD1      = 1;          // D1 körvonal vastagsága
input ENUM_LINE_STYLE LineStyleD1 = STYLE_DOT; // D1 körvonal stílusa

// Globális változók
string objPrefix = "MTC_";
string objTypes[6] = {"Top_", "Bottom_", "Left_", "Right_", "UpperWick_", "LowerWick_"};
datetime lastUpdateTime = 0; // Utolsó frissítés ideje

//--- Segédfüggvény: Idősík szövegből ENUM_TIMEFRAMES
int TimeframeFromString(string tf) {
   StringToUpper(tf);
   
   if(tf=="M1")  return PERIOD_M1;
   if(tf=="M5")  return PERIOD_M5;
   if(tf=="M15") return PERIOD_M15;
   if(tf=="M30") return PERIOD_M30;
   if(tf=="H1")  return PERIOD_H1;
   if(tf=="H4")  return PERIOD_H4;
   if(tf=="D1")  return PERIOD_D1;
   if(tf=="W1")  return PERIOD_W1;
   if(tf=="MN1") return PERIOD_MN1;
   return 0;
}

//+------------------------------------------------------------------+
//| Objektumok törlése                                               |
//+------------------------------------------------------------------+
void DeleteObjects() {
   string name;
   for(int i=ObjectsTotal()-1; i>=0; i--) {
      name = ObjectName(i);
      if(StringSubstr(name, 0, StringLen(objPrefix)) == objPrefix) {
         ObjectDelete(name);
      }
   }
}

//+------------------------------------------------------------------+
//| Gyertya rajzolása                                                |
//+------------------------------------------------------------------+
void DrawCandle(int tfIndex, int candleIndex, datetime t1, datetime t2, 
                double open, double high, double low, double close, 
                color bullColor, color bearColor, int lineWidth, ENUM_LINE_STYLE lineStyle) {
   // Bullish vagy bearish gyertya?
   bool isBullish = close > open;
   color currentColor = isBullish ? bullColor : bearColor;
   
   // Gyertya test teteje és alja
   double bodyTop = MathMax(open, close);
   double bodyBottom = MathMin(open, close);
   
   // Középpont a gyertya időtartamában
   datetime tMiddle = t1 + (t2 - t1) / 2;
   
   string objName;
   
   // Gyertya körvonal (4 vonal)
   // Felső vonal
   objName = StringFormat("%s%s%d_%d", objPrefix, objTypes[0], tfIndex, candleIndex);
   ObjectCreate(objName, OBJ_TREND, 0, t1, bodyTop, t2, bodyTop);
   ObjectSet(objName, OBJPROP_COLOR, currentColor);
   ObjectSet(objName, OBJPROP_WIDTH, lineWidth);
   ObjectSet(objName, OBJPROP_STYLE, lineStyle);
   ObjectSet(objName, OBJPROP_RAY, false);
   ObjectSet(objName, OBJPROP_BACK, true);
   
   // Alsó vonal
   objName = StringFormat("%s%s%d_%d", objPrefix, objTypes[1], tfIndex, candleIndex);
   ObjectCreate(objName, OBJ_TREND, 0, t1, bodyBottom, t2, bodyBottom);
   ObjectSet(objName, OBJPROP_COLOR, currentColor);
   ObjectSet(objName, OBJPROP_WIDTH, lineWidth);
   ObjectSet(objName, OBJPROP_STYLE, lineStyle);
   ObjectSet(objName, OBJPROP_RAY, false);
   ObjectSet(objName, OBJPROP_BACK, true);
   
   // Bal oldali vonal
   objName = StringFormat("%s%s%d_%d", objPrefix, objTypes[2], tfIndex, candleIndex);
   ObjectCreate(objName, OBJ_TREND, 0, t1, bodyBottom, t1, bodyTop);
   ObjectSet(objName, OBJPROP_COLOR, currentColor);
   ObjectSet(objName, OBJPROP_WIDTH, lineWidth);
   ObjectSet(objName, OBJPROP_STYLE, lineStyle);
   ObjectSet(objName, OBJPROP_RAY, false);
   ObjectSet(objName, OBJPROP_BACK, true);
   
   // Jobb oldali vonal
   objName = StringFormat("%s%s%d_%d", objPrefix, objTypes[3], tfIndex, candleIndex);
   ObjectCreate(objName, OBJ_TREND, 0, t2, bodyBottom, t2, bodyTop);
   ObjectSet(objName, OBJPROP_COLOR, currentColor);
   ObjectSet(objName, OBJPROP_WIDTH, lineWidth);
   ObjectSet(objName, OBJPROP_STYLE, lineStyle);
   ObjectSet(objName, OBJPROP_RAY, false);
   ObjectSet(objName, OBJPROP_BACK, true);
   
   // Felső kanóc
   if(high > bodyTop) {
      objName = StringFormat("%s%s%d_%d", objPrefix, objTypes[4], tfIndex, candleIndex);
      ObjectCreate(objName, OBJ_TREND, 0, tMiddle, bodyTop, tMiddle, high);
      ObjectSet(objName, OBJPROP_COLOR, currentColor);
      ObjectSet(objName, OBJPROP_WIDTH, lineWidth);
      ObjectSet(objName, OBJPROP_STYLE, lineStyle);
      ObjectSet(objName, OBJPROP_RAY, false);
      ObjectSet(objName, OBJPROP_BACK, true);
   }
   
   // Alsó kanóc
   if(low < bodyBottom) {
      objName = StringFormat("%s%s%d_%d", objPrefix, objTypes[5], tfIndex, candleIndex);
      ObjectCreate(objName, OBJ_TREND, 0, tMiddle, bodyBottom, tMiddle, low);
      ObjectSet(objName, OBJPROP_COLOR, currentColor);
      ObjectSet(objName, OBJPROP_WIDTH, lineWidth);
      ObjectSet(objName, OBJPROP_STYLE, lineStyle);
      ObjectSet(objName, OBJPROP_RAY, false);
      ObjectSet(objName, OBJPROP_BACK, true);
   }
}

//+------------------------------------------------------------------+
//| Timeframe beállítások lekérése                                   |
//+------------------------------------------------------------------+
void GetTimeframeSettings(int tf, bool &show, color &bullColor, color &bearColor, 
                         int &width, ENUM_LINE_STYLE &style) {
   if(tf == PERIOD_H1) {
      show = ShowH1;
      bullColor = ColorH1Bullish;
      bearColor = ColorH1Bearish;
      width = LineWidthH1;
      style = LineStyleH1;
   } else if(tf == PERIOD_H4) {
      show = ShowH4;
      bullColor = ColorH4Bullish;
      bearColor = ColorH4Bearish;
      width = LineWidthH4;
      style = LineStyleH4;
   } else if(tf == PERIOD_D1) {
      show = ShowD1;
      bullColor = ColorD1Bullish;
      bearColor = ColorD1Bearish;
      width = LineWidthD1;
      style = LineStyleD1;
   } else {
      show = false;
      bullColor = clrGray;
      bearColor = clrGray;
      width = 1;
      style = STYLE_DOT;
   }
}

//+------------------------------------------------------------------+
//| Gyertyák rajzolása                                               |
//+------------------------------------------------------------------+
void DrawCandles() {
   // Töröljük a régi objektumokat
   DeleteObjects();

   string tfArr[10]; // Megnövelt méret a biztonság kedvéért
   int tfCount = StringSplit(HigherTimeframes, ',', tfArr);
   int bars = BarsBack + 1; // +1 a jelenlegi gyertyának

   for(int i=0; i<tfCount; i++) {
      int tf = TimeframeFromString(tfArr[i]);
      if(tf <= Period()) continue; // Csak magasabb idősík

      bool show;
      color bullColor, bearColor;
      int lineWidth;
      ENUM_LINE_STYLE lineStyle;
      
      GetTimeframeSettings(tf, show, bullColor, bearColor, lineWidth, lineStyle);
      if(!show) continue;

      // Magasabb idősík adatok lekérése
      double hOpen[], hHigh[], hLow[], hClose[];
      datetime hTime[];
      
      ArraySetAsSeries(hOpen, true);
      ArraySetAsSeries(hHigh, true);
      ArraySetAsSeries(hLow, true);
      ArraySetAsSeries(hClose, true);
      ArraySetAsSeries(hTime, true);
      
      CopyOpen(Symbol(), tf, 0, bars, hOpen);
      CopyHigh(Symbol(), tf, 0, bars, hHigh);
      CopyLow(Symbol(), tf, 0, bars, hLow);
      CopyClose(Symbol(), tf, 0, bars, hClose);
      CopyTime(Symbol(), tf, 0, bars, hTime);

      // Gyertyák kirajzolása
      for(int j=0; j<bars; j++) {
         datetime t1 = hTime[j];
         datetime t2;
         
         // Ha ez az utolsó (jelenlegi) gyertya, akkor a jobb szélét a chart jelen idejére állítjuk
         if(j == 0) {
            t2 = Time[0]; // Jelenlegi chart idő
         } else {
            t2 = hTime[j-1]; // Előző magasabb timeframe gyertya kezdete
         }
         
         DrawCandle(i, j, t1, t2, hOpen[j], hHigh[j], hLow[j], hClose[j], 
                   bullColor, bearColor, lineWidth, lineStyle);
      }
   }
   
   // Frissítjük az utolsó frissítés idejét
   lastUpdateTime = TimeCurrent();
}

//+------------------------------------------------------------------+
//| Fő rajzoló ciklus                                                |
//+------------------------------------------------------------------+
int start() {
   // Ellenőrizzük, hogy eltelt-e a megadott idő az utolsó frissítés óta
   datetime currentTime = TimeCurrent();
   
   // Ha még nem telt el a megadott idő, vagy ha ez az első futás (lastUpdateTime == 0)
   if(lastUpdateTime == 0 || currentTime - lastUpdateTime >= RefreshSeconds) {
      DrawCandles();
   }
   
   return(0);
}

//+------------------------------------------------------------------+
//| Indikátor inicializálása                                         |
//+------------------------------------------------------------------+
int init() {
   // Első futáskor azonnal rajzoljuk ki a gyertyákat
   lastUpdateTime = 0;
   return(0);
}

//+------------------------------------------------------------------+
//| Indikátor deinicializálása                                       |
//+------------------------------------------------------------------+
int deinit() {
   DeleteObjects();
   return(0);
}
