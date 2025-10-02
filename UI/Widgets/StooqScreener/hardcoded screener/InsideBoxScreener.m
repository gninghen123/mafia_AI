//
//  InsideBoxScreener.m
//  TradingApp
//
//  Pattern: Trova titoli in consolidamento dentro una "barra madre"
//  - Cerca una barra madre nelle ultime 15 barre (escludendo la più recente)
//  - Le barre successive devono essere tutte dentro il box
//  - Minimo 5 giorni di consolidamento
//  - La barra più recente può essere breakout (viene segnalato comunque)
//

#import "InsideBoxScreener.h"
#import "TechnicalIndicatorHelper.h"

@implementation InsideBoxScreener

#pragma mark - BaseScreener Overrides

- (NSString *)screenerID {
    return @"insidebox";
}

- (NSString *)displayName {
    return @"InsideBox";
}

- (NSString *)descriptionText {
    return @"Finds stocks consolidating inside a mother bar (10%+ range, 3M$+ volume) for at least N days, currently active or just broken out";
}

- (NSInteger)minBarsRequired {
    // Need: max lookback (15) + min consolidation days (5) + 1 current = 21
    NSInteger maxLookback = [self parameterIntegerForKey:@"maxLookback" defaultValue:15];
    NSInteger minConsolidationDays = [self parameterIntegerForKey:@"minConsolidationDays" defaultValue:5];
    return maxLookback + minConsolidationDays + 1;
}

- (NSDictionary *)defaultParameters {
    return @{
        @"maxLookback": @15,
        @"minConsolidationDays": @5,
        @"minBoxRangePercent": @10.0,
        @"minMotherDollarVolume": @3000000.0,
        @"onlyBreakouts": @NO,
        @"minMotherVolumeSpike": @30.0  // ✅ Volume madre deve essere +30% rispetto a prima/dopo
    };
}


#pragma mark - Execution

- (NSArray<NSString *> *)executeOnSymbols:(NSArray<NSString *> *)inputSymbols
                               cachedData:(NSDictionary<NSString *, NSArray<HistoricalBarModel *> *> *)cache {
    
    NSInteger maxLookback = [self parameterIntegerForKey:@"maxLookback" defaultValue:15];
    NSInteger minConsolidationDays = [self parameterIntegerForKey:@"minConsolidationDays" defaultValue:5];
    double minBoxRangePercent = [self parameterDoubleForKey:@"minBoxRangePercent" defaultValue:10.0];
    double minMotherDollarVolume = [self parameterDoubleForKey:@"minMotherDollarVolume" defaultValue:3000000.0];
    
    NSMutableArray<NSString *> *results = [NSMutableArray array];
    
    for (NSString *symbol in inputSymbols) {
        NSArray<HistoricalBarModel *> *bars = [self barsForSymbol:symbol inCache:cache];
        
        if (!bars || bars.count < self.minBarsRequired) continue;
        
        NSInteger lastIdx = bars.count - 1;
        HistoricalBarModel *todayBar = bars[lastIdx]; // Barra più recente
        
        BOOL foundValidBox = NO;
        
        // Cerca la madre da (lastIdx-1) andando indietro fino a (lastIdx-maxLookback)
        for (NSInteger motherIdx = lastIdx - 1; motherIdx >= lastIdx - maxLookback && motherIdx >= 0; motherIdx--) {
            HistoricalBarModel *motherBar = bars[motherIdx];
            
            // ✅ FILTRO 1: Range minimo 10%
            double boxRange = motherBar.high - motherBar.low;
            double boxRangePercent = (boxRange / motherBar.low) * 100.0;
            
            if (boxRangePercent < minBoxRangePercent) {
                continue;
            }
            
            // ✅ FILTRO 2: Volume$ >= 3M
            double motherDollarVolume = motherBar.volume * motherBar.close;
            
            if (motherDollarVolume < minMotherDollarVolume) {
                continue;
            }
            
            // ✅ FILTRO 2.5: Volume spike - madre deve avere volume +30% rispetto a prima/dopo
            double minMotherVolumeSpike = [self parameterDoubleForKey:@"minMotherVolumeSpike" defaultValue:30.0];
            
            if (minMotherVolumeSpike > 0) {
                // Controlla barra prima (se esiste)
                if (motherIdx > 0) {
                    HistoricalBarModel *barBefore = bars[motherIdx - 1];
                    double volumeIncreaseBefore = ((motherBar.volume - barBefore.volume) / barBefore.volume) * 100.0;
                    
                    if (volumeIncreaseBefore < minMotherVolumeSpike) {
                        continue; // Volume non abbastanza alto rispetto al giorno prima
                    }
                }
                
                // Controlla barra dopo (se esiste e non è l'ultima)
                if (motherIdx < lastIdx) {
                    HistoricalBarModel *barAfter = bars[motherIdx + 1];
                    double volumeIncreaseAfter = ((motherBar.volume - barAfter.volume) / barAfter.volume) * 100.0;
                    
                    if (volumeIncreaseAfter < minMotherVolumeSpike) {
                        continue; // Volume non abbastanza alto rispetto al giorno dopo
                    }
                }
            }
            
            // ✅ FILTRO 3: TUTTE le barre DOPO la madre fino a ieri devono essere inside
            NSInteger daysInsideBox = 0;
            BOOL allBarsInside = YES;
            
            // Controlla tutte le barre da (madre+1) fino a (lastIdx-1) - escludiamo oggi
            for (NSInteger i = motherIdx + 1; i < lastIdx; i++) {
                HistoricalBarModel *bar = bars[i];
                
                BOOL isInside = (bar.close <= motherBar.high) && (bar.close >= motherBar.low);
                
                if (isInside) {
                    daysInsideBox++;
                } else {
                    // Appena troviamo una barra fuori, il pattern è rotto
                    allBarsInside = NO;
                    break;
                }
            }
            
            // ✅ FILTRO 4: Almeno N giorni di consolidamento
            if (!allBarsInside || daysInsideBox < minConsolidationDays) {
                continue; // Pattern non valido, cerca altra madre
            }
            
            // ✅ FILTRO 5: Oggi può essere dentro (ACTIVE) o fuori (BREAKOUT TODAY)
            BOOL todayInside = (todayBar.close <= motherBar.high) && (todayBar.close >= motherBar.low);

            // ✅ Controlla se vogliamo solo breakout
            BOOL onlyBreakouts = [self parameterBoolForKey:@"onlyBreakouts" defaultValue:NO];

            if (onlyBreakouts && todayInside) {
                // Se vogliamo solo breakout e oggi è ancora inside, salta questo pattern
                continue;
            }

            foundValidBox = YES;

            NSString *status = todayInside ? @"ACTIVE" : @"BREAKOUT TODAY";
            NSLog(@"📦 InsideBox found for %@: Mother at [%ld] date=%@, %ld days inside, status=%@, range=%.2f%%, vol$=%.0f",
                  symbol, (long)motherIdx, motherBar.date, (long)daysInsideBox, status, boxRangePercent, motherDollarVolume);
            break;
        }
        
        if (foundValidBox) {
            [results addObject:symbol];
        }
    }
    
    return [results copy];
}
@end
