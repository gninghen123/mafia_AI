//
//  AlertEntry.m
//  TradingApp
//

#import "AlertEntry.h"

@implementation AlertEntry

+ (instancetype)alertWithSymbol:(NSString *)symbol
                    targetPrice:(double)targetPrice
                           type:(AlertType)type {
    AlertEntry *alert = [[AlertEntry alloc] init];
    alert.alertID = [[NSUUID UUID] UUIDString];
    alert.symbol = symbol;
    alert.targetPrice = targetPrice;
    alert.alertType = type;
    alert.status = AlertStatusActive;
    alert.creationDate = [NSDate date];
    return alert;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _alertID = [[NSUUID UUID] UUIDString];
        _creationDate = [NSDate date];
        _status = AlertStatusActive;
    }
    return self;
}

#pragma mark - NSCoding

- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeObject:self.alertID forKey:@"alertID"];
    [coder encodeObject:self.symbol forKey:@"symbol"];
    [coder encodeDouble:self.targetPrice forKey:@"targetPrice"];
    [coder encodeInteger:self.alertType forKey:@"alertType"];
    [coder encodeInteger:self.status forKey:@"status"];
    [coder encodeObject:self.creationDate forKey:@"creationDate"];
    [coder encodeObject:self.triggerDate forKey:@"triggerDate"];
    [coder encodeObject:self.notes forKey:@"notes"];
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    self = [super init];
    if (self) {
        _alertID = [coder decodeObjectForKey:@"alertID"];
        _symbol = [coder decodeObjectForKey:@"symbol"];
        _targetPrice = [coder decodeDoubleForKey:@"targetPrice"];
        _alertType = [coder decodeIntegerForKey:@"alertType"];
        _status = [coder decodeIntegerForKey:@"status"];
        _creationDate = [coder decodeObjectForKey:@"creationDate"];
        _triggerDate = [coder decodeObjectForKey:@"triggerDate"];
        _notes = [coder decodeObjectForKey:@"notes"];
    }
    return self;
}

#pragma mark - NSCopying

- (id)copyWithZone:(NSZone *)zone {
    AlertEntry *copy = [[AlertEntry allocWithZone:zone] init];
    copy.alertID = [self.alertID copy];
    copy.symbol = [self.symbol copy];
    copy.targetPrice = self.targetPrice;
    copy.alertType = self.alertType;
    copy.status = self.status;
    copy.creationDate = [self.creationDate copy];
    copy.triggerDate = [self.triggerDate copy];
    copy.notes = [self.notes copy];
    return copy;
}

#pragma mark - Utility Methods

- (NSString *)alertTypeString {
    switch (self.alertType) {
        case AlertTypeAbove:
            return @"Sopra";
        case AlertTypeBelow:
            return @"Sotto";
        default:
            return @"";
    }
}

- (NSString *)statusString {
    switch (self.status) {
        case AlertStatusActive:
            return @"Attivo";
        case AlertStatusTriggered:
            return @"Scattato";
        case AlertStatusDisabled:
            return @"Disabilitato";
        default:
            return @"";
    }
}

- (BOOL)shouldTriggerForPrice:(double)currentPrice {
    if (self.status != AlertStatusActive) {
        return NO;
    }
    
    if (self.alertType == AlertTypeAbove) {
        return currentPrice >= self.targetPrice;
    } else {
        return currentPrice <= self.targetPrice;
    }
}

- (NSDictionary *)toDictionary {
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    dict[@"alertID"] = self.alertID;
    dict[@"symbol"] = self.symbol;
    dict[@"targetPrice"] = @(self.targetPrice);
    dict[@"alertType"] = @(self.alertType);
    dict[@"status"] = @(self.status);
    dict[@"creationDate"] = @([self.creationDate timeIntervalSince1970]);
    
    if (self.triggerDate) {
        dict[@"triggerDate"] = @([self.triggerDate timeIntervalSince1970]);
    }
    if (self.notes) {
        dict[@"notes"] = self.notes;
    }
    
    return [dict copy];
}

+ (instancetype)fromDictionary:(NSDictionary *)dict {
    AlertEntry *alert = [[AlertEntry alloc] init];
    alert.alertID = dict[@"alertID"];
    alert.symbol = dict[@"symbol"];
    alert.targetPrice = [dict[@"targetPrice"] doubleValue];
    alert.alertType = [dict[@"alertType"] integerValue];
    alert.status = [dict[@"status"] integerValue];
    alert.creationDate = [NSDate dateWithTimeIntervalSince1970:[dict[@"creationDate"] doubleValue]];
    
    if (dict[@"triggerDate"]) {
        alert.triggerDate = [NSDate dateWithTimeIntervalSince1970:[dict[@"triggerDate"] doubleValue]];
    }
    if (dict[@"notes"]) {
        alert.notes = dict[@"notes"];
    }
    
    return alert;
}

@end
