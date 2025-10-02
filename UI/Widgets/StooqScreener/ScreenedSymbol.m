//
//  ScreenedSymbol.m
//  TradingApp
//

#import "ScreenedSymbol.h"

@implementation ScreenedSymbol

#pragma mark - Initialization

- (instancetype)init {
    self = [super init];
    if (self) {
        _isSelected = NO;
        _addedAtStep = -1;
        _metadata = [NSMutableDictionary dictionary];
    }
    return self;
}

#pragma mark - Factory Methods

+ (instancetype)symbolWithName:(NSString *)symbol addedAtStep:(NSInteger)addedAtStep {
    ScreenedSymbol *screenedSymbol = [[ScreenedSymbol alloc] init];
    screenedSymbol.symbol = symbol;
    screenedSymbol.addedAtStep = addedAtStep;
    return screenedSymbol;
}

+ (instancetype)symbolWithName:(NSString *)symbol
                  addedAtStep:(NSInteger)addedAtStep
                     metadata:(nullable NSDictionary *)metadata {
    ScreenedSymbol *screenedSymbol = [[ScreenedSymbol alloc] init];
    screenedSymbol.symbol = symbol;
    screenedSymbol.addedAtStep = addedAtStep;
    if (metadata) {
        screenedSymbol.metadata = [metadata mutableCopy];
    }
    return screenedSymbol;
}

#pragma mark - Metadata Helpers

- (void)setMetadataValue:(id)value forKey:(NSString *)key {
    if (!self.metadata) {
        self.metadata = [NSMutableDictionary dictionary];
    }
    self.metadata[key] = value;
}

- (nullable id)metadataValueForKey:(NSString *)key {
    return self.metadata[key];
}

- (BOOL)hasMetadataForKey:(NSString *)key {
    return self.metadata[key] != nil;
}

#pragma mark - Serialization

- (NSDictionary *)toDictionary {
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    
    dict[@"symbol"] = self.symbol ?: @"";
    dict[@"is_selected"] = @(self.isSelected);
    dict[@"added_at_step"] = @(self.addedAtStep);
    
    if (self.metadata && self.metadata.count > 0) {
        dict[@"metadata"] = [self.metadata copy];
    }
    
    return [dict copy];
}

+ (nullable instancetype)fromDictionary:(NSDictionary *)dict {
    if (!dict || !dict[@"symbol"]) {
        return nil;
    }
    
    ScreenedSymbol *symbol = [[ScreenedSymbol alloc] init];
    symbol.symbol = dict[@"symbol"];
    symbol.isSelected = [dict[@"is_selected"] boolValue];
    symbol.addedAtStep = [dict[@"added_at_step"] integerValue];
    
    if (dict[@"metadata"]) {
        symbol.metadata = [dict[@"metadata"] mutableCopy];
    }
    
    return symbol;
}

#pragma mark - Comparison

- (NSComparisonResult)compare:(ScreenedSymbol *)other {
    return [self.symbol compare:other.symbol];
}

#pragma mark - Description

- (NSString *)description {
    return [NSString stringWithFormat:@"<ScreenedSymbol: %@ (step: %ld, selected: %@, metadata: %lu)>",
            self.symbol,
            (long)self.addedAtStep,
            self.isSelected ? @"YES" : @"NO",
            (unsigned long)self.metadata.count];
}

@end
