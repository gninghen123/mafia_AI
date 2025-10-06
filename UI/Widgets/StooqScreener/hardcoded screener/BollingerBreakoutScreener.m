//
//  BollingerBreakoutScreener.m
//  TradingApp
//

#import "BollingerBreakoutScreener.h"
#import "TechnicalIndicatorHelper.h"

@implementation BollingerBreakoutScreener

#pragma mark - BaseScreener Overrides

- (NSString *)screenerID {
    return @"bollinger_breakout";
}

- (NSString *)displayName {
    return @"Bollinger Breakout";
}

- (NSString *)descriptionText {
    return @"Filters symbols where High, Low, Open or Close breaks outside Bollinger Bands (above upper band or below lower band).";
}

- (NSInteger)minBarsRequired {
    NSInteger period = [self parameterIntegerForKey:@"period" defaultValue:20];
    return period + 1;
}

- (NSDictionary *)defaultParameters {
    return @{
        @"period": @20,              // Bollinger Bands period
        @"multiplier": @2.0,         // Standard deviation multiplier
        @"breakoutType": @"any",     // "upper", "lower", "any"
        @"pricePoints": @[@"high", @"low", @"open", @"close"]  // Which prices to check
    };
}

#pragma mark - Execution

- (NSArray<NSString *> *)executeOnSymbols:(NSArray<NSString *> *)inputSymbols
                               cachedData:(NSDictionary<NSString *, NSArray<HistoricalBarModel *> *> *)cache {
    
    // Read parameters
    NSInteger period = [self parameterIntegerForKey:@"period" defaultValue:20];
    double multiplier = [self parameterDoubleForKey:@"multiplier" defaultValue:2.0];
    NSString *breakoutType = [self parameterStringForKey:@"breakoutType" defaultValue:@"any"];
    NSArray<NSString *> *pricePoints = self.parameters[@"pricePoints"] ?: @[@"high", @"low", @"open", @"close"];
    
    // Validation
    if (period < 2 || period > 100) {
        NSLog(@"⚠️ BollingerBreakoutScreener: period must be between 2-100, got %ld", (long)period);
        return @[];
    }
    
    if (multiplier < 0.5 || multiplier > 5.0) {
        NSLog(@"⚠️ BollingerBreakoutScreener: multiplier must be between 0.5-5.0, got %.2f", multiplier);
        return @[];
    }
    
    if (![breakoutType isEqualToString:@"upper"] &&
        ![breakoutType isEqualToString:@"lower"] &&
        ![breakoutType isEqualToString:@"any"]) {
        NSLog(@"⚠️ BollingerBreakoutScreener: breakoutType must be 'upper', 'lower' or 'any'");
        return @[];
    }
    
    NSMutableArray<NSString *> *results = [NSMutableArray array];
    
    for (NSString *symbol in inputSymbols) {
        NSArray<HistoricalBarModel *> *bars = [self barsForSymbol:symbol inCache:cache];
        
        if (!bars || bars.count < self.minBarsRequired) {
            continue;
        }
        
        // Calculate Bollinger Bands on most recent bar (index = 0)
        // Middle band = SMA
        double middleBand = [TechnicalIndicatorHelper sma:bars
                                                    index:0
                                                   period:period
                                                 valueKey:@"close"];
        
        // Standard deviation
        double stdDev = [TechnicalIndicatorHelper standardDeviation:bars
                                                              index:0
                                                             period:period];
        
        // Validate calculations
        if (middleBand == 0.0 || stdDev == 0.0) {
            continue;
        }
        
        // Calculate upper and lower bands
        double upperBand = middleBand + (stdDev * multiplier);
        double lowerBand = middleBand - (stdDev * multiplier);
        
        // Get current bar
        HistoricalBarModel *currentBar = bars.lastObject;
        
        // Check which price points to test
        NSMutableArray<NSNumber *> *pricesToCheck = [NSMutableArray array];
        NSMutableArray<NSString *> *priceNames = [NSMutableArray array];
        
        for (NSString *pricePoint in pricePoints) {
            if ([pricePoint isEqualToString:@"high"]) {
                [pricesToCheck addObject:@(currentBar.high)];
                [priceNames addObject:@"High"];
            } else if ([pricePoint isEqualToString:@"low"]) {
                [pricesToCheck addObject:@(currentBar.low)];
                [priceNames addObject:@"Low"];
            } else if ([pricePoint isEqualToString:@"open"]) {
                [pricesToCheck addObject:@(currentBar.open)];
                [priceNames addObject:@"Open"];
            } else if ([pricePoint isEqualToString:@"close"]) {
                [pricesToCheck addObject:@(currentBar.close)];
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
            
            // Check based on breakoutType
            if ([breakoutType isEqualToString:@"upper"] && isAboveUpper) {
                hasBreakout = YES;
                [breakoutDetails addObject:[NSString stringWithFormat:@"%@(%.2f) > Upper(%.2f)",
                                           priceName, price, upperBand]];
            } else if ([breakoutType isEqualToString:@"lower"] && isBelowLower) {
                hasBreakout = YES;
                [breakoutDetails addObject:[NSString stringWithFormat:@"%@(%.2f) < Lower(%.2f)",
                                           priceName, price, lowerBand]];
            } else if ([breakoutType isEqualToString:@"any"] && (isAboveUpper || isBelowLower)) {
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
        
        // Add to results if breakout found
        if (hasBreakout) {
            [results addObject:symbol];
            
            NSLog(@"✓ %@: BB(%ld,%.1f) Middle=%.2f, Upper=%.2f, Lower=%.2f - %@",
                  symbol,
                  (long)period,
                  multiplier,
                  middleBand,
                  upperBand,
                  lowerBand,
                  [breakoutDetails componentsJoinedByString:@", "]);
        }
    }
    
    NSLog(@"📊 BollingerBreakoutScreener: %lu/%lu symbols passed",
          (unsigned long)results.count,
          (unsigned long)inputSymbols.count);
    
    return [results copy];
}

@end
