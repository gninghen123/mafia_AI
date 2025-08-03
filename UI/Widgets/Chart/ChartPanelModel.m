
//
//  ChartPanelModel.m
//  TradingApp
//

#import "ChartPanelModel.h"

@implementation ChartPanelModel

- (instancetype)init {
    self = [super init];
    if (self) {
        _panelId = [[NSUUID UUID] UUIDString];
        _title = @"Panel";
        _panelType = ChartPanelTypeSecondary;
        _heightRatio = 0.25;
        _minHeight = 100.0;
        _indicators = [NSMutableArray array];
        _isVisible = YES;
        _canBeDeleted = YES;
    }
    return self;
}

#pragma mark - Factory Methods

+ (instancetype)mainPanelWithTitle:(NSString *)title {
    ChartPanelModel *panel = [[ChartPanelModel alloc] init];
    panel.title = title;
    panel.panelType = ChartPanelTypeMain;
    panel.heightRatio = 0.6;  // Main panel gets more space
    panel.canBeDeleted = NO;  // Main panel cannot be deleted
    return panel;
}

+ (instancetype)secondaryPanelWithTitle:(NSString *)title {
    ChartPanelModel *panel = [[ChartPanelModel alloc] init];
    panel.title = title;
    panel.panelType = ChartPanelTypeSecondary;
    panel.heightRatio = 0.2;  // Secondary panels get less space
    panel.canBeDeleted = YES;
    return panel;
}

#pragma mark - Indicator Management

- (void)addIndicator:(id<IndicatorRenderer>)indicator {
    if (indicator && ![self.indicators containsObject:indicator]) {
        [self.indicators addObject:indicator];
        NSLog(@"📊 ChartPanelModel: Added indicator '%@' to panel '%@'",
              [indicator displayName], self.title);
    }
}

- (void)removeIndicator:(id<IndicatorRenderer>)indicator {
    if ([self.indicators containsObject:indicator]) {
        [self.indicators removeObject:indicator];
        NSLog(@"📊 ChartPanelModel: Removed indicator '%@' from panel '%@'",
              [indicator displayName], self.title);
    }
}

- (void)removeIndicatorAtIndex:(NSInteger)index {
    if (index >= 0 && index < self.indicators.count) {
        id<IndicatorRenderer> indicator = self.indicators[index];
        [self.indicators removeObjectAtIndex:index];
        NSLog(@"📊 ChartPanelModel: Removed indicator '%@' at index %ld",
              [indicator displayName], (long)index);
    }
}

- (BOOL)hasIndicatorOfType:(NSString *)type {
    for (id<IndicatorRenderer> indicator in self.indicators) {
        if ([[indicator indicatorType] isEqualToString:type]) {
            return YES;
        }
    }
    return NO;
}

- (nullable id<IndicatorRenderer>)indicatorOfType:(NSString *)type {
    for (id<IndicatorRenderer> indicator in self.indicators) {
        if ([[indicator indicatorType] isEqualToString:type]) {
            return indicator;
        }
    }
    return nil;
}

#pragma mark - Serialization

- (NSDictionary *)serialize {
    NSMutableDictionary *data = [NSMutableDictionary dictionary];
    
    data[@"panelId"] = self.panelId;
    data[@"title"] = self.title;
    data[@"panelType"] = @(self.panelType);
    data[@"heightRatio"] = @(self.heightRatio);
    data[@"minHeight"] = @(self.minHeight);
    data[@"isVisible"] = @(self.isVisible);
    data[@"canBeDeleted"] = @(self.canBeDeleted);
    
    // Serialize indicators
    NSMutableArray *indicatorsData = [NSMutableArray array];
    for (id<IndicatorRenderer> indicator in self.indicators) {
        NSMutableDictionary *indicatorData = [NSMutableDictionary dictionary];
        indicatorData[@"type"] = [indicator indicatorType];
        indicatorData[@"displayName"] = [indicator displayName];
        
        // Serialize indicator state if supported
        if ([indicator respondsToSelector:@selector(serializeState)]) {
            indicatorData[@"state"] = [indicator serializeState];
        }
        
        [indicatorsData addObject:indicatorData];
    }
    data[@"indicators"] = indicatorsData;
    
    return [data copy];
}

- (void)deserialize:(NSDictionary *)data {
    if (data[@"panelId"]) self.panelId = data[@"panelId"];
    if (data[@"title"]) self.title = data[@"title"];
    if (data[@"panelType"]) self.panelType = [data[@"panelType"] integerValue];
    if (data[@"heightRatio"]) self.heightRatio = [data[@"heightRatio"] doubleValue];
    if (data[@"minHeight"]) self.minHeight = [data[@"minHeight"] doubleValue];
    if (data[@"isVisible"]) self.isVisible = [data[@"isVisible"] boolValue];
    if (data[@"canBeDeleted"]) self.canBeDeleted = [data[@"canBeDeleted"] boolValue];
    
    // Note: Indicator deserialization would need indicator factory
    // For now, we'll handle this in the chart widget
    NSLog(@"📊 ChartPanelModel: Deserialized panel '%@' with %lu indicators",
          self.title, (unsigned long)[data[@"indicators"] count]);
}

#pragma mark - Debug

- (NSString *)description {
    return [NSString stringWithFormat:@"ChartPanelModel(id:%@, title:%@, type:%ld, indicators:%lu)",
            self.panelId, self.title, (long)self.panelType, (unsigned long)self.indicators.count];
}

@end
