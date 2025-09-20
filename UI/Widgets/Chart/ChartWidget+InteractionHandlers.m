//
//  ChartWidget+InteractionHandlers.m
//  TradingApp
//
//  Complete implementation of the interaction handlers - FIXED VERSION
//

#import "ChartWidget+InteractionHandlers.h"
#import "DataHub+MarketData.h"
#import "ChartObjectManagerWindow.h"  

@implementation ChartWidget (InteractionHandlers)

#pragma mark - PRIMARY HANDLERS - COMPLETE IMPLEMENTATION

- (void)handleSymbolChange:(NSString *)newSymbol forceReload:(BOOL)forceReload {
    NSLog(@"🔄 Handler: Symbol change to '%@' (force: %@)", newSymbol, forceReload ? @"YES" : @"NO");
    
    // Early exit if same symbol and not forced
    if (!forceReload && [newSymbol isEqualToString:self.currentSymbol]) {
        NSLog(@"⏭️ Same symbol, skipping");
        return;
    }
    
    // Store previous symbol for logging
    NSString *previousSymbol = self.currentSymbol;
    
    // ✅ COORDINATE SYMBOL DEPENDENCIES FIRST (before data load)
    [self coordinateSymbolDependencies:newSymbol];
    
    // ✅ UPDATE CURRENT SYMBOL
    self.currentSymbol = newSymbol;
    
    // ✅ UPDATE UI IMMEDIATELY
    [self processUIUpdate:ChartInvalidationSymbolChange];
    
    // ✅ LOAD NEW DATA
    if (newSymbol && newSymbol.length > 0) {
        [self loadDataWithCurrentSettings];
    }
    
    NSLog(@"✅ Handler: Symbol change from '%@' to '%@' initiated", previousSymbol ?: @"(none)", newSymbol);
}

- (void)handleTimeframeChange:(BarTimeframe)newTimeframe {
    NSLog(@"🔄 Handler: Timeframe change to %ld", (long)newTimeframe);
    
    if (newTimeframe == self.currentTimeframe) {
        NSLog(@"⏭️ Same timeframe, skipping");
        return;
    }
    
    BarTimeframe previousTimeframe = self.currentTimeframe;
    
    // ✅ UPDATE TIMEFRAME
    self.currentTimeframe = newTimeframe;
    
    // ✅ UPDATE DATE RANGE PREFERENCES FOR NEW TIMEFRAME
    if ([self respondsToSelector:@selector(updateDateRangeSegmentedForTimeframe:)]) {
        [self updateDateRangeSegmentedForTimeframe:newTimeframe];
    }
    
    // ✅ RESET VISIBLE RANGE FOR NEW TIMEFRAME
    if ([self respondsToSelector:@selector(resetVisibleRangeForTimeframe)]) {
        [self resetVisibleRangeForTimeframe];
    }
    
    // ✅ UPDATE UI IMMEDIATELY
    [self processUIUpdate:ChartInvalidationTimeframeChange];
    
    // ✅ LOAD NEW DATA
    if (self.currentSymbol && self.currentSymbol.length > 0) {
        [self loadDataWithCurrentSettings];
    }
    
    NSLog(@"✅ Handler: Timeframe change from %ld to %ld initiated",
          (long)previousTimeframe, (long)newTimeframe);
}

- (void)handleDataRangeChange:(NSInteger)newDays isExtension:(BOOL)isExtension {
    NSLog(@"🔄 Handler: Data range change to %ld days (extension: %@)",
          (long)newDays, isExtension ? @"YES" : @"NO");
    
    if (newDays == self.currentDateRangeDays) {
        NSLog(@"⏭️ Same range, skipping");
        return;
    }
    
    NSInteger previousDays = self.currentDateRangeDays;
    
    // ✅ UPDATE CURRENT RANGE
    self.currentDateRangeDays = newDays;
    
    // ✅ UPDATE UI IMMEDIATELY
    [self processUIUpdate:ChartInvalidationDataRangeChange];
    
    // ✅ LOAD NEW DATA
    if (self.currentSymbol && self.currentSymbol.length > 0) {
        [self loadDataWithCurrentSettings];
    }
    
    NSLog(@"✅ Handler: Data range change from %ld to %ld days initiated",
          (long)previousDays, (long)newDays);
}

- (void)handleTemplateChange:(ChartTemplateModel *)newTemplate {
    NSLog(@"🔄 Handler: Template change to '%@'", newTemplate.templateName);
    
    // ✅ Check if template system is available
    if (![self respondsToSelector:@selector(currentChartTemplate)]) {
        NSLog(@"⚠️ Template system not available, skipping template change");
        return;
    }
    
    // ✅ Get current template safely using KVC
    ChartTemplateModel *currentTemplate = [self valueForKey:@"currentChartTemplate"];
    
    if (newTemplate == currentTemplate ||
        [newTemplate.templateName isEqualToString:currentTemplate.templateName]) {
        NSLog(@"⏭️ Same template, skipping");
        return;
    }
    
    // ✅ UPDATE CURRENT TEMPLATE safely using KVC
    if ([self respondsToSelector:@selector(setCurrentChartTemplate:)]) {
        [self setValue:newTemplate forKey:@"currentChartTemplate"];
    }
    
    // ✅ APPLY TEMPLATE - check multiple possible method names
    if ([self respondsToSelector:@selector(applyChartTemplate:)]) {
        [self performSelector:@selector(applyChartTemplate:) withObject:newTemplate];
    } else if ([self respondsToSelector:@selector(applyTemplate:)]) {
        [self performSelector:@selector(applyTemplate:) withObject:newTemplate];
    } else {
        NSLog(@"⚠️ No template application method available");
    }
    
    // ✅ PROCESS INDICATOR RECALCULATION
    [self processIndicatorRecalculation:ChartInvalidationTemplateChange];
    
    // ✅ UPDATE UI
    [self processUIUpdate:ChartInvalidationTemplateChange];
    
    // ✅ SAVE AS LAST USED
    if ([self respondsToSelector:@selector(saveLastUsedTemplate:)]) {
        [self performSelector:@selector(saveLastUsedTemplate:) withObject:newTemplate];
    }
    
    NSLog(@"✅ Handler: Template change completed");
}

- (void)handleTradingHoursChange:(ChartTradingHours)newMode {
    NSLog(@"🔄 Handler: Trading hours change to %ld", (long)newMode);
    
    if (newMode == self.tradingHoursMode) {
        NSLog(@"⏭️ Same trading hours mode, skipping");
        return;
    }
    
    ChartTradingHours previousMode = self.tradingHoursMode;
    
    // ✅ UPDATE TRADING HOURS MODE
    self.tradingHoursMode = newMode;
    
    // ✅ THIS REQUIRES DATA RELOAD
    if (self.currentSymbol && self.currentSymbol.length > 0) {
        [self loadDataWithCurrentSettings];
    }
    
    NSLog(@"✅ Handler: Trading hours change from %ld to %ld initiated",
          (long)previousMode, (long)newMode);
}

- (void)handleStaticModeToggle:(BOOL)isStatic {
    NSLog(@"🔄 Handler: Static mode toggle to %@", isStatic ? @"ON" : @"OFF");
    
    if (isStatic == self.isStaticMode) {
        NSLog(@"⏭️ Same static mode, skipping");
        return;
    }
    
    BOOL previousMode = self.isStaticMode;
    
    // ✅ UPDATE STATIC MODE
    self.isStaticMode = isStatic;
    
    // ✅ UPDATE UI IMMEDIATELY
    if ([self respondsToSelector:@selector(updateStaticModeUI)]) {
        [self updateStaticModeUI];
    }
    
    if (!isStatic && self.currentSymbol && self.currentSymbol.length > 0) {
        // ✅ RE-ENABLE AUTO UPDATES - refresh data
        [self loadDataWithCurrentSettings];
    }
    
    NSLog(@"✅ Handler: Static mode change from %@ to %@",
          previousMode ? @"ON" : @"OFF", isStatic ? @"ON" : @"OFF");
}

#pragma mark - COMMON PROCESSING NODES - COMPLETE IMPLEMENTATION

- (void)processNewHistoricalData:(NSArray<HistoricalBarModel *> *)newData
                   invalidations:(ChartInvalidationFlags)flags {
    NSLog(@"🔄 Processing new historical data (%ld bars) with flags: %lu",
          (long)newData.count, (unsigned long)flags);
    
    if (!newData || newData.count == 0) {
        NSLog(@"❌ No data to process");
        return;
    }
    
    // ✅ UPDATE CHART DATA using KVC to access private property
    [self setValue:newData forKey:@"chartData"];
    
    // ✅ APPLY INVALIDATIONS IN DEPENDENCY ORDER
    [self applyInvalidations:flags];
    
    NSLog(@"✅ New historical data processed successfully");
}

- (void)processIndicatorRecalculation:(ChartInvalidationFlags)flags {
    NSLog(@"🔄 Processing indicator recalculation with flags: %lu", (unsigned long)flags);
    
    if (!(flags & ChartInvalidationIndicators)) {
        NSLog(@"⏭️ No indicator invalidation requested");
        return;
    }
    
    // ✅ RECALCULATE INDICATORS - check if method exists
    if ([self respondsToSelector:@selector(recalculateAllIndicators)]) {
        [self performSelector:@selector(recalculateAllIndicators)];
        NSLog(@"✅ Indicators recalculated");
    } else {
        NSLog(@"⚠️ recalculateAllIndicators method not available");
    }
    
    // ✅ REFRESH INDICATOR RENDERING - check if method exists
    if ([self respondsToSelector:@selector(refreshIndicatorsRendering)]) {
        [self performSelector:@selector(refreshIndicatorsRendering)];
        NSLog(@"✅ Indicator rendering refreshed");
    } else {
        NSLog(@"⚠️ refreshIndicatorsRendering method not available");
    }
    
    NSLog(@"✅ Indicator recalculation processed");
}

- (void)processViewportUpdate:(ChartInvalidationFlags)flags {
    NSLog(@"🔄 Processing viewport update with flags: %lu", (unsigned long)flags);
    
    if (!(flags & ChartInvalidationViewport)) {
        NSLog(@"⏭️ No viewport invalidation requested");
        return;
    }
    
    // ✅ SINGLE CALL: resetToInitialView handles everything
    if ([self respondsToSelector:@selector(resetToInitialView)]) {
        [self resetToInitialView]; // Questo già fa updateViewport + synchronizePanels
        NSLog(@"✅ Viewport reset completed (includes update + sync)");
    }
    
    NSLog(@"✅ Viewport update processed");
}
- (void)processUIUpdate:(ChartInvalidationFlags)flags {
    NSLog(@"🔄 Processing UI update with flags: %lu", (unsigned long)flags);
    
    if (!(flags & ChartInvalidationUI)) {
        NSLog(@"⏭️ No UI invalidation requested");
        return;
    }
    
    // ✅ UPDATE UI CONTROLS
    [self updateUIControlsForCurrentState];
    
    NSLog(@"✅ UI update processed");
}

#pragma mark - COORDINATION HELPERS - COMPLETE IMPLEMENTATION

- (void)coordinateSymbolDependencies:(NSString *)newSymbol {
    NSLog(@"🔗 Coordinating symbol dependencies for '%@'", newSymbol);
    if ([self.currentSymbol isEqualToString:[newSymbol uppercaseString]]){
        return;
    }
    
    self.currentSymbol = [newSymbol uppercaseString];
    // ✅ COORDINATE OBJECTS MANAGER
    if (self.objectsManager) {
        self.objectsManager.currentSymbol = newSymbol;
        NSLog(@"✅ ObjectsManager updated for symbol '%@'", newSymbol);
    }
    
    // ✅ REFRESH ALERTS FOR NEW SYMBOL
    if ([self respondsToSelector:@selector(refreshAlertsForCurrentSymbol)]) {
        [self refreshAlertsForCurrentSymbol];
    }
    
    // ✅ UPDATE OBJECTS PANEL IF OPEN
    if (self.objectsPanel && self.objectsPanel.objectManagerWindow) {
        if ([self.objectsPanel.objectManagerWindow respondsToSelector:@selector(updateForSymbol:)]) {
            [self.objectsPanel.objectManagerWindow performSelector:@selector(updateForSymbol:) withObject:newSymbol];
        }
    }
    
    // ✅ BROADCAST TO WIDGET CHAIN
    if ([self respondsToSelector:@selector(broadcastSymbolToChain:)]) {
        [self performSelector:@selector(broadcastSymbolToChain:) withObject:newSymbol];
    }
    
    NSLog(@"✅ Symbol dependencies coordinated");
}

- (void)updateUIControlsForCurrentState {
    NSLog(@"🎛️ Updating UI controls for current state");
    
    // ✅ UPDATE SYMBOL TEXT FIELD
    if (self.symbolTextField && self.currentSymbol) {
        self.symbolTextField.stringValue = self.currentSymbol;
    }
    
    // ✅ UPDATE TIMEFRAME SEGMENTED CONTROL
    if (self.timeframeSegmented) {
        NSInteger segmentIndex = [self barTimeframeToSegmentIndex:self.currentTimeframe];
        if (segmentIndex >= 0 && segmentIndex < self.timeframeSegmented.segmentCount) {
            [self.timeframeSegmented setSelectedSegment:segmentIndex];
        }
    }
    
    
    // ✅ UPDATE DATE RANGE CONTROLS
    if ([self respondsToSelector:@selector(updateDateRangeLabel)]) {
        [self performSelector:@selector(updateDateRangeLabel)];
    }
    
    // ✅ UPDATE STATIC MODE TOGGLE
    if (self.staticModeToggle) {
        self.staticModeToggle.state = self.isStaticMode ? NSControlStateValueOn : NSControlStateValueOff;
    }
    
    NSLog(@"✅ UI controls updated");
}

- (void)applyInvalidations:(ChartInvalidationFlags)flags {
    NSLog(@"🎯 Applying invalidations: %lu", (unsigned long)flags);
    
    // ✅ PROCESS IN DEPENDENCY ORDER
    
    // 1. Indicators first (depend on data)
    if (flags & ChartInvalidationIndicators) {
        [self processIndicatorRecalculation:flags];
    }
    
    // 2. Viewport next (depends on data and indicators)
    if (flags & ChartInvalidationViewport) {
        [self processViewportUpdate:flags];
    }
    
    // 3. UI last (depends on everything else)
    if (flags & ChartInvalidationUI) {
        [self processUIUpdate:flags];
    }
    
    // ✅ ALERTS AND OBJECTS are handled by coordinateSymbolDependencies
    
    NSLog(@"✅ Invalidations applied successfully");
}

#pragma mark - HELPER METHODS

- (ChartInvalidationFlags)invalidationFlagsForOperation:(NSString *)operation {
    if ([operation isEqualToString:@"symbolChange"]) {
        return ChartInvalidationSymbolChange;
    } else if ([operation isEqualToString:@"timeframeChange"]) {
        return ChartInvalidationTimeframeChange;
    } else if ([operation isEqualToString:@"dataRangeChange"] ||
               [operation isEqualToString:@"dataRangeExtension"]) {
        return ChartInvalidationDataRangeChange;
    } else if ([operation isEqualToString:@"tradingHoursChange"]) {
        return ChartInvalidationData | ChartInvalidationIndicators | ChartInvalidationViewport;
    } else if ([operation isEqualToString:@"templateChange"]) {
        return ChartInvalidationTemplateChange;
    } else if ([operation isEqualToString:@"dataRefresh"] ||
               [operation isEqualToString:@"staticModeDisabled"]) {
        // General refresh - update indicators and viewport but keep UI
        return ChartInvalidationData | ChartInvalidationIndicators | ChartInvalidationViewport;
    } else {
        // Unknown operation - do full invalidation
        NSLog(@"⚠️ Unknown operation '%@', using full invalidation", operation);
        return ChartInvalidationData | ChartInvalidationIndicators | ChartInvalidationViewport | ChartInvalidationUI;
    }
}

@end
