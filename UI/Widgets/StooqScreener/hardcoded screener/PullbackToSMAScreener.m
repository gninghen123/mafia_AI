//
//  PullbackToSMAScreener.m
//  TradingApp
//
//  Pattern: Pullback a SMA in trend rialzista con compressione range
//  - SMA(10) > SMA(20) - trend rialzista
//  - Nelle ultime 3 barre almeno una ha toccato sotto SMA(9)
//  - Range in compressione
//  - Low in rialzo
//

#import "PullbackToSMAScreener.h"
#import "TechnicalIndicatorHelper.h"

@implementation PullbackToSMAScreener

#pragma mark - BaseScreener Overrides

- (NSString *)screenerID {
    return @"pullbacksma";
}

- (NSString *)displayName {
    return @"Pullback to SMA";
}

- (NSString *)descriptionText {
    return @"Finds stocks that pulled back to SMA 9 in last 3 bars, with compressing range and rising lows";
}

- (NSInteger)minBarsRequired {
    // Serve SMA(20) + 3 barre lookback = 23 barre minimo
    return [self parameterIntegerForKey:@"pullbackSMA" defaultValue:9]+[self parameterIntegerForKey:@"lookbackBars" defaultValue:3];
}

- (NSDictionary *)defaultParameters {
    return @{
        @"pullbackSMA": @9,
        @"lookbackBars": @3
    };
}

#pragma mark - Execution

- (NSArray<NSString *> *)executeOnSymbols:(NSArray<NSString *> *)inputSymbols
                               cachedData:(NSDictionary<NSString *, NSArray<HistoricalBarModel *> *> *)cache {
    
    NSInteger pullbackSMA = [self parameterIntegerForKey:@"pullbackSMA" defaultValue:9];
    NSInteger lookbackBars = [self parameterIntegerForKey:@"lookbackBars" defaultValue:3];
    
    NSMutableArray<NSString *> *results = [NSMutableArray array];
    
    for (NSString *symbol in inputSymbols) {
        NSArray<HistoricalBarModel *> *bars = [self barsForSymbol:symbol inCache:cache];
        
        if (!bars || bars.count < self.minBarsRequired) continue;
        
        NSInteger lastIdx = bars.count - 1;
        
  
        
        // ✅ FILTRO 2: Nelle ultime N barre, almeno una ha toccato sotto SMA(9)
        BOOL foundPullback = NO;
        
        for (NSInteger i = lastIdx; i > lastIdx - lookbackBars && i >= 0; i--) {
            HistoricalBarModel *bar = bars[i];
            
            double sma9Value = [TechnicalIndicatorHelper sma:bars
                                                        index:i
                                                       period:pullbackSMA
                                                     valueKey:@"close"];
            
            if (sma9Value > 0.0 && bar.low < sma9Value) {
                foundPullback = YES;
                break;
            }
        }
        
        if (!foundPullback) {
            continue;
        }
        
        // ✅ FILTRO 3+4: Range compresso E low crescente (oggi O ieri)
        if (lastIdx < 2) continue;
        
        HistoricalBarModel *today = bars[lastIdx];
        HistoricalBarModel *yesterday = bars[lastIdx - 1];
        HistoricalBarModel *twoDaysAgo = bars[lastIdx - 2];
        
        double rangeToday = today.high - today.low;
        double rangeYesterday = yesterday.high - yesterday.low;
        double rangeTwoDaysAgo = twoDaysAgo.high - twoDaysAgo.low;
        
        // Condizione A: oggi ha range < ieri AND low > ieri
        BOOL conditionToday = (rangeToday < rangeYesterday) && (today.low > yesterday.low);
        
        // Condizione B: ieri aveva range < 2gg fa AND low > 2gg fa
        BOOL conditionYesterday = (rangeYesterday < rangeTwoDaysAgo) && (yesterday.low > twoDaysAgo.low);
        
        if (!conditionToday && !conditionYesterday) {
            continue;
        }
        
        // ✅ Tutti i filtri passati
        NSString *condition = conditionToday ? @"TODAY" : @"YESTERDAY";
        
        [results addObject:symbol];
    }
    
    return [results copy];
}



@end
