//
//  BaseScreener.m
//  TradingApp
//

#import "BaseScreener.h"

@implementation BaseScreener

#pragma mark - Properties (Default implementations - subclasses should override)

- (NSString *)screenerID {
    return @"base_screener";
}

- (NSString *)displayName {
    return @"Base Screener";
}

- (NSString *)descriptionText {
    return @"Base screener class - should be overridden";
}

- (NSInteger)minBarsRequired {
    return 1;
}

#pragma mark - Execution

- (NSArray<NSString *> *)executeOnSymbols:(NSArray<NSString *> *)inputSymbols
                               cachedData:(NSDictionary<NSString *, NSArray<HistoricalBarModel *> *> *)cache {
    
    // Base implementation does nothing - subclasses must override
    NSLog(@"⚠️ BaseScreener executeOnSymbols called directly - subclass should override");
    return @[];
}

#pragma mark - Helper Methods

- (NSArray<HistoricalBarModel *> *)barsForSymbol:(NSString *)symbol
                                          inCache:(NSDictionary *)cache {
    return cache[symbol];
}

- (double)parameterDoubleForKey:(NSString *)key
                   defaultValue:(double)defaultValue {
    if (!self.parameters || !self.parameters[key]) {
        return defaultValue;
    }
    return [self.parameters[key] doubleValue];
}

- (NSInteger)parameterIntegerForKey:(NSString *)key
                       defaultValue:(NSInteger)defaultValue {
    if (!self.parameters || !self.parameters[key]) {
        return defaultValue;
    }
    return [self.parameters[key] integerValue];
}

- (BOOL)parameterBoolForKey:(NSString *)key
               defaultValue:(BOOL)defaultValue {
    if (!self.parameters || !self.parameters[key]) {
        return defaultValue;
    }
    return [self.parameters[key] boolValue];
}

- (NSString *)parameterStringForKey:(NSString *)key
                       defaultValue:(NSString *)defaultValue {
    if (!self.parameters || !self.parameters[key]) {
        return defaultValue;
    }
    return self.parameters[key];
}

@end
