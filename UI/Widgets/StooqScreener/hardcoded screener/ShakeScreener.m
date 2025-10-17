//
//  ShakeScreener.m
//  TradingApp
//

#import "ShakeScreener.h"
#import "TechnicalIndicatorHelper.h"

@implementation ShakeScreener

#pragma mark - Properties

- (NSString *)screenerID {
    return @"shake";
}

- (NSString *)displayName {
    return @"Shake (Gap + Volume)";
}

- (NSString *)descriptionText {
    return @"Finds stocks with gapping and high volume days in the last N days. Optional: check if high > Bollinger Band top (calculated on SMA or EMA).";
}

- (NSInteger)minBarsRequired {
    // Need 50 bars for SMA(volume, 50) + 16 lookback = 66 bars
    // If BB check enabled, need period bars for BB calculation
    NSInteger lookback = [self parameterIntegerForKey:@"lookback_days" defaultValue:16];
    BOOL checkBB = [self parameterBoolForKey:@"check_bb_breakout" defaultValue:NO];
    NSInteger smaPeriod = [self parameterIntegerForKey:@"sma_period" defaultValue:50];
    
    if (checkBB) {
        NSInteger bbPeriod = [self parameterIntegerForKey:@"bb_period" defaultValue:100];
        return MAX(smaPeriod + lookback, bbPeriod + lookback);
    }
    
    return smaPeriod + lookback;
}

#pragma mark - Execution

- (NSArray<NSString *> *)executeOnSymbols:(NSArray<NSString *> *)inputSymbols
                               cachedData:(NSDictionary<NSString *, NSArray<HistoricalBarModel *> *> *)cache {
    
    NSMutableArray *results = [NSMutableArray array];
    
    NSInteger smaPeriod = [self parameterIntegerForKey:@"sma_period" defaultValue:50];
    
    // Get parameters with defaults
    double volumeMultiplier = [self parameterDoubleForKey:@"volume_multiplier" defaultValue:2.0];
    double minDollarVolume = [self parameterDoubleForKey:@"min_dollar_volume" defaultValue:5.0] * 1000000;
    double minVolume = [self parameterDoubleForKey:@"min_volume" defaultValue:1.0] * 1000000;
    double gapThreshold = [self parameterDoubleForKey:@"gap_threshold" defaultValue:1.2];
    NSInteger lookbackDays = [self parameterIntegerForKey:@"lookback_days" defaultValue:16];
    
    // Bollinger Bands parameters (optional)
    BOOL checkBB = [self parameterBoolForKey:@"check_bb_breakout" defaultValue:NO];
    NSInteger bbPeriod = [self parameterIntegerForKey:@"bb_period" defaultValue:100];
    double bbMultiplier = [self parameterDoubleForKey:@"bb_multiplier" defaultValue:2.0];
    NSString *bbBasisType = [self parameterStringForKey:@"bb_basis_type" defaultValue:@"sma"];  // "sma" or "ema"
    NSString *bbBreakoutDirection = [self parameterStringForKey:@"bb_breakout_direction" defaultValue:@"upper"];  // "upper", "lower", or "any"
    NSArray<NSString *> *bbPricePoints = self.parameters[@"bb_price_points"] ?: @[@"high"];  // Which prices to check
    
    for (NSString *symbol in inputSymbols) {
        NSArray<HistoricalBarModel *> *bars = [self barsForSymbol:symbol inCache:cache];
        
        if (!bars || bars.count < self.minBarsRequired) {
            continue;  // Insufficient data
        }
        
        // Check if there was a "shake day" within the lookback period
        BOOL foundShakeDay = NO;
        
        NSInteger startIdx = bars.count - 1;
        NSInteger endIdx = MAX(0, bars.count - 1 - lookbackDays);
        
        for (NSInteger i = startIdx; i > endIdx; i--) {
            HistoricalBarModel *bar = bars[i];
            HistoricalBarModel *prevBar = (i > 0) ? bars[i-1] : nil;
            
            if (!prevBar) continue;
            
            // Calculate SMA(volume, smaPeriod) at position i
            double smaVolume = [TechnicalIndicatorHelper sma:bars
                                                        index:(bars.count - 1 - i)
                                                       period:smaPeriod
                                                     valueKey:@"volume"];
            
            // Calculate SMA(close, 5) at position i
            double smaClose5 = [TechnicalIndicatorHelper sma:bars
                                                        index:(bars.count - 1 - i)
                                                       period:5
                                                     valueKey:@"close"];
            
            // Condition 1: volume >= SMA(volume, 50) * multiplier
            BOOL volumeCondition = bar.volume >= (smaVolume * volumeMultiplier);
            
            // Condition 2: volume * close >= min dollar volume
            double dollarVol = [TechnicalIndicatorHelper dollarVolume:bar];
            BOOL dollarVolumeCondition = dollarVol >= minDollarVolume;
            
            // Condition 3: volume >= min absolute volume
            BOOL minVolumeCondition = bar.volume >= minVolume;
            
            // Condition 4: Gap up OR close > previous close * threshold
            BOOL gapUp = [TechnicalIndicatorHelper isGapUp:bar previous:prevBar];
            BOOL bigMove = bar.close > (prevBar.close * gapThreshold);
            BOOL gapCondition = gapUp || bigMove;
            
            // Condition 5: close > SMA(close, 5)
            BOOL smaCondition = bar.close > smaClose5;
            
            // All conditions must be true for a "shake day"
            if (volumeCondition && dollarVolumeCondition && minVolumeCondition &&
                gapCondition && smaCondition) {
                foundShakeDay = YES;
                break;
            }
        }
        
        if (!foundShakeDay) continue;
        
        // Final condition: close today OR yesterday > SMA(close, 20)
        NSInteger todayIdx = bars.count - 1;
        NSInteger yesterdayIdx = bars.count - 2;
        
        HistoricalBarModel *today = bars[todayIdx];
        HistoricalBarModel *yesterday = bars[yesterdayIdx];
        
        double sma20Today = [TechnicalIndicatorHelper sma:bars
                                                     index:0
                                                    period:20
                                                  valueKey:@"close"];
        
        BOOL finalCondition = (today.close > sma20Today) || (yesterday.close > sma20Today);
        
        if (!finalCondition) continue;
        
        // ✅ OPTIONAL: Check Bollinger Bands breakout
        if (checkBB) {
            // Calculate middle band (SMA or EMA based on parameter)
            double middleBand = 0.0;
            
            if ([bbBasisType isEqualToString:@"ema"]) {
                middleBand = [TechnicalIndicatorHelper ema:bars
                                                      index:0
                                                     period:bbPeriod];
            } else {
                // Default to SMA
                middleBand = [TechnicalIndicatorHelper sma:bars
                                                      index:0
                                                     period:bbPeriod
                                                   valueKey:@"close"];
            }
            
            if (middleBand == 0.0) continue;  // Invalid calculation
            
            // Calculate standard deviation on close prices (for BB calculation)
            double stdDev = [TechnicalIndicatorHelper standardDeviation:bars
                                                                  index:0
                                                                 period:bbPeriod];
            
            if (stdDev == 0.0) continue;  // Invalid standard deviation
            
            // Calculate upper and lower bands
            double upperBand = middleBand + (stdDev * bbMultiplier);
            double lowerBand = middleBand - (stdDev * bbMultiplier);
            
            // Check which price points to test
            NSMutableArray<NSNumber *> *pricesToCheck = [NSMutableArray array];
            NSMutableArray<NSString *> *priceNames = [NSMutableArray array];
            
            for (NSString *pricePoint in bbPricePoints) {
                if ([pricePoint isEqualToString:@"high"]) {
                    [pricesToCheck addObject:@(today.high)];
                    [priceNames addObject:@"High"];
                } else if ([pricePoint isEqualToString:@"low"]) {
                    [pricesToCheck addObject:@(today.low)];
                    [priceNames addObject:@"Low"];
                } else if ([pricePoint isEqualToString:@"open"]) {
                    [pricesToCheck addObject:@(today.open)];
                    [priceNames addObject:@"Open"];
                } else if ([pricePoint isEqualToString:@"close"]) {
                    [pricesToCheck addObject:@(today.close)];
                    [priceNames addObject:@"Close"];
                }
            }
            
            // Check for breakouts
            BOOL hasBreakout = NO;
            NSMutableArray<NSString *> *breakoutDetails = [NSMutableArray array];
            
            for (NSInteger i = 0; i < pricesToCheck.count; i++) {
                double price = [pricesToCheck[i] doubleValue];
                NSString *priceName = priceNames[i];
                
                BOOL isAboveUpper = (price > upperBand);
                BOOL isBelowLower = (price < lowerBand);
                
                // Check based on breakoutDirection
                if ([bbBreakoutDirection isEqualToString:@"upper"] && isAboveUpper) {
                    hasBreakout = YES;
                    [breakoutDetails addObject:[NSString stringWithFormat:@"%@(%.2f) > Upper(%.2f)",
                                               priceName, price, upperBand]];
                } else if ([bbBreakoutDirection isEqualToString:@"lower"] && isBelowLower) {
                    hasBreakout = YES;
                    [breakoutDetails addObject:[NSString stringWithFormat:@"%@(%.2f) < Lower(%.2f)",
                                               priceName, price, lowerBand]];
                } else if ([bbBreakoutDirection isEqualToString:@"any"] && (isAboveUpper || isBelowLower)) {
                    hasBreakout = YES;
                    if (isAboveUpper) {
                        [breakoutDetails addObject:[NSString stringWithFormat:@"%@(%.2f) > Upper(%.2f)",
                                                   priceName, price, upperBand]];
                    }
                    if (isBelowLower) {
                        [breakoutDetails addObject:[NSString stringWithFormat:@"%@(%.2f) < Lower(%.2f)",
                                                   priceName, price, lowerBand]];
                    }
                }
            }
            
            if (!hasBreakout) {
                continue;  // Skip this symbol if BB condition not met
            }
            
            NSLog(@"✓ %@ passed BB check: %@ [%@(%ld), mult=%.1f]",
                  symbol,
                  [breakoutDetails componentsJoinedByString:@", "],
                  [bbBasisType isEqualToString:@"ema"] ? @"EMA" : @"SMA",
                  (long)bbPeriod, bbMultiplier);
        }
        
        [results addObject:symbol];
    }
    
    return [results copy];
}

- (NSDictionary *)defaultParameters {
    return @{
        @"volume_multiplier": @2.0,
        @"min_dollar_volume": @5.0,       // In millions
        @"min_volume": @1.0,              // In millions
        @"gap_threshold": @1.2,
        @"lookback_days": @16,
        @"sma_period": @50,
        
        // Bollinger Bands optional parameters
        @"check_bb_breakout": @YES,              // Enable/disable BB check
        @"bb_period": @20,                     // BB period (default 100)
        @"bb_multiplier": @2.0,                 // BB multiplier (default 2.0)
        @"bb_basis_type": @"ema",               // "sma" or "ema"
        @"bb_breakout_direction": @"upper",     // "upper", "lower", or "any"
        @"bb_price_points": @[@"high"]          // Array: ["high", "low", "open", "close"]
    };
}

@end
