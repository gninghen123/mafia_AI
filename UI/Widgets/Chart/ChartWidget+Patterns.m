//
//  ChartWidget+Patterns.m
//  TradingApp
//
//  Extension for Chart Patterns integration
//

#import "ChartWidget+Patterns.h"
#import "ChartPatternManager.h"
#import "DataHub.h"
#import "DataHub+ChartPatterns.h"

@implementation ChartWidget (Patterns)

#pragma mark - Interactive Pattern Creation

- (void)createPatternLabelInteractive {
    ChartPatternManager *manager = [ChartPatternManager shared];
    
    [manager showPatternCreationDialogForChartWidget:self completion:^(ChartPatternModel *pattern, BOOL cancelled) {
        if (!cancelled && pattern) {
            NSLog(@"✅ ChartWidget: Pattern created successfully: %@", pattern.patternType);
        }
    }];
}

- (void)createPatternLabel:(NSString *)patternType
                     notes:(nullable NSString *)notes
                completion:(void(^)(BOOL success, ChartPatternModel * _Nullable pattern, NSError * _Nullable error))completion {
    
    if (!patternType) {
        NSError *error = [NSError errorWithDomain:@"ChartWidgetPatterns"
                                             code:1001
                                         userInfo:@{NSLocalizedDescriptionKey: @"Pattern type is required"}];
        if (completion) completion(NO, nil, error);
        return;
    }
    
    // Validate chart has data
    NSArray<HistoricalBarModel *> *chartData = [self currentChartData];
    if (!self.currentSymbol || !chartData || chartData.count == 0) {
        NSError *error = [NSError errorWithDomain:@"ChartWidgetPatterns"
                                             code:1002
                                         userInfo:@{NSLocalizedDescriptionKey: @"No chart data available"}];
        if (completion) completion(NO, nil, error);
        return;
    }
    
    // Create pattern using manager
    ChartPatternManager *manager = [ChartPatternManager shared];
    ChartPatternModel *pattern = [manager createPatternFromChartWidget:self
                                                           patternType:patternType
                                                                 notes:notes];
    
    if (pattern) {
        NSLog(@"✅ ChartWidget: Created pattern '%@' for %@", patternType, self.currentSymbol);
        if (completion) completion(YES, pattern, nil);
    } else {
        NSError *error = [NSError errorWithDomain:@"ChartWidgetPatterns"
                                             code:1003
                                         userInfo:@{NSLocalizedDescriptionKey: @"Failed to create pattern"}];
        if (completion) completion(NO, nil, error);
    }
}

#pragma mark - Pattern Loading

- (void)loadPattern:(ChartPatternModel *)pattern {
    if (!pattern) {
        NSLog(@"❌ ChartWidget: Cannot load nil pattern");
        return;
    }
    
    ChartPatternManager *manager = [ChartPatternManager shared];
    BOOL success = [manager loadPatternIntoChartWidget:pattern chartWidget:self];
    
    if (success) {
        NSLog(@"✅ ChartWidget: Loaded pattern '%@'", pattern.patternType);
    } else {
        NSLog(@"❌ ChartWidget: Failed to load pattern '%@'", pattern.patternType);
        
        // Show error alert
        dispatch_async(dispatch_get_main_queue(), ^{
            NSAlert *alert = [[NSAlert alloc] init];
            alert.messageText = @"Failed to Load Pattern";
            alert.informativeText = [NSString stringWithFormat:@"Could not load pattern '%@'. The saved chart data may be missing or corrupted.", pattern.patternType];
            [alert addButtonWithTitle:@"OK"];
            [alert runModal];
        });
    }
}

- (void)showPatternLibraryInteractive {
    if (!self.currentSymbol) {
        NSAlert *alert = [[NSAlert alloc] init];
        alert.messageText = @"No Symbol Loaded";
        alert.informativeText = @"Please load a symbol first to view its patterns.";
        [alert addButtonWithTitle:@"OK"];
        [alert runModal];
        return;
    }
    
    // Get patterns for current symbol
    NSArray<ChartPatternModel *> *patterns = [self getPatternsForCurrentSymbol];
    
    if (patterns.count == 0) {
        NSAlert *alert = [[NSAlert alloc] init];
        alert.messageText = @"No Patterns Found";
        alert.informativeText = [NSString stringWithFormat:@"No patterns found for %@.", self.currentSymbol];
        [alert addButtonWithTitle:@"OK"];
        [alert runModal];
        return;
    }
    
    // Create selection dialog
    NSAlert *selectionAlert = [[NSAlert alloc] init];
    selectionAlert.messageText = @"Load Pattern";
    selectionAlert.informativeText = [NSString stringWithFormat:@"Select a pattern to load for %@:", self.currentSymbol];
    [selectionAlert addButtonWithTitle:@"Load"];
    [selectionAlert addButtonWithTitle:@"Cancel"];
    
    // Create popup button for pattern selection
    NSPopUpButton *patternSelector = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(0, 0, 500, 25)];
    
    for (ChartPatternModel *pattern in patterns) {
        NSString *displayTitle = pattern.displayInfo;
        [patternSelector addItemWithTitle:displayTitle];
        patternSelector.lastItem.representedObject = pattern;
    }
    
    selectionAlert.accessoryView = patternSelector;
    
    NSModalResponse response = [selectionAlert runModal];
    if (response == NSAlertFirstButtonReturn) {
        ChartPatternModel *selectedPattern = patternSelector.selectedItem.representedObject;
        if (selectedPattern) {
            [self loadPattern:selectedPattern];
        }
    }
}

#pragma mark - Context Menu Integration

- (void)addPatternMenuItemsToMenu:(NSMenu *)menu {
    [menu addItem:[NSMenuItem separatorItem]];
    
    // Create Pattern Label
    NSMenuItem *createPatternItem = [[NSMenuItem alloc] initWithTitle:@"📋 Create Pattern Label..."
                                                               action:@selector(contextMenuCreatePatternLabel:)
                                                        keyEquivalent:@""];
    createPatternItem.target = self;
    [menu addItem:createPatternItem];
    
    // Load Pattern
    NSMenuItem *loadPatternItem = [[NSMenuItem alloc] initWithTitle:@"📂 Load Pattern..."
                                                             action:@selector(contextMenuShowPatternLibrary:)
                                                      keyEquivalent:@""];
    loadPatternItem.target = self;
    [menu addItem:loadPatternItem];
    
    // Manage Patterns
    NSMenuItem *managePatternsItem = [[NSMenuItem alloc] initWithTitle:@"⚙️ Manage Patterns..."
                                                                action:@selector(contextMenuManagePatterns:)
                                                         keyEquivalent:@""];
    managePatternsItem.target = self;
    [menu addItem:managePatternsItem];
}

#pragma mark - Context Menu Actions

- (IBAction)contextMenuCreatePatternLabel:(id)sender {
    [self createPatternLabelInteractive];
}

- (IBAction)contextMenuShowPatternLibrary:(id)sender {
    [self showPatternLibraryInteractive];
}

- (IBAction)contextMenuManagePatterns:(id)sender {
    [self showPatternManagementWindow];
}

#pragma mark - Pattern Management

- (NSArray<ChartPatternModel *> *)getPatternsForCurrentSymbol {
    if (!self.currentSymbol) {
        return @[];
    }
    
    ChartPatternManager *manager = [ChartPatternManager shared];
    return [manager getPatternsForSymbol:self.currentSymbol];
}

- (void)showPatternManagementWindow {
    // For now, show a simple info dialog with pattern statistics
    // In the future, this could open a dedicated pattern management window
    
    ChartPatternManager *manager = [ChartPatternManager shared];
    NSInteger totalPatterns = [manager getTotalPatternCount];
    NSDictionary<NSString *, NSNumber *> *stats = [manager getPatternStatistics];
    
    NSMutableString *message = [NSMutableString string];
    [message appendFormat:@"Total Patterns: %ld\n\n", (long)totalPatterns];
    
    if (stats.count > 0) {
        [message appendString:@"Patterns by Type:\n"];
        NSArray *sortedTypes = [stats.allKeys sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
        for (NSString *type in sortedTypes) {
            [message appendFormat:@"• %@: %@\n", type, stats[type]];
        }
    } else {
        [message appendString:@"No patterns created yet."];
    }
    
    if (self.currentSymbol) {
        NSArray<ChartPatternModel *> *symbolPatterns = [self getPatternsForCurrentSymbol];
        [message appendFormat:@"\nPatterns for %@: %ld", self.currentSymbol, (long)symbolPatterns.count];
    }
    
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"Pattern Management";
    alert.informativeText = message;
    [alert addButtonWithTitle:@"Cleanup Orphaned"];
    [alert addButtonWithTitle:@"Close"];
    
    NSModalResponse response = [alert runModal];
    if (response == NSAlertFirstButtonReturn) {
        // Run cleanup
        [manager cleanupOrphanedPatternsWithCompletion:^(NSInteger deletedCount, NSError *error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                NSAlert *resultAlert = [[NSAlert alloc] init];
                if (error) {
                    resultAlert.messageText = @"Cleanup Failed";
                    resultAlert.informativeText = error.localizedDescription;
                } else {
                    resultAlert.messageText = @"Cleanup Complete";
                    resultAlert.informativeText = [NSString stringWithFormat:@"Deleted %ld orphaned patterns.", (long)deletedCount];
                }
                [resultAlert addButtonWithTitle:@"OK"];
                [resultAlert runModal];
            });
        }];
    }
}

@end
