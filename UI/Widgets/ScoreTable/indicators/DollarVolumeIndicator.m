//
//  DollarVolumeIndicator.m
//  TradingApp
//

#import "DollarVolumeIndicator.h"

@implementation DollarVolumeIndicator

- (CGFloat)calculateScoreForSymbol:(NSString *)symbol
                          withData:(NSArray<HistoricalBarModel *> *)bars
                        parameters:(NSDictionary *)params {
    
    if (!bars || bars.count == 0) {
        NSLog(@"⚠️ DollarVolume: No data for %@", symbol);
        return -100.0;
    }
    
    // Get threshold parameter
    NSNumber *thresholdNum = params[@"threshold"];
    CGFloat threshold = thresholdNum ? [thresholdNum doubleValue] : 10000000.0; // Default $10M
    
    // Calculate dollar volume for most recent bar
    HistoricalBarModel *latestBar = bars.lastObject;
    CGFloat dollarVolume = latestBar.close * latestBar.volume;
    
    NSLog(@"💵 DollarVolume %@: $%.2fM (threshold: $%.2fM)",
          symbol, dollarVolume / 1000000.0, threshold / 1000000.0);
    
    // Graduated scoring
    CGFloat ratio = dollarVolume / threshold;
    
    if (ratio >= 5.0) {
        return 100.0;
    } else if (ratio >= 3.0) {
        return 75.0;
    } else if (ratio >= 2.0) {
        return 50.0;
    } else if (ratio >= 1.0) {
        return 25.0;
    } else {
        return -100.0;
    }
}

- (NSString *)indicatorType {
    return @"DollarVolume";
}

- (NSString *)displayName {
    return @"Dollar Volume";
}

- (NSInteger)minimumBarsRequired {
    return 1; // Only need latest bar
}

- (NSDictionary *)defaultParameters {
    return @{
        @"threshold": @(10000000.0) // $10M
    };
}

- (NSString *)indicatorDescription {
    return @"Measures liquidity by calculating close price × volume. Higher values indicate more liquid stocks.";
}

@end
