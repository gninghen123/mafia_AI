// ============================================================================
// VolumeLiquidityScreener.m
// ============================================================================

#import "VolumeLiquidityScreener.h"

@implementation VolumeLiquidityScreener

- (instancetype)init {
    self = [super init];
    if (self) {
        self.screenerID = @"volume_liquidity";
        self.displayName = @"$Volume (Liquidity)";
        self.category = @"Volume";
        self.detailedDescription = @"Filters symbols where average volume (SMA) * close price exceeds threshold. Measures daily dollar volume traded.";
        
        // Parametri di default
        self.parameters = @{
            @"sma_period": @5,           // Periodo per SMA del volume
            @"threshold_millions": @4.0   // Soglia in milioni di dollari
        };
    }
    return self;
}

- (NSInteger)minBarsRequired {
    NSInteger smaPeriod = [self.parameters[@"sma_period"] integerValue];
    return smaPeriod;  // Serve almeno smaPeriod giorni
}

- (NSArray<NSString *> *)executeOnSymbols:(NSArray<NSString *> *)symbols
                               cachedData:(NSDictionary<NSString *, NSArray<HistoricalBarModel *> *> *)cache {
    
    // Leggi parametri
    NSInteger smaPeriod = [self.parameters[@"sma_period"] integerValue];
    double thresholdMillions = [self.parameters[@"threshold_millions"] doubleValue];
    double threshold = thresholdMillions * 1000000.0;  // Converti in dollari
    
    NSLog(@"🔍 %@ screening %lu symbols (SMA period: %ld, threshold: $%.1fM)",
          self.displayName,
          (unsigned long)symbols.count,
          (long)smaPeriod,
          thresholdMillions);
    
    NSMutableArray<NSString *> *passed = [NSMutableArray array];
    NSInteger skippedCount = 0;
    
    for (NSString *symbol in symbols) {
        NSArray<HistoricalBarModel *> *bars = cache[symbol];
        
        if (!bars || bars.count < smaPeriod) {
            skippedCount++;
            continue;
        }
        
        // Calcola SMA del volume sugli ultimi smaPeriod giorni
        double volumeSum = 0.0;
        for (NSInteger i = bars.count - smaPeriod; i < bars.count; i++) {
            volumeSum += bars[i].volume;
        }
        double avgVolume = volumeSum / smaPeriod;
        
        // Prezzo di chiusura più recente
        double lastClose = bars.lastObject.close;
        
        // Calcola dollar volume
        double dollarVolume = avgVolume * lastClose;
        
        // Controlla se supera la soglia
        if (dollarVolume > threshold) {
            [passed addObject:symbol];
            
            NSLog(@"  ✓ %@: avg_volume=%.0f, close=$%.2f, $volume=$%.2fM",
                  symbol,
                  avgVolume,
                  lastClose,
                  dollarVolume / 1000000.0);
        }
    }
    
    NSLog(@"✅ %@: %lu/%lu passed (skipped: %ld)",
          self.displayName,
          (unsigned long)passed.count,
          (unsigned long)symbols.count,
          (long)skippedCount);
    
    return [passed copy];
}

- (NSDictionary *)availableParameters {
    return @{
        @"sma_period": @{
            @"type": @"integer",
            @"min": @1,
            @"max": @50,
            @"default": @5,
            @"description": @"Period for volume SMA"
        },
        @"threshold_millions": @{
            @"type": @"number",
            @"min": @0.1,
            @"max": @1000.0,
            @"default": @4.0,
            @"description": @"Minimum dollar volume in millions"
        }
    };
}

@end
