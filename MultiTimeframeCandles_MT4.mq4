//+------------------------------------------------------------------+
//| MultiTimeframeCandles_MT4.mq4                                    |
//| Magasabb idősík gyertyák overlay MT4-re                          |
//| Verzió: Formálódó gyertya teljes szélességben                     |
//+------------------------------------------------------------------+
#property indicator_chart_window
#property strict // Szigorúbb fordítási ellenőrzés engedélyezése

//--- Paraméterek
input string HigherTimeframes = "H1,H4,D1"; // Magasabb idősíkok vesszővel
input int    BarsBack         = 30;         // Hány gyertyát mutasson visszamenőleg
input int    RefreshSeconds   = 60;         // Frissítési időköz másodpercben
input int    CandleWidthPct   = 95;         // Gyertya szélessége százalékban (1-100)

// H1 beállítások
input bool   ShowH1           = false;      // H1 gyertyák mutatása
input color  ColorH1Bullish   = clrLime;    // H1 emelkedő gyertya színe
input color  ColorH1Bearish   = clrRed;     // H1 csökkenő gyertya színe
input int    LineWidthH1      = 1;          // H1 körvonal vastagsága
input ENUM_LINE_STYLE LineStyleH1 = STYLE_DOT; // H1 körvonal stílusa
input bool   H1InBackground   = true;       // H1 gyertyák a háttérben (true) vagy előtérben (false)

// H4 beállítások
input bool   ShowH4           = true;       // H4 gyertyák mutatása
input color  ColorH4Bullish   = clrGreen;   // H4 emelkedő gyertya színe
input color  ColorH4Bearish   = clrFireBrick; // H4 csökkenő gyertya színe
input int    LineWidthH4      = 2;          // H4 körvonal vastagsága
input ENUM_LINE_STYLE LineStyleH4 = STYLE_SOLID; // H4 körvonal stílusa
input bool   H4InBackground   = false;       // H4 gyertyák a háttérben (true) vagy előtérben (false)

// D1 beállítások
input bool   ShowD1           = false;      // D1 gyertyák mutatása
input color  ColorD1Bullish   = C'189,255,0'; // D1 emelkedő gyertya színe (YellowGreen)
input color  ColorD1Bearish   = clrOrange;  // D1 csökkenő gyertya színe
input int    LineWidthD1      = 1;          // D1 körvonal vastagsága
input ENUM_LINE_STYLE LineStyleD1 = STYLE_DOT; // D1 körvonal stílusa
input bool   D1InBackground   = true;       // D1 gyertyák a háttérben (true) vagy előtérben (false)

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
   return 0; // Érvénytelen idősík esetén 0
}

//+------------------------------------------------------------------+
//| Objektumok törlése                                               |
//+------------------------------------------------------------------+
void DeleteObjects() {
   string name;
   long chart_id = ChartID();
   // Optimalizált törlés: csak a saját prefixszel rendelkező objektumokat nézzük
   for(int i=ObjectsTotal(chart_id, -1, -1)-1; i>=0; i--) {
      name = ObjectName(chart_id, i, -1, -1);
      // StringFind gyorsabb lehet, mint a StringSubstr
      if(StringFind(name, objPrefix, 0) == 0) {
         ObjectDelete(chart_id, name);
      }
   }
   WindowRedraw(); // Biztosítja a vizuális frissítést törlés után
}

//+------------------------------------------------------------------+
//| Gyertya rajzolása                                                |
//+------------------------------------------------------------------+
// A timeLimit paraméter megmarad, de a formálódó gyertyánál 0 lesz az értéke
void DrawCandle(int tfIndex, int candleIndex, datetime t1, datetime t2,
                double open, double high, double low, double close,
                color bullColor, color bearColor, int lineWidth, ENUM_LINE_STYLE lineStyle,
                bool inBackground, datetime timeLimit = 0) {

   bool isBullish = close > open;
   color currentColor = isBullish ? bullColor : bearColor;
   double bodyTop = MathMax(open, close);
   double bodyBottom = MathMin(open, close);
   int widthPercent = MathMax(1, MathMin(100, CandleWidthPct));
   double widthRatio = widthPercent / 100.0;
   int tDurationSeconds = int(t2 - t1);

   if (tDurationSeconds <= 0) {
       // Print("Érvénytelen időtartam a DrawCandle-ben: t1=", t1, ", t2=", t2);
       return;
   }

   int paddingSeconds = int(tDurationSeconds * (1.0 - widthRatio) / 2.0);
   datetime tLeft = t1 + paddingSeconds;
   datetime tRight = t2 - paddingSeconds; // Teljes szélesség jobb széle
   datetime tMiddle = t1 + tDurationSeconds / 2; // Teljes szélesség közepe

   // Effektív jobb szél: Ha timeLimit > 0 és korábbi, akkor azt használja,
   // egyébként (formálódó gyertyánál timeLimit=0) a teljes tRight-ot.
   datetime effectiveRightTime = tRight;
   if (timeLimit > 0 && timeLimit < tRight) {
      effectiveRightTime = timeLimit;
   }
   if (effectiveRightTime < tLeft) {
       effectiveRightTime = tLeft;
   }

   // Effektív középpont: Hasonló logika, mint a jobb szélnél.
   datetime effectiveMiddleTime = tMiddle;
   if (timeLimit > 0 && timeLimit < tMiddle) {
       effectiveMiddleTime = effectiveRightTime; // Ha limit van, a limitált jobb szélhez igazít
   }
   if (effectiveMiddleTime < tLeft) {
       effectiveMiddleTime = tLeft;
   }

   string objName;
   long chartID = ChartID();

   // --- Gyertya körvonal (4 vonal) ---
   // Felső vonal
   objName = StringFormat("%s%s%d_%d", objPrefix, objTypes[0], tfIndex, candleIndex);
   if (!ObjectCreate(chartID, objName, OBJ_TREND, 0, tLeft, bodyTop, effectiveRightTime, bodyTop)) {
       // Print("Hiba a felső vonal létrehozásakor: ", objName, ", Error: ", GetLastError());
   }
   ObjectSetInteger(chartID, objName, OBJPROP_COLOR, currentColor);
   ObjectSetInteger(chartID, objName, OBJPROP_WIDTH, lineWidth);
   ObjectSetInteger(chartID, objName, OBJPROP_STYLE, lineStyle);
   ObjectSetInteger(chartID, objName, OBJPROP_RAY_RIGHT, false);
   ObjectSetInteger(chartID, objName, OBJPROP_BACK, inBackground);

   // Alsó vonal
   objName = StringFormat("%s%s%d_%d", objPrefix, objTypes[1], tfIndex, candleIndex);
   if (!ObjectCreate(chartID, objName, OBJ_TREND, 0, tLeft, bodyBottom, effectiveRightTime, bodyBottom)) {
        // Print("Hiba az alsó vonal létrehozásakor: ", objName, ", Error: ", GetLastError());
   }
   ObjectSetInteger(chartID, objName, OBJPROP_COLOR, currentColor);
   ObjectSetInteger(chartID, objName, OBJPROP_WIDTH, lineWidth);
   ObjectSetInteger(chartID, objName, OBJPROP_STYLE, lineStyle);
   ObjectSetInteger(chartID, objName, OBJPROP_RAY_RIGHT, false);
   ObjectSetInteger(chartID, objName, OBJPROP_BACK, inBackground);

   // Bal oldali vonal
   objName = StringFormat("%s%s%d_%d", objPrefix, objTypes[2], tfIndex, candleIndex);
   if (!ObjectCreate(chartID, objName, OBJ_TREND, 0, tLeft, bodyBottom, tLeft, bodyTop)) {
       // Print("Hiba a bal vonal létrehozásakor: ", objName, ", Error: ", GetLastError());
   }
   ObjectSetInteger(chartID, objName, OBJPROP_COLOR, currentColor);
   ObjectSetInteger(chartID, objName, OBJPROP_WIDTH, lineWidth);
   ObjectSetInteger(chartID, objName, OBJPROP_STYLE, lineStyle);
   ObjectSetInteger(chartID, objName, OBJPROP_RAY_RIGHT, false);
   ObjectSetInteger(chartID, objName, OBJPROP_BACK, inBackground);

   // Jobb oldali vonal
   objName = StringFormat("%s%s%d_%d", objPrefix, objTypes[3], tfIndex, candleIndex);
   if (effectiveRightTime > tLeft) {
      if (!ObjectCreate(chartID, objName, OBJ_TREND, 0, effectiveRightTime, bodyBottom, effectiveRightTime, bodyTop)) {
          // Print("Hiba a jobb vonal létrehozásakor: ", objName, ", Error: ", GetLastError());
      }
      ObjectSetInteger(chartID, objName, OBJPROP_COLOR, currentColor);
      ObjectSetInteger(chartID, objName, OBJPROP_WIDTH, lineWidth);
      ObjectSetInteger(chartID, objName, OBJPROP_STYLE, lineStyle);
      ObjectSetInteger(chartID, objName, OBJPROP_RAY_RIGHT, false);
      ObjectSetInteger(chartID, objName, OBJPROP_BACK, inBackground);
   } else {
       ObjectDelete(chartID, objName);
   }

   // --- Kanócok ---
   // Felső kanóc
   objName = StringFormat("%s%s%d_%d", objPrefix, objTypes[4], tfIndex, candleIndex);
   if(high > bodyTop) {
      if (effectiveMiddleTime >= tLeft) {
         if (!ObjectCreate(chartID, objName, OBJ_TREND, 0, effectiveMiddleTime, bodyTop, effectiveMiddleTime, high)) {
             // Print("Hiba a felső kanóc létrehozásakor: ", objName, ", Error: ", GetLastError());
         }
         ObjectSetInteger(chartID, objName, OBJPROP_COLOR, currentColor);
         ObjectSetInteger(chartID, objName, OBJPROP_WIDTH, lineWidth);
         ObjectSetInteger(chartID, objName, OBJPROP_STYLE, lineStyle);
         ObjectSetInteger(chartID, objName, OBJPROP_RAY_RIGHT, false);
         ObjectSetInteger(chartID, objName, OBJPROP_BACK, inBackground);
      } else {
          ObjectDelete(chartID, objName);
      }
   } else {
       ObjectDelete(chartID, objName);
   }

   // Alsó kanóc
   objName = StringFormat("%s%s%d_%d", objPrefix, objTypes[5], tfIndex, candleIndex);
   if(low < bodyBottom) {
      if (effectiveMiddleTime >= tLeft) {
         if (!ObjectCreate(chartID, objName, OBJ_TREND, 0, effectiveMiddleTime, bodyBottom, effectiveMiddleTime, low)) {
             // Print("Hiba az alsó kanóc létrehozásakor: ", objName, ", Error: ", GetLastError());
         }
         ObjectSetInteger(chartID, objName, OBJPROP_COLOR, currentColor);
         ObjectSetInteger(chartID, objName, OBJPROP_WIDTH, lineWidth);
         ObjectSetInteger(chartID, objName, OBJPROP_STYLE, lineStyle);
         ObjectSetInteger(chartID, objName, OBJPROP_RAY_RIGHT, false);
         ObjectSetInteger(chartID, objName, OBJPROP_BACK, inBackground);
      } else {
          ObjectDelete(chartID, objName);
      }
   } else {
       ObjectDelete(chartID, objName);
   }
}

//+------------------------------------------------------------------+
//| Timeframe beállítások lekérése                                   |
//+------------------------------------------------------------------+
void GetTimeframeSettings(int tf, bool &show, color &bullColor, color &bearColor,
                         int &width, ENUM_LINE_STYLE &style, bool &inBackground) {
   if(tf == PERIOD_H1) {
      show = ShowH1; bullColor = ColorH1Bullish; bearColor = ColorH1Bearish;
      width = LineWidthH1; style = LineStyleH1; inBackground = H1InBackground;
   } else if(tf == PERIOD_H4) {
      show = ShowH4; bullColor = ColorH4Bullish; bearColor = ColorH4Bearish;
      width = LineWidthH4; style = LineStyleH4; inBackground = H4InBackground;
   } else if(tf == PERIOD_D1) {
      show = ShowD1; bullColor = ColorD1Bullish; bearColor = ColorD1Bearish;
      width = LineWidthD1; style = LineStyleD1; inBackground = D1InBackground;
   } else {
      show = false; bullColor = clrGray; bearColor = clrGray;
      width = 1; style = STYLE_DOT; inBackground = true;
   }
}

//+------------------------------------------------------------------+
//| Gyertyák rajzolása (Formálódó gyertya teljes szélességű)          |
//+------------------------------------------------------------------+
void DrawCandles() {
   DeleteObjects();

   string tfArr[]; // Dinamikus tömb
   int tfCount = StringSplit(HigherTimeframes, ',', tfArr);
   if (tfCount <= 0) return;

   int barsToProcess = BarsBack + 1;
   int currentPeriod = Period(); // Aktuális chart idősík lekérése egyszer

   for(int i=0; i<tfCount; i++) {
      int tf = TimeframeFromString(tfArr[i]);
      // Csak magasabb idősík és érvényes idősík
      if(tf <= 0 || tf <= currentPeriod) continue;

      bool show; color bullColor, bearColor; int lineWidth;
      ENUM_LINE_STYLE lineStyle; bool inBackground;
      GetTimeframeSettings(tf, show, bullColor, bearColor, lineWidth, lineStyle, inBackground);
      if(!show) continue;

      // Magasabb idősík adatok lekérése
      double hOpen[], hHigh[], hLow[], hClose[];
      datetime hTime[];
      // Méret beállítása
      ArrayResize(hOpen, barsToProcess); ArrayResize(hHigh, barsToProcess);
      ArrayResize(hLow, barsToProcess); ArrayResize(hClose, barsToProcess);
      ArrayResize(hTime, barsToProcess);
      // Sorrend beállítása (0. index a legfrissebb)
      ArraySetAsSeries(hOpen, true); ArraySetAsSeries(hHigh, true);
      ArraySetAsSeries(hLow, true); ArraySetAsSeries(hClose, true);
      ArraySetAsSeries(hTime, true);

      // Adatok másolása
      int copiedOpen  = CopyOpen(Symbol(), (ENUM_TIMEFRAMES)tf, 0, barsToProcess, hOpen);
      int copiedHigh  = CopyHigh(Symbol(), (ENUM_TIMEFRAMES)tf, 0, barsToProcess, hHigh);
      int copiedLow   = CopyLow(Symbol(), (ENUM_TIMEFRAMES)tf, 0, barsToProcess, hLow);
      int copiedClose = CopyClose(Symbol(), (ENUM_TIMEFRAMES)tf, 0, barsToProcess, hClose);
      int copiedTime  = CopyTime(Symbol(), (ENUM_TIMEFRAMES)tf, 0, barsToProcess, hTime);

      if (copiedTime <= 0) {
          Print("Nem sikerült idő adatokat másolni a ", EnumToString((ENUM_TIMEFRAMES)tf), " idősíkhoz.");
          continue;
      }
      // A másolt elemek számát használjuk a ciklusban
      int barsAvailable = copiedTime;

      for(int j=0; j < barsAvailable; j++) {
         datetime t1 = hTime[j];
         datetime t2;
         // A currentTimeLimit mindig 0 lesz, így a DrawCandle a teljes szélességet használja
         datetime currentTimeLimit = 0;

         if(j == 0) { // Formálódó gyertya
            // A várható vége a kezdete plusz az idősík periódusa
            t2 = t1 + PeriodSeconds((ENUM_TIMEFRAMES)tf);
            // Nincs időkorlát beállítva (currentTimeLimit marad 0)
         } else { // Historikus gyertya
            // A vége az előző gyertya kezdete
            if (j-1 >= 0 && j-1 < barsAvailable) {
                 t2 = hTime[j-1];
            } else {
                 // Becslés, ha nincs előző gyertya
                 t2 = t1 + PeriodSeconds((ENUM_TIMEFRAMES)tf);
                 Print("Figyelmeztetés: Hiányzó adat a ", EnumToString((ENUM_TIMEFRAMES)tf), " idősíkon, ", TimeToString(t1), " gyertya végideje becsült.");
            }
         }

         // Ellenőrizzük az érvényes adatokat
         if (hOpen[j] <= 0 || hHigh[j] <= 0 || hLow[j] <= 0 || hClose[j] <= 0 || t1 >= t2) {
             // Print("Érvénytelen adat a ", EnumToString((ENUM_TIMEFRAMES)tf), " idősíkon, index: ", j, ", idő: ", TimeToString(t1));
             continue;
         }

         // Gyertya rajzolása, a currentTimeLimit mindig 0
         DrawCandle(i, j, t1, t2, hOpen[j], hHigh[j], hLow[j], hClose[j],
                   bullColor, bearColor, lineWidth, lineStyle, inBackground,
                   currentTimeLimit); // Itt currentTimeLimit értéke 0
      }
   }

   lastUpdateTime = TimeCurrent();
   ChartRedraw();
}

//+------------------------------------------------------------------+
//| Indikátor fő számítási ciklusa                                   |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
{
   datetime currentTime = TimeCurrent();
   bool isNewBar = rates_total > prev_calculated; // Új gyertya a charton?

   // Frissítés, ha:
   // 1. Ez az első futás (lastUpdateTime == 0)
   // 2. Eltelt a RefreshSeconds idő
   // 3. Új gyertya érkezett a chartra (opcionális, de reszponzívabb)
   if(lastUpdateTime == 0 || currentTime - lastUpdateTime >= RefreshSeconds || isNewBar) {
      // Csak akkor rajzolunk, ha van elég adat a charton
      if (rates_total > 1) { // Legalább 2 gyertya kell a Time[0] értelmes használatához
         DrawCandles();
      } else {
         // Kezdeti állapotban vagy kevés adat esetén töröljük a régi objektumokat
         DeleteObjects();
         lastUpdateTime = currentTime; // Frissítjük az időt, hogy ne fusson feleslegesen
      }
   }

   return(rates_total);
}

//+------------------------------------------------------------------+
//| Indikátor inicializálása                                         |
//+------------------------------------------------------------------+
int OnInit() {
   lastUpdateTime = 0; // Kényszeríti az első rajzolást az OnCalculate-ben
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Indikátor deinicializálása                                       |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
   DeleteObjects();
   // ChartRedraw(); // A DeleteObjects már tartalmazza
}
//+------------------------------------------------------------------+
