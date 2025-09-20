//
//  ChartTemplateModels.m
//  TradingApp
//
//  Runtime models implementation for chart templates
//

#import "ChartTemplateModels.h"

// =======================================
// CHART PANEL TEMPLATE MODEL IMPLEMENTATION
// =======================================

@implementation ChartPanelTemplateModel

#pragma mark - Factory Methods

+ (instancetype)panelWithID:(NSString *)panelID
                       name:(nullable NSString *)name
            rootIndicatorType:(NSString *)rootType
                     height:(double)height
                      order:(NSInteger)order {
    
    ChartPanelTemplateModel *panel = [[ChartPanelTemplateModel alloc] init];
    panel.panelID = panelID ?: [[NSUUID UUID] UUIDString];
    panel.panelName = name;
    panel.rootIndicatorType = rootType;
    panel.relativeHeight = height;
    panel.displayOrder = order;
    panel.rootIndicatorParams = @{};
    panel.childIndicatorsData = @[];
    
    return panel;
}

+ (instancetype)securityPanelWithHeight:(double)height order:(NSInteger)order {
    return [self panelWithID:nil
                        name:@"Security"
             rootIndicatorType:@"SecurityIndicator"
                      height:height
                       order:order];
}

+ (instancetype)volumePanelWithHeight:(double)height order:(NSInteger)order {
    return [self panelWithID:nil
                        name:@"Volume"
             rootIndicatorType:@"VolumeIndicator"
                      height:height
                       order:order];
}

+ (instancetype)oscillatorPanelWithHeight:(double)height order:(NSInteger)order {
    return [self panelWithID:nil
                        name:@"Oscillator"
             rootIndicatorType:@"RSIIndicator"  // Default oscillator
                      height:height
                       order:order];
}

#pragma mark - Convenience Methods

- (NSString *)displayName {
    if (self.panelName && self.panelName.length > 0) {
        return self.panelName;
    }
    
    // Fallback to root indicator display name
    return [self rootIndicatorDisplayName];
}

- (NSString *)rootIndicatorDisplayName {
    // Map technical indicator types to display names
    static NSDictionary *displayNames = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        displayNames = @{
            @"SecurityIndicator": @"Security",
            @"CandlestickIndicator": @"Candlestick",
            @"OHLCIndicator": @"OHLC",
            @"LineIndicator": @"Line",
            @"VolumeIndicator": @"Volume",
            @"VolumeProfileIndicator": @"Volume Profile",
            @"RSIIndicator": @"RSI",
            @"MACDIndicator": @"MACD",
            @"StochasticIndicator": @"Stochastic",
            @"CCIIndicator": @"CCI",
            @"WilliamsRIndicator": @"Williams %R",
            @"CustomIndicator": @"Custom"
        };
    });
    
    NSString *displayName = displayNames[self.rootIndicatorType];
    return displayName ?: self.rootIndicatorType;
}

- (BOOL)isSecurityPanel {
    return [self.rootIndicatorType hasPrefix:@"Security"] ||
           [self.rootIndicatorType hasSuffix:@"Indicator"] &&
           ([self.rootIndicatorType isEqualToString:@"CandlestickIndicator"] ||
            [self.rootIndicatorType isEqualToString:@"OHLCIndicator"] ||
            [self.rootIndicatorType isEqualToString:@"LineIndicator"]);
}

- (BOOL)isVolumePanel {
    return [self.rootIndicatorType hasPrefix:@"Volume"];
}

- (BOOL)isOscillatorPanel {
    NSArray *oscillatorTypes = @[@"RSIIndicator", @"MACDIndicator", @"StochasticIndicator",
                                @"CCIIndicator", @"WilliamsRIndicator"];
    return [oscillatorTypes containsObject:self.rootIndicatorType];
}

#pragma mark - Serialization

- (NSDictionary *)toDictionary {
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    
    dict[@"panelID"] = self.panelID;
    dict[@"panelName"] = self.panelName ?: [NSNull null];
    dict[@"relativeHeight"] = @(self.relativeHeight);
    dict[@"displayOrder"] = @(self.displayOrder);
    dict[@"rootIndicatorType"] = self.rootIndicatorType;
    dict[@"rootIndicatorParams"] = self.rootIndicatorParams ?: @{};
    dict[@"childIndicatorsData"] = self.childIndicatorsData ?: @[];
    
    return [dict copy];
}

+ (instancetype)fromDictionary:(NSDictionary *)dictionary {
    ChartPanelTemplateModel *panel = [[ChartPanelTemplateModel alloc] init];
    
    panel.panelID = dictionary[@"panelID"] ?: [[NSUUID UUID] UUIDString];
    panel.panelName = [dictionary[@"panelName"] isEqual:[NSNull null]] ? nil : dictionary[@"panelName"];
    panel.relativeHeight = [dictionary[@"relativeHeight"] doubleValue];
    panel.displayOrder = [dictionary[@"displayOrder"] integerValue];
    panel.rootIndicatorType = dictionary[@"rootIndicatorType"];
    panel.rootIndicatorParams = dictionary[@"rootIndicatorParams"];
    panel.childIndicatorsData = dictionary[@"childIndicatorsData"];
    
    return panel;
}

#pragma mark - Working Copy

- (ChartPanelTemplateModel *)createWorkingCopy {
    ChartPanelTemplateModel *copy = [[ChartPanelTemplateModel alloc] init];
    
    copy.panelID = self.panelID;
    copy.panelName = [self.panelName copy];
    copy.relativeHeight = self.relativeHeight;
    copy.displayOrder = self.displayOrder;
    copy.rootIndicatorType = [self.rootIndicatorType copy];
    copy.rootIndicatorParams = [self.rootIndicatorParams copy];
    copy.childIndicatorsData = [self.childIndicatorsData copy];
    // Note: rootIndicator is runtime-only, not copied
    
    return copy;
}

- (void)updateFromWorkingCopy:(ChartPanelTemplateModel *)workingCopy {
    self.panelName = [workingCopy.panelName copy];
    self.relativeHeight = workingCopy.relativeHeight;
    self.displayOrder = workingCopy.displayOrder;
    self.rootIndicatorType = [workingCopy.rootIndicatorType copy];
    self.rootIndicatorParams = [workingCopy.rootIndicatorParams copy];
    self.childIndicatorsData = [workingCopy.childIndicatorsData copy];
    // Note: panelID should not be updated from working copy
}

@end

// =======================================
// CHART TEMPLATE MODEL IMPLEMENTATION
// =======================================

@implementation ChartTemplateModel

#pragma mark - Initialization

- (instancetype)init {
    self = [super init];
    if (self) {
        _templateID = [[NSUUID UUID] UUIDString];
        _templateName = @"Untitled Template";
        _isDefault = NO;
        _createdDate = [NSDate date];
        _modifiedDate = [NSDate date];
        _panels = [NSMutableArray array];
    }
    return self;
}

#pragma mark - Factory Methods

+ (instancetype)templateWithName:(NSString *)name {
    ChartTemplateModel *template = [[ChartTemplateModel alloc] init];
    template.templateName = name;
    return template;
}

+ (instancetype)templateWithID:(NSString *)templateID name:(NSString *)name {
    ChartTemplateModel *template = [[ChartTemplateModel alloc] init];
    template.templateID = templateID;
    template.templateName = name;
    return template;
}

+ (instancetype)defaultSecurityVolumeTemplate {
    ChartTemplateModel *template = [ChartTemplateModel templateWithName:@"Default"];
    template.isDefault = YES;
    
    // Security panel (80%)
    ChartPanelTemplateModel *securityPanel = [ChartPanelTemplateModel securityPanelWithHeight:0.80 order:0];
    [template addPanel:securityPanel];
    
    // Volume panel (20%)
    ChartPanelTemplateModel *volumePanel = [ChartPanelTemplateModel volumePanelWithHeight:0.20 order:1];
    [template addPanel:volumePanel];
    
    return template;
}

+ (instancetype)defaultSecurityVolumeOscillatorTemplate {
    ChartTemplateModel *template = [ChartTemplateModel templateWithName:@"Security + Volume + Oscillator"];
    
    // Security panel (60%)
    ChartPanelTemplateModel *securityPanel = [ChartPanelTemplateModel securityPanelWithHeight:0.60 order:0];
    [template addPanel:securityPanel];
    
    // Volume panel (20%)
    ChartPanelTemplateModel *volumePanel = [ChartPanelTemplateModel volumePanelWithHeight:0.20 order:1];
    [template addPanel:volumePanel];
    
    // Oscillator panel (20%)
    ChartPanelTemplateModel *oscillatorPanel = [ChartPanelTemplateModel oscillatorPanelWithHeight:0.20 order:2];
    [template addPanel:oscillatorPanel];
    
    return template;
}

+ (instancetype)defaultSecurityOnlyTemplate {
    ChartTemplateModel *template = [ChartTemplateModel templateWithName:@"Security Only"];
    
    // Security panel (100%)
    ChartPanelTemplateModel *securityPanel = [ChartPanelTemplateModel securityPanelWithHeight:1.00 order:0];
    [template addPanel:securityPanel];
    
    return template;
}

#pragma mark - Panel Management

- (void)addPanel:(ChartPanelTemplateModel *)panel {
    if (!panel) return;
    [self.panels addObject:panel];
}

- (void)removePanel:(ChartPanelTemplateModel *)panel {
    if (!panel) return;
    [self.panels removeObject:panel];
}

- (void)removePanelAtIndex:(NSUInteger)index {
    if (index < self.panels.count) {
        [self.panels removeObjectAtIndex:index];
    }
}

- (void)insertPanel:(ChartPanelTemplateModel *)panel atIndex:(NSUInteger)index {
    if (!panel) return;
    if (index > self.panels.count) index = self.panels.count;
    [self.panels insertObject:panel atIndex:index];
}

- (void)movePanelFromIndex:(NSUInteger)fromIndex toIndex:(NSUInteger)toIndex {
    if (fromIndex >= self.panels.count || toIndex >= self.panels.count) return;
    
    ChartPanelTemplateModel *panel = self.panels[fromIndex];
    [self.panels removeObjectAtIndex:fromIndex];
    [self.panels insertObject:panel atIndex:toIndex];
    
    // Update display orders
    for (NSUInteger i = 0; i < self.panels.count; i++) {
        self.panels[i].displayOrder = i;
    }
}

#pragma mark - Panel Access

- (NSArray<ChartPanelTemplateModel *> *)orderedPanels {
    return [self.panels sortedArrayUsingComparator:^NSComparisonResult(ChartPanelTemplateModel *panel1, ChartPanelTemplateModel *panel2) {
        return [@(panel1.displayOrder) compare:@(panel2.displayOrder)];
    }];
}

- (ChartPanelTemplateModel *)panelAtIndex:(NSUInteger)index {
    if (index < self.panels.count) {
        return self.panels[index];
    }
    return nil;
}

- (ChartPanelTemplateModel *)panelWithID:(NSString *)panelID {
    for (ChartPanelTemplateModel *panel in self.panels) {
        if ([panel.panelID isEqualToString:panelID]) {
            return panel;
        }
    }
    return nil;
}

- (ChartPanelTemplateModel *)securityPanel {
    for (ChartPanelTemplateModel *panel in self.panels) {
        if ([panel isSecurityPanel]) {
            return panel;
        }
    }
    return nil;
}

- (ChartPanelTemplateModel *)volumePanel {
    for (ChartPanelTemplateModel *panel in self.panels) {
        if ([panel isVolumePanel]) {
            return panel;
        }
    }
    return nil;
}

#pragma mark - Validation

- (BOOL)isValid {
    return [self isValidWithError:nil];
}

- (BOOL)isValidWithError:(NSError **)error {
    // Must have at least one panel
    if (self.panels.count == 0) {
        if (error) {
            *error = [NSError errorWithDomain:@"ChartTemplateValidation"
                                         code:1001
                                     userInfo:@{NSLocalizedDescriptionKey: @"Template must have at least one panel"}];
        }
        return NO;
    }
    
    // Check total height
    double totalHeight = [self totalHeight];
    if (fabs(totalHeight - 1.0) > 0.01) {
        if (error) {
            *error = [NSError errorWithDomain:@"ChartTemplateValidation"
                                         code:1002
                                     userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Panel heights must sum to 1.0 (currently %.3f)", totalHeight]}];
        }
        return NO;
    }
    
    return YES;
}

- (void)normalizeHeights {
    double totalHeight = [self totalHeight];
    if (totalHeight > 0 && fabs(totalHeight - 1.0) > 0.01) {
        // Normalize heights to sum to 1.0
        for (ChartPanelTemplateModel *panel in self.panels) {
            panel.relativeHeight = panel.relativeHeight / totalHeight;
        }
    }
}

#pragma mark - Convenience Methods

- (NSUInteger)panelCount {
    return self.panels.count;
}

- (double)totalHeight {
    double total = 0.0;
    for (ChartPanelTemplateModel *panel in self.panels) {
        total += panel.relativeHeight;
    }
    return total;
}

- (NSString *)panelSummary {
    NSMutableArray *summaryParts = [NSMutableArray array];
    
    NSArray<ChartPanelTemplateModel *> *orderedPanels = [self orderedPanels];
    for (ChartPanelTemplateModel *panel in orderedPanels) {
        NSString *part = [NSString stringWithFormat:@"%@ (%.0f%%)",
                         [panel displayName], panel.relativeHeight * 100];
        [summaryParts addObject:part];
    }
    
    return [summaryParts componentsJoinedByString:@" + "];
}

#pragma mark - Serialization

- (NSDictionary *)toDictionary {
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    
    dict[@"templateID"] = self.templateID;
    dict[@"templateName"] = self.templateName;
    dict[@"isDefault"] = @(self.isDefault);
    dict[@"createdDate"] = @([self.createdDate timeIntervalSince1970]);
    dict[@"modifiedDate"] = @([self.modifiedDate timeIntervalSince1970]);
    
    NSMutableArray *panelsArray = [NSMutableArray array];
    for (ChartPanelTemplateModel *panel in [self orderedPanels]) {
        [panelsArray addObject:[panel toDictionary]];
    }
    dict[@"panels"] = panelsArray;
    
    return [dict copy];
}

+ (instancetype)fromDictionary:(NSDictionary *)dictionary {
    ChartTemplateModel *template = [[ChartTemplateModel alloc] init];
    
    template.templateID = dictionary[@"templateID"] ?: [[NSUUID UUID] UUIDString];
    template.templateName = dictionary[@"templateName"];
    template.isDefault = [dictionary[@"isDefault"] boolValue];
    template.createdDate = [NSDate dateWithTimeIntervalSince1970:[dictionary[@"createdDate"] doubleValue]];
    template.modifiedDate = [NSDate dateWithTimeIntervalSince1970:[dictionary[@"modifiedDate"] doubleValue]];
    
    NSArray *panelsArray = dictionary[@"panels"];
    for (NSDictionary *panelDict in panelsArray) {
        ChartPanelTemplateModel *panel = [ChartPanelTemplateModel fromDictionary:panelDict];
        [template addPanel:panel];
    }
    
    return template;
}

#pragma mark - Working Copy

- (ChartTemplateModel *)createWorkingCopy {
    ChartTemplateModel *copy = [[ChartTemplateModel alloc] init];
    
    copy.templateID = self.templateID;
    copy.templateName = [self.templateName copy];
    copy.isDefault = self.isDefault;
    copy.createdDate = [self.createdDate copy];
    copy.modifiedDate = [self.modifiedDate copy];
    
    // Deep copy panels
    for (ChartPanelTemplateModel *panel in self.panels) {
        [copy addPanel:[panel createWorkingCopy]];
    }
    
    return copy;
}

- (void)updateFromWorkingCopy:(ChartTemplateModel *)workingCopy {
    self.templateName = [workingCopy.templateName copy];
    self.isDefault = workingCopy.isDefault;
    self.modifiedDate = [NSDate date]; // Update modification time
    
    // Replace panels with working copy panels
    [self.panels removeAllObjects];
    for (ChartPanelTemplateModel *workingPanel in workingCopy.panels) {
        [self addPanel:[workingPanel createWorkingCopy]];
    }
}

#pragma mark - Template Comparison

- (BOOL)isEqualToTemplate:(ChartTemplateModel *)otherTemplate {
    if (!otherTemplate) return NO;
    if (![self.templateID isEqualToString:otherTemplate.templateID]) return NO;
    if (![self.templateName isEqualToString:otherTemplate.templateName]) return NO;
    if (self.isDefault != otherTemplate.isDefault) return NO;
    if (self.panels.count != otherTemplate.panels.count) return NO;
    
    // Compare panels (simplified - could be more sophisticated)
    NSArray *ourPanels = [self orderedPanels];
    NSArray *theirPanels = [otherTemplate orderedPanels];
    
    for (NSUInteger i = 0; i < ourPanels.count; i++) {
        ChartPanelTemplateModel *ourPanel = ourPanels[i];
        ChartPanelTemplateModel *theirPanel = theirPanels[i];
        
        if (![ourPanel.rootIndicatorType isEqualToString:theirPanel.rootIndicatorType]) return NO;
        if (fabs(ourPanel.relativeHeight - theirPanel.relativeHeight) > 0.01) return NO;
    }
    
    return YES;
}

- (NSComparisonResult)compareByName:(ChartTemplateModel *)otherTemplate {
    return [self.templateName compare:otherTemplate.templateName];
}

@end
