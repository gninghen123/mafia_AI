// ============================================================================
// VolumeLiquidityScreener.m
// ============================================================================

#import "VolumeLiquidityScreener.h"

@implementation VolumeLiquidityScreener

- (NSString *)screenerID {
    return @"volume_liquidity";
}

- (NSString *)displayName {
    return @"$Volume (Liquidity)";
}

- (NSString *)descriptionText {
    return @"Filters symbols by: 1) SMA(volume, period) * close > minDollarVolume (M) AND 2) SMA(volume, period) > minVolume (M)";
}

- (NSInteger)minBarsRequired {
    NSInteger smaPeriod = [self parameterIntegerForKey:@"smaPeriod" defaultValue:10];
    return smaPeriod;  // Serve almeno smaPeriod giorni
}


- (NSArray<NSString *> *)executeOnSymbols:(NSArray<NSString *> *)inputSymbols
                               cachedData:(NSDictionary<NSString *, NSArray<HistoricalBarModel *> *> *)cache {

    // Leggi parametri (espressi in milioni)
    NSInteger smaPeriod = [self parameterIntegerForKey:@"smaPeriod" defaultValue:10];
    double minDollarVolumeM = [self parameterDoubleForKey:@"minDollarVolume" defaultValue:4.0];
    double minVolumeM = [self parameterDoubleForKey:@"minVolume" defaultValue:1.0];
    
    // Converti in valori assoluti
    double minDollarVolume = minDollarVolumeM * 1000000.0;
    double minVolume = minVolumeM * 1000000.0;
    
    NSLog(@"🔍 %@ screening %lu symbols (SMA period: %ld, minDollarVol: $%.1fM, minVol: %.1fM)",
          self.displayName,
          (unsigned long)inputSymbols.count,
          (long)smaPeriod,
          minDollarVolumeM,
          minVolumeM);
    
    NSMutableArray<NSString *> *results = [NSMutableArray array];
    NSInteger skippedCount = 0;
    NSInteger failedDollarVol = 0;
    NSInteger failedMinVol = 0;
    
    for (NSString *symbol in inputSymbols) {
        NSArray<HistoricalBarModel *> *bars = [self barsForSymbol:symbol inCache:cache];
        
        if (!bars || bars.count < smaPeriod) {
            skippedCount++;
            continue;
        }
        
        // Calcola SMA del volume sugli ultimi smaPeriod giorni (ultime barre)
        double volumeSum = 0.0;
        for (NSInteger i = 0; i < smaPeriod; i++) {
            NSInteger idx = bars.count - 1 - i;   // partendo dall’ultima barra
            volumeSum += bars[idx].volume;
        }
        double avgVolume = volumeSum / (double)smaPeriod;
        
        // Prezzo di chiusura corrente (ultima barra = più recente)
        double currentClose = bars.lastObject.close;
        
        // Calcola dollar volume = SMA(volume) * close
        double dollarVolume = avgVolume * currentClose;
        
        // CONDIZIONE 1: SMA(volume, period) * close > minDollarVolume
        BOOL dollarVolumeCondition = dollarVolume >= minDollarVolume;
        
        // CONDIZIONE 2: SMA(volume, period) > minVolume
        BOOL volumeCondition = avgVolume >= minVolume;
        
        // Entrambe le condizioni devono essere vere
        if (dollarVolumeCondition && volumeCondition) {
            [results addObject:symbol];
            
            NSLog(@"  ✓ %@: avgVol=%.0f (%.1fM), close=$%.2f, $vol=$%.2fM",
                  symbol,
                  avgVolume,
                  avgVolume / 1000000.0,
                  currentClose,
                  dollarVolume / 1000000.0);
        } else {
            if (!dollarVolumeCondition) failedDollarVol++;
            if (!volumeCondition) failedMinVol++;
        }
    }
    
    NSLog(@"✅ %@: %lu/%lu passed (skipped: %ld, failed $vol: %ld, failed vol: %ld)",
          self.displayName,
          (unsigned long)results.count,
          (unsigned long)inputSymbols.count,
          (long)skippedCount,
          (long)failedDollarVol,
          (long)failedMinVol);
    
    return [results copy];
}
- (NSDictionary *)defaultParameters {
    return @{
        @"smaPeriod": @10,          // Periodo SMA per calcolare volume medio
        @"minDollarVolume": @4.0,   // 4M - SMA(volume) * close > $4M
        @"minVolume": @1.0          // 1M - SMA(volume) > 1M shares
    };
}

@end
