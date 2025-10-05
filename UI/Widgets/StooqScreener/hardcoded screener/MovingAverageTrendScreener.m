//
//  MovingAverageTrendScreener.m
//  TradingApp
//

#import "MovingAverageTrendScreener.h"
#import "TechnicalIndicatorHelper.h"

@implementation MovingAverageTrendScreener

#pragma mark - BaseScreener Override

- (NSString *)screenerID {
    return @"moving_average_trend";
}

- (NSString *)displayName {
    return @"Moving Average Trend";
}

- (NSString *)descriptionText {
    return @"Filters symbols where the moving average is trending up or down. "
           @"Checks if the MA is consistently rising/falling over recent bars.";
}

- (NSInteger)minBarsRequired {
    NSInteger period = [self parameterIntegerForKey:@"period" defaultValue:50];
    NSInteger lookbackBars = [self parameterIntegerForKey:@"lookbackBars" defaultValue:3];
    
    // Serve: periodo MA + lookback per verificare trend
    return period + lookbackBars;
}

- (NSDictionary *)defaultParameters {
    return @{
        @"period": @50,           // Periodo MA (50 giorni default)
        @"direction": @0,         // 0=Up, 1=Down
        @"maType": @0,            // 0=Simple, 1=Exponential
        @"lookbackBars": @3       // Numero barre per verificare trend
    };
}

#pragma mark - Execution

- (NSArray<NSString *> *)executeOnSymbols:(NSArray<NSString *> *)inputSymbols
                               cachedData:(NSDictionary<NSString *, NSArray<HistoricalBarModel *> *> *)cache {
    
    // Leggi parametri
    NSInteger period = [self parameterIntegerForKey:@"period" defaultValue:50];
    MATrendDirection direction = [self parameterIntegerForKey:@"direction" defaultValue:MATrendDirectionUp];
    MAType maType = [self parameterIntegerForKey:@"maType" defaultValue:MATypeSimple];
    NSInteger lookbackBars = [self parameterIntegerForKey:@"lookbackBars" defaultValue:3];
    
    NSLog(@"📊 MovingAverageTrend: period=%ld, direction=%@, type=%@, lookback=%ld",
          (long)period,
          direction == MATrendDirectionUp ? @"UP" : @"DOWN",
          maType == MATypeSimple ? @"SMA" : @"EMA",
          (long)lookbackBars);
    
    NSMutableArray<NSString *> *passed = [NSMutableArray array];
    
    for (NSString *symbol in inputSymbols) {
        @autoreleasepool {
            NSArray<HistoricalBarModel *> *bars = [self barsForSymbol:symbol inCache:cache];
            
            if (!bars || bars.count < [self minBarsRequired]) {
                continue;
            }
            
            // ✅ USA TechnicalIndicatorHelper per verificare il trend
            BOOL isTrending = [self checkTrendUsingHelper:bars
                                                    period:period
                                                    maType:maType
                                                 direction:direction
                                               lookbackBars:lookbackBars];
            
            if (isTrending) {
                [passed addObject:symbol];
                
                // Log dettagli - calcola MA per logging
                double lastMA = [self calculateMA:bars index:0 period:period type:maType];
                double prevMA = [self calculateMA:bars index:lookbackBars period:period type:maType];
                
                if (lastMA > 0 && prevMA > 0) {
                    double change = ((lastMA - prevMA) / prevMA) * 100.0;
                    
                    NSLog(@"  ✅ %@: MA(%.2f) %@ by %.2f%% over %ld bars",
                          symbol, lastMA,
                          direction == MATrendDirectionUp ? @"UP" : @"DOWN",
                          fabs(change), (long)lookbackBars);
                }
            }
        }
    }
    
    NSLog(@"✅ MovingAverageTrend: %ld/%ld symbols passed",
          (long)passed.count, (long)inputSymbols.count);
    
    return [passed copy];
}

#pragma mark - Trend Check usando TechnicalIndicatorHelper

- (BOOL)checkTrendUsingHelper:(NSArray<HistoricalBarModel *> *)bars
                        period:(NSInteger)period
                        maType:(MAType)maType
                     direction:(MATrendDirection)direction
                   lookbackBars:(NSInteger)lookbackBars {
    
    // Calcola MA per le ultime lookbackBars + 1 barre
    // (serve +1 per confrontare con la barra precedente)
    NSMutableArray<NSNumber *> *maValues = [NSMutableArray arrayWithCapacity:lookbackBars + 1];
    
    for (NSInteger i = 0; i <= lookbackBars; i++) {
        double maValue = [self calculateMA:bars index:i period:period type:maType];
        
        if (maValue <= 0) {
            return NO;  // Dati insufficienti
        }
        
        [maValues addObject:@(maValue)];
    }
    
    // Verifica trend
    if (direction == MATrendDirectionUp) {
        // Verifica che ogni valore sia >= del successivo (crescente)
        // Ricorda: index 0 = più recente, quindi confrontiamo al contrario
        for (NSInteger i = 0; i < maValues.count - 1; i++) {
            double current = [maValues[i] doubleValue];
            double next = [maValues[i + 1] doubleValue];
            
            if (current < next) {
                return NO;  // Non è in uptrend
            }
        }
        return YES;
        
    } else {
        // Verifica che ogni valore sia <= del successivo (decrescente)
        for (NSInteger i = 0; i < maValues.count - 1; i++) {
            double current = [maValues[i] doubleValue];
            double next = [maValues[i + 1] doubleValue];
            
            if (current > next) {
                return NO;  // Non è in downtrend
            }
        }
        return YES;
    }
}

#pragma mark - Calculate MA usando TechnicalIndicatorHelper

- (double)calculateMA:(NSArray<HistoricalBarModel *> *)bars
                index:(NSInteger)index
               period:(NSInteger)period
                 type:(MAType)type {
    
    if (type == MATypeSimple) {
        // ✅ USA TechnicalIndicatorHelper::sma
        return [TechnicalIndicatorHelper sma:bars
                                        index:index
                                       period:period
                                     valueKey:@"close"];
    } else {
        // ✅ USA TechnicalIndicatorHelper::ema
        return [TechnicalIndicatorHelper ema:bars
                                        index:index
                                       period:period];
    }
}

@end
