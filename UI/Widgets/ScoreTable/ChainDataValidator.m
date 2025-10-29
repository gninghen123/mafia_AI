//
//  ChainDataValidator.m
//  TradingApp
//

#import "ChainDataValidator.h"

@implementation ChainDataValidator

+ (BOOL)validateChainData:(NSDictionary *)chainData
          forRequirements:(DataRequirements *)requirements
                   result:(ValidationResult **)result {
    
    ValidationResult *validation = [[ValidationResult alloc] init];
    validation.isValid = YES;  // Assume valid until proven otherwise
    
    // 1️⃣ CHECK: Data exists
    if (!chainData || ![chainData isKindOfClass:[NSDictionary class]]) {
        validation.isValid = NO;
        validation.reason = @"Chain data is nil or not a dictionary";
        if (result) *result = validation;
        return NO;
    }
    
    // 2️⃣ CHECK: Historical bars exist
    NSArray<HistoricalBarModel *> *bars = chainData[@"historicalBars"];
    if (!bars || ![bars isKindOfClass:[NSArray class]] || bars.count == 0) {
        validation.isValid = NO;
        validation.reason = @"No historical bars in chain data";
        if (result) *result = validation;
        return NO;
    }
    
    // 3️⃣ CHECK: Sufficient bars
    if (bars.count < requirements.minimumBars) {
        validation.isValid = NO;
        validation.hasSufficientBars = NO;
        validation.missingBars = requirements.minimumBars - bars.count;
        validation.reason = [NSString stringWithFormat:@"Insufficient bars: %lu < %ld required",
                            (unsigned long)bars.count, (long)requirements.minimumBars];
        if (result) *result = validation;
        return NO;
    }
    validation.hasSufficientBars = YES;
    
    // 4️⃣ CHECK: Timeframe compatibility
    NSNumber *timeframeNum = chainData[@"timeframe"];
    BarTimeframe chainTimeframe = timeframeNum ? [timeframeNum integerValue] : BarTimeframeDaily;
    
    if (chainTimeframe != requirements.timeframe) {
        validation.isValid = NO;
        validation.hasCompatibleTimeframe = NO;
        validation.reason = [NSString stringWithFormat:@"Timeframe mismatch: got %ld, need %ld",
                            (long)chainTimeframe, (long)requirements.timeframe];
        if (result) *result = validation;
        return NO;
    }
    validation.hasCompatibleTimeframe = YES;
    
    // 5️⃣ CHECK: Date range (if specified)
    if (requirements.earliestDate) {
        HistoricalBarModel *oldestBar = bars.firstObject;
        if ([oldestBar.date compare:requirements.earliestDate] == NSOrderedDescending) {
            validation.isValid = NO;
            validation.reason = @"Data does not go back far enough";
            if (result) *result = validation;
            return NO;
        }
    }
    
    // ✅ ALL CHECKS PASSED
    validation.reason = @"Valid";
    if (result) *result = validation;
    
    NSLog(@"✅ ChainDataValidator: Data is valid (%lu bars, timeframe=%ld)",
          (unsigned long)bars.count, (long)chainTimeframe);
    
    return YES;
}

+ (ValidationResult *)validateBars:(NSArray<HistoricalBarModel *> *)bars
                   forRequirements:(DataRequirements *)requirements {
    
    ValidationResult *validation = [[ValidationResult alloc] init];
    validation.isValid = YES;
    
    if (!bars || bars.count == 0) {
        validation.isValid = NO;
        validation.reason = @"No bars provided";
        return validation;
    }
    
    if (bars.count < requirements.minimumBars) {
        validation.isValid = NO;
        validation.hasSufficientBars = NO;
        validation.missingBars = requirements.minimumBars - bars.count;
        validation.reason = [NSString stringWithFormat:@"Need %ld bars, have %lu",
                            (long)requirements.minimumBars, (unsigned long)bars.count];
        return validation;
    }
    
    validation.hasSufficientBars = YES;
    validation.hasCompatibleTimeframe = YES;
    validation.reason = @"Valid";
    
    return validation;
}

@end
