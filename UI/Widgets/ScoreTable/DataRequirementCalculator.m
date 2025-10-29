//
//  DataRequirementCalculator.m
//  TradingApp
//

#import "DataRequirementCalculator.h"
#import "DollarVolumeIndicator.h"
#import "AscendingLowsIndicator.h"
#import "BearTrapIndicator.h"
#import "UNRIndicator.h"
#import "PriceVsMAIndicator.h"
#import "VolumeSpikeIndicator.h"

@implementation DataRequirementCalculator

+ (DataRequirements *)calculateRequirementsForStrategy:(ScoringStrategy *)strategy {
    DataRequirements *req = [DataRequirements requirements];
    
    if (!strategy || strategy.indicators.count == 0) {
        NSLog(@"⚠️ DataRequirementCalculator: Invalid or empty strategy");
        req.minimumBars = 0;
        return req;
    }
    
    NSInteger maxBarsNeeded = 0;
    BOOL needsFundamentals = NO;
    
    // Analyze each indicator
    for (IndicatorConfig *indicator in strategy.indicators) {
        if (!indicator.isEnabled) continue;
        
        NSInteger barsForIndicator = [self minimumBarsForIndicator:indicator];
        maxBarsNeeded = MAX(maxBarsNeeded, barsForIndicator);
        
        // Check if fundamentals needed (future expansion)
        if ([indicator.indicatorType isEqualToString:@"PERatio"] ||
            [indicator.indicatorType isEqualToString:@"EPS"]) {
            needsFundamentals = YES;
        }
    }
    
    // Add 20% buffer for safety
    req.minimumBars = (NSInteger)(maxBarsNeeded * 1.2);
    req.timeframe = BarTimeframeDaily;  // Always daily for now
    req.needsFundamentals = needsFundamentals;
    
    // Calculate earliest date needed
    NSCalendar *calendar = [NSCalendar currentCalendar];
    req.earliestDate = [calendar dateByAddingUnit:NSCalendarUnitDay
                                            value:-(req.minimumBars + 10)
                                           toDate:[NSDate date]
                                          options:0];
    
    NSLog(@"📐 DataRequirements: %ld bars minimum, timeframe=%ld",
          (long)req.minimumBars, (long)req.timeframe);
    
    return req;
}

+ (NSInteger)minimumBarsForIndicator:(IndicatorConfig *)indicator {
    // Get calculator for this indicator type
    id<IndicatorCalculator> calculator = [self calculatorForType:indicator.indicatorType];
    
    if (!calculator) {
        NSLog(@"⚠️ Unknown indicator type: %@, assuming 20 bars", indicator.indicatorType);
        return 20;
    }
    
    return [calculator minimumBarsRequired];
}

+ (id<IndicatorCalculator>)calculatorForType:(NSString *)indicatorType {
    static NSDictionary<NSString *, Class> *calculatorRegistry = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        calculatorRegistry = @{
            @"DollarVolume": [DollarVolumeIndicator class],
            @"AscendingLows": [AscendingLowsIndicator class],
            @"BearTrap": [BearTrapIndicator class],
            @"UNR": [UNRIndicator class],
            @"PriceVsMA": [PriceVsMAIndicator class],
            @"VolumeSpike": [VolumeSpikeIndicator class]
        };
    });
    
    Class calculatorClass = calculatorRegistry[indicatorType];
    if (calculatorClass) {
        return [[calculatorClass alloc] init];
    }
    
    return nil;
}

@end
