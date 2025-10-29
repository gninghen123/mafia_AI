//
//  BearTrapIndicator.m
//  TradingApp
//

#import "BearTrapIndicator.h"

@implementation BearTrapIndicator

- (CGFloat)calculateScoreForSymbol:(NSString *)symbol
                          withData:(NSArray<HistoricalBarModel *> *)bars
                        parameters:(NSDictionary *)params {
    
    if (!bars || bars.count < 2) {
        NSLog(@"⚠️ BearTrap: Insufficient data for %@ (need 2 bars, have %lu)",
              symbol, (unsigned long)bars.count);
        return -100.0;
    }
    
    // Get last 2 bars
    HistoricalBarModel *currentBar = bars[bars.count - 1];
    HistoricalBarModel *previousBar = bars[bars.count - 2];
    
    BOOL isUndercut = currentBar.low < previousBar.low;
    
    NSLog(@"🐻 BearTrap %@: low[0]=%.2f %@ low[1]=%.2f → %@",
          symbol, currentBar.low, isUndercut ? @"<" : @">=", previousBar.low,
          isUndercut ? @"UNDERCUT ✓" : @"NO");
    
    return isUndercut ? 100.0 : -100.0;
}

- (NSString *)indicatorType {
    return @"BearTrap";
}

- (NSString *)displayName {
    return @"Bear Trap";
}

- (NSInteger)minimumBarsRequired {
    return 2;
}

- (NSDictionary *)defaultParameters {
    return @{};
}

- (NSString *)indicatorDescription {
    return @"Detects when current low breaks below previous low, potentially signaling a shakeout or reversal setup.";
}

@end
