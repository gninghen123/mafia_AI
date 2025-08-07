
#import "Alert+CoreDataProperties.h"

// Alert+CoreDataClass.m
#import "Alert+CoreDataClass.h"
#import "Symbol+CoreDataClass.h"

@implementation Alert

#pragma mark - Convenience Methods

- (NSString *)symbolName {
    return self.symbol.symbol;
}

- (BOOL)shouldTriggerWithPrice:(double)currentPrice previousPrice:(double)previousPrice {
    if (!self.isActive || self.isTriggered) {
        return NO;
    }
    
    double triggerValue = self.triggerValue;
    NSString *condition = self.conditionString;
    
    if ([condition isEqualToString:@"above"]) {
        return currentPrice > triggerValue;
    } else if ([condition isEqualToString:@"below"]) {
        return currentPrice < triggerValue;
    } else if ([condition isEqualToString:@"crosses_above"]) {
        return previousPrice <= triggerValue && currentPrice > triggerValue;
    } else if ([condition isEqualToString:@"crosses_below"]) {
        return previousPrice >= triggerValue && currentPrice < triggerValue;
    }
    
    return NO;
}

- (NSString *)formattedTriggerValue {
    return [NSString stringWithFormat:@"%.2f", self.triggerValue];
}

- (NSString *)conditionDescription {
    if ([self.conditionString isEqualToString:@"above"]) {
        return @"above";
    } else if ([self.conditionString isEqualToString:@"below"]) {
        return @"below";
    } else if ([self.conditionString isEqualToString:@"crosses_above"]) {
        return @"crosses above";
    } else if ([self.conditionString isEqualToString:@"crosses_below"]) {
        return @"crosses below";
    }
    return self.conditionString;
}

#pragma mark - Description

- (NSString *)description {
    return [NSString stringWithFormat:@"<Alert: %@ %@ %.2f (%@)>",
            [self symbolName], [self conditionDescription], self.triggerValue,
            self.isActive ? @"active" : @"inactive"];
}

@end
