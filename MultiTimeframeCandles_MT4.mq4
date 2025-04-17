//+------------------------------------------------------------------+
//| MultiTimeframeCandles_MT4.mq4                                    |
//| Magasabb idősík gyertyák overlay MT4-re                          |
//+------------------------------------------------------------------+
#property indicator_chart_window

//--- Paraméterek
input string HigherTimeframes = "H1,H4,D1"; // Magasabb idősíkok vesszővel
input int    BarsBack         = 30;         // Hány gyertyát mutasson visszamenőleg

// H1 beállítások
input bool   ShowH1           = false;      // H1 gyertyák mutatása
input color  ColorH1Bullish   = clrLime;    // H1 emelkedő gyertya színe
input color  ColorH1Bearish   = clrRed;     // H1 csökkenő gyertya színe
input int    LineWidthH1      = 1;          // H1 körvonal vastagsága
input ENUM_LINE_STYLE LineStyleH1 = STYLE_DOT; // H1 körvonal stílusa

// H4 beállítások
input bool   ShowH4           = true;       // H4 gyertyák mutatása
input color  ColorH4Bullish   = clrGreen;    // H4 emelkedő gyertya színe
input color  ColorH4Bearish   = clrFireBrick;     // H4 csökkenő gyertya színe
input int    LineWidthH4      = 2;          // H4 körvonal vastagsága
input ENUM_LINE_STYLE LineStyleH4 = STYLE_SOLID; // H4 körvonal stílusa

// D1 beállítások
input bool   ShowD1           = false;      // D1 gyertyák mutatása
input color  ColorD1Bullish   = C'189,255,0'; // D1 emelkedő gyertya színe (YellowGreen)
input color  ColorD1Bearish   = clrOrange;  // D1 csökkenő gyertya színe
input int    LineWidthD1      = 1;          // D1 körvonal vastagsága
input ENUM_LINE_STYLE LineStyleD1 = STYLE_DOT; // D1 körvonal stílusa

//--- Segédfüggvény: Idősík szövegből ENUM_TIMEFRAMES
int TimeframeFromString(string tf) {
   string up = tf;
   for(int k=0; k<StringLen(tf); k++) {
      int ch = StringGetChar(tf, k);
      if(ch >= 97 && ch <= 122) // a-z
         StringSetChar(up, k, ch - 32);
   }
   if(up=="M1")  return PERIOD_M1;
   if(up=="M5")  return PERIOD_M5;
   if(up=="M15") return PERIOD_M15;
   if(up=="M30") return PERIOD_M30;
   if(up=="H1")  return PERIOD_H1;
   if(up=="H4")  return PERIOD_H4;
   if(up=="D1")  return PERIOD_D1;
   if(up=="W1")  return PERIOD_W1;
   if(up=="MN1") return PERIOD_MN1;
   return 0;
}

//+------------------------------------------------------------------+
//| Fő rajzoló ciklus                                                |
//+------------------------------------------------------------------+
int start()
{
   string objNameTop, objNameBottom, objNameLeft, objNameRight;
   string objNameUpperWick, objNameLowerWick;
   
   // Töröljük a régi objektumokat
   for(int tfidx=0; tfidx<3; tfidx++) {
      for(int j1=0; j1<BarsBack+1; j1++) { // +1 a jelenlegi gyertyának
         objNameTop = StringFormat("MTC_Top_%d_%d", tfidx, j1);
         objNameBottom = StringFormat("MTC_Bottom_%d_%d", tfidx, j1);
         objNameLeft = StringFormat("MTC_Left_%d_%d", tfidx, j1);
         objNameRight = StringFormat("MTC_Right_%d_%d", tfidx, j1);
         objNameUpperWick = StringFormat("MTC_UpperWick_%d_%d", tfidx, j1);
         objNameLowerWick = StringFormat("MTC_LowerWick_%d_%d", tfidx, j1);
         
         ObjectDelete(objNameTop);
         ObjectDelete(objNameBottom);
         ObjectDelete(objNameLeft);
         ObjectDelete(objNameRight);
         ObjectDelete(objNameUpperWick);
         ObjectDelete(objNameLowerWick);
      }
   }

   string tfArr[3];
   int tfCount = StringSplit(HigherTimeframes, ',', tfArr);

   for(int i=0; i<tfCount; i++)
   {
      int tf = TimeframeFromString(tfArr[i]);
      if(tf<=Period()) continue; // Csak magasabb idősík

      bool show = false;
      color colBullish = clrGray;
      color colBearish = clrGray;
      int lineWidth = 1;
      ENUM_LINE_STYLE lineStyle = STYLE_DOT;
      
      if(tf==PERIOD_H1)  { 
         show=ShowH1; 
         colBullish=ColorH1Bullish; 
         colBearish=ColorH1Bearish;
         lineWidth=LineWidthH1;
         lineStyle=LineStyleH1;
      }
      if(tf==PERIOD_H4)  { 
         show=ShowH4; 
         colBullish=ColorH4Bullish; 
         colBearish=ColorH4Bearish;
         lineWidth=LineWidthH4;
         lineStyle=LineStyleH4;
      }
      if(tf==PERIOD_D1)  { 
         show=ShowD1; 
         colBullish=ColorD1Bullish; 
         colBearish=ColorD1Bearish;
         lineWidth=LineWidthD1;
         lineStyle=LineStyleD1;
      }
      if(!show) continue;

      int bars = BarsBack + 1; // +1 a jelenlegi gyertyának

      // Magasabb idősík adatok lekérése
      double hOpen[], hHigh[], hLow[], hClose[];
      datetime hTime[];
      ArrayResize(hOpen, bars);
      ArrayResize(hHigh, bars);
      ArrayResize(hLow, bars);
      ArrayResize(hClose, bars);
      ArrayResize(hTime, bars);

      for(int b=0; b<bars; b++) {
         hOpen[b]  = iOpen(Symbol(), tf, b);
         hHigh[b]  = iHigh(Symbol(), tf, b);
         hLow[b]   = iLow(Symbol(), tf, b);
         hClose[b] = iClose(Symbol(), tf, b);
         hTime[b]  = iTime(Symbol(), tf, b);
      }

      // Gyertyák kirajzolása
      for(int j2=0; j2<bars; j2++)
      {
         // Bullish vagy bearish gyertya?
         bool isBullish = hClose[j2] > hOpen[j2];
         color currentColor = isBullish ? colBullish : colBearish;
         
         datetime t1 = hTime[j2];
         datetime t2;
         
         // Ha ez az utolsó (jelenlegi) gyertya, akkor a jobb szélét a chart jelen idejére állítjuk
         if(j2 == 0) {
            t2 = Time[0]; // Jelenlegi chart idő
         } else {
            t2 = hTime[j2-1]; // Előző magasabb timeframe gyertya kezdete
         }
         
         // Gyertya test teteje és alja
         double bodyTop = MathMax(hOpen[j2], hClose[j2]);
         double bodyBottom = MathMin(hOpen[j2], hClose[j2]);
         
         // Gyertya kanócai
         double upperWick = hHigh[j2];
         double lowerWick = hLow[j2];
         
         // Középpont a gyertya időtartamában
         datetime tMiddle = t1 + (t2 - t1) / 2;
         
         // Gyertya körvonal (4 vonal)
         objNameTop = StringFormat("MTC_Top_%d_%d", i, j2);
         ObjectCreate(objNameTop, OBJ_TREND, 0, t1, bodyTop, t2, bodyTop);
         ObjectSet(objNameTop, OBJPROP_COLOR, currentColor);
         ObjectSet(objNameTop, OBJPROP_WIDTH, lineWidth);
         ObjectSet(objNameTop, OBJPROP_STYLE, lineStyle);
         ObjectSet(objNameTop, OBJPROP_RAY, false);
         ObjectSet(objNameTop, OBJPROP_BACK, true);
         
         objNameBottom = StringFormat("MTC_Bottom_%d_%d", i, j2);
         ObjectCreate(objNameBottom, OBJ_TREND, 0, t1, bodyBottom, t2, bodyBottom);
         ObjectSet(objNameBottom, OBJPROP_COLOR, currentColor);
         ObjectSet(objNameBottom, OBJPROP_WIDTH, lineWidth);
         ObjectSet(objNameBottom, OBJPROP_STYLE, lineStyle);
         ObjectSet(objNameBottom, OBJPROP_RAY, false);
         ObjectSet(objNameBottom, OBJPROP_BACK, true);
         
         objNameLeft = StringFormat("MTC_Left_%d_%d", i, j2);
         ObjectCreate(objNameLeft, OBJ_TREND, 0, t1, bodyBottom, t1, bodyTop);
         ObjectSet(objNameLeft, OBJPROP_COLOR, currentColor);
         ObjectSet(objNameLeft, OBJPROP_WIDTH, lineWidth);
         ObjectSet(objNameLeft, OBJPROP_STYLE, lineStyle);
         ObjectSet(objNameLeft, OBJPROP_RAY, false);
         ObjectSet(objNameLeft, OBJPROP_BACK, true);
         
         objNameRight = StringFormat("MTC_Right_%d_%d", i, j2);
         ObjectCreate(objNameRight, OBJ_TREND, 0, t2, bodyBottom, t2, bodyTop);
         ObjectSet(objNameRight, OBJPROP_COLOR, currentColor);
         ObjectSet(objNameRight, OBJPROP_WIDTH, lineWidth);
         ObjectSet(objNameRight, OBJPROP_STYLE, lineStyle);
         ObjectSet(objNameRight, OBJPROP_RAY, false);
         ObjectSet(objNameRight, OBJPROP_BACK, true);
         
         // Felső kanóc
         if(upperWick > bodyTop) {
            objNameUpperWick = StringFormat("MTC_UpperWick_%d_%d", i, j2);
            ObjectCreate(objNameUpperWick, OBJ_TREND, 0, tMiddle, bodyTop, tMiddle, upperWick);
            ObjectSet(objNameUpperWick, OBJPROP_COLOR, currentColor);
            ObjectSet(objNameUpperWick, OBJPROP_WIDTH, lineWidth);
            ObjectSet(objNameUpperWick, OBJPROP_STYLE, lineStyle);
            ObjectSet(objNameUpperWick, OBJPROP_RAY, false);
            ObjectSet(objNameUpperWick, OBJPROP_BACK, true);
         }
         
         // Alsó kanóc
         if(lowerWick < bodyBottom) {
            objNameLowerWick = StringFormat("MTC_LowerWick_%d_%d", i, j2);
            ObjectCreate(objNameLowerWick, OBJ_TREND, 0, tMiddle, bodyBottom, tMiddle, lowerWick);
            ObjectSet(objNameLowerWick, OBJPROP_COLOR, currentColor);
            ObjectSet(objNameLowerWick, OBJPROP_WIDTH, lineWidth);
            ObjectSet(objNameLowerWick, OBJPROP_STYLE, lineStyle);
            ObjectSet(objNameLowerWick, OBJPROP_RAY, false);
            ObjectSet(objNameLowerWick, OBJPROP_BACK, true);
         }
      }
   }
   return(0);
}
