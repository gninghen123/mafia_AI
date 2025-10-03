//
//  APTRScreener.m
//  TradingApp
//
//  APTR (Adaptive Price True Range) Screener
//
//  Formula (from ThinkOrSwim):
//  bottom = Min(close[1], low)
//  tr = TrueRange(high, close, low)
//  ptr = tr / (bottom + tr / 2) * 100
//  APTR = MovingAverage(WILDERS, ptr, length)
//
//  This screener filters stocks based on APTR thresholds
//

#import "APTRScreener.h"
#import "TechnicalIndicatorHelper.h"

@implementation APTRScreener

#pragma mark - BaseScreener Overrides

- (NSString *)screenerID {
    return @"aptr";
}

- (NSString *)displayName {
    return @"APTR";
}

- (NSString *)descriptionText {
    return @"Adaptive Price True Range - filters stocks based on normalized volatility";
}

- (NSInteger)minBarsRequired {
    // Need length period + 1 for close[1] + extra for smoothing
    NSInteger length = [self parameterIntegerForKey:@"length" defaultValue:14];
    return length + 15;  // Extra bars for accurate Wilders smoothing
}

- (NSDictionary *)defaultParameters {
    return @{
        @"length": @14,              // Smoothing period (default 14)
        @"minAPTR": @0.0,           // Minimum APTR threshold (0 = no minimum)
        @"maxAPTR": @100.0          // Maximum APTR threshold (100 = no maximum)
    };
}

#pragma mark - Execution

- (NSArray<NSString *> *)executeOnSymbols:(NSArray<NSString *> *)inputSymbols
                               cachedData:(NSDictionary<NSString *, NSArray<HistoricalBarModel *> *> *)cache {
    
    NSInteger length = [self parameterIntegerForKey:@"length" defaultValue:14];
    double minAPTR = [self parameterDoubleForKey:@"minAPTR" defaultValue:0.0];
    double maxAPTR = [self parameterDoubleForKey:@"maxAPTR" defaultValue:100.0];
    
    NSMutableArray<NSString *> *results = [NSMutableArray array];
    
    for (NSString *symbol in inputSymbols) {
        NSArray<HistoricalBarModel *> *bars = [self barsForSymbol:symbol inCache:cache];
        
        if (!bars || bars.count < self.minBarsRequired) continue;
        
        // Calculate APTR for current bar (index 0)
        double aptr = [self calculateAPTR:bars index:0 length:length];
        
        // Apply filters
        if (aptr >= minAPTR && aptr <= maxAPTR) {
            [results addObject:symbol];
            
            NSLog(@"✅ APTR: %@ - APTR: %.2f (range: %.2f-%.2f)",
                  symbol, aptr, minAPTR, maxAPTR);
        }
    }
    
    NSLog(@"🎯 APTR screener found %lu symbols (length: %ld, range: %.2f-%.2f)",
          (unsigned long)results.count, (long)length, minAPTR, maxAPTR);
    
    return [results copy];
}

#pragma mark - APTR Calculation

- (double)calculateAPTR:(NSArray<HistoricalBarModel *> *)bars
                  index:(NSInteger)index
                 length:(NSInteger)length {
    
    if (bars.count < index + length + 1) return 0.0;
    
    // Calculate PTR values for each bar
    NSMutableArray<NSNumber *> *ptrValues = [NSMutableArray arrayWithCapacity:length];
    
    for (NSInteger i = index; i < index + length; i++) {
        if (i >= bars.count - 1) break;  // Need previous bar
        
        HistoricalBarModel *current = bars[i];
        HistoricalBarModel *previous = bars[i + 1];
        
        // bottom = Min(close[1], low)
        double bottom = fmin(previous.close, current.low);
        
        // tr = TrueRange(high, close, low)
        double tr = [TechnicalIndicatorHelper trueRange:current previous:previous];
        
        // ptr = tr / (bottom + tr / 2) * 100
        double denominator = bottom + (tr / 2.0);
        double ptr = (denominator > 0.0) ? (tr / denominator * 100.0) : 0.0;
        
        [ptrValues addObject:@(ptr)];
    }
    
    // Apply Wilders smoothing (SMMA) to PTR values
    double aptr = [self wildersSmoothing:ptrValues period:length];
    
    return aptr;
}

#pragma mark - Wilders Smoothing (SMMA)

/**
 * Wilders Smoothing (also known as Smoothed Moving Average - SMMA)
 * Formula: SMMA[i] = (SMMA[i-1] * (period - 1) + value[i]) / period
 * First SMMA = Simple average of first 'period' values
 */
- (double)wildersSmoothing:(NSArray<NSNumber *> *)values period:(NSInteger)period {
    
    if (values.count < period) return 0.0;
    
    // Calculate initial SMA for first SMMA value
    double sum = 0.0;
    for (NSInteger i = 0; i < period; i++) {
        sum += [values[i] doubleValue];
    }
    double smma = sum / (double)period;
    
    // Apply Wilders smoothing for remaining values
    for (NSInteger i = period; i < values.count; i++) {
        double value = [values[i] doubleValue];
        smma = (smma * (period - 1) + value) / (double)period;
    }
    
    return smma;
}

@end
