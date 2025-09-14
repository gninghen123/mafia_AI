
//
//  ChartWidget+UnifiedSearch.m
//  TradingApp
//
//  Implementation of unified search field functionality
//

#import "ChartWidget+UnifiedSearch.h"
#import "ChartWidget.h"
#import "ChartWidget+SaveData.h"
#import "StorageMetadataCache.h"
#import "DataHub+SpotlightSearch.h"
#import "SpotlightModels.h"
#import <objc/runtime.h>

// Associated object key for search results
static const void *kCurrentSearchResultsKey = &kCurrentSearchResultsKey;

@implementation ChartWidget (UnifiedSearch)

#pragma mark - Associated Objects

- (NSArray<StorageMetadataItem *> *)currentSearchResults {
    return objc_getAssociatedObject(self, kCurrentSearchResultsKey);
}

- (void)setCurrentSearchResults:(NSArray<StorageMetadataItem *> *)results {
    objc_setAssociatedObject(self, kCurrentSearchResultsKey, results, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

#pragma mark - Search Field Management

- (void)setupUnifiedSearchField {
    if (!self.symbolTextField) {
        NSLog(@"⚠️ symbolTextField is nil - check IBOutlet connection");
        return;
    }
    
    // Setup delegates for search functionality
    self.symbolTextField.delegate = self;
    
    // If it's a combobox (has dropdown), setup data source
    if ([self.symbolTextField isKindOfClass:[NSComboBox class]]) {
        NSComboBox *comboBox = (NSComboBox *)self.symbolTextField;
        comboBox.dataSource = self;
        comboBox.delegate = self;
        comboBox.usesDataSource = YES;
        comboBox.completes = YES;
        comboBox.numberOfVisibleItems = 8;
    }
    
    // Setup initial appearance
    [self updateSearchFieldForMode];
    
    NSLog(@"✅ Unified search field setup completed");
}

- (void)updateSearchFieldForMode {
    if (!self.symbolTextField) return;
    
    if (self.isStaticMode) {
        // 🔵 STATIC MODE: Search saved data
        self.symbolTextField.placeholderString = @"Search saved data...";
        
        // Blue styling for static mode
        self.symbolTextField.wantsLayer = YES;
        self.symbolTextField.layer.cornerRadius = 12.0;
        self.symbolTextField.layer.borderColor = [NSColor systemBlueColor].CGColor;
        self.symbolTextField.layer.borderWidth = 1.5;
        
        NSLog(@"🔍 Search field configured for static mode (saved data)");
        
    } else {
        // 🔴 NORMAL MODE: Live symbol search + smart entry
        self.symbolTextField.placeholderString = @"Symbol or search...";
        
        // Accent color styling for normal mode
        self.symbolTextField.layer.cornerRadius = 6.0;
        self.symbolTextField.layer.borderColor = [NSColor controlAccentColor].CGColor;
        self.symbolTextField.layer.borderWidth = 1.0;
        
        NSLog(@"📈 Search field configured for normal mode (live symbols)");
    }
}

#pragma mark - Text Field Delegate (Override existing method in ChartWidget.m)

- (void)controlTextDidChange:(NSNotification *)notification {
    NSControl *control = notification.object;
    
    if (control != self.symbolTextField) return;
    
    NSString *searchTerm = control.stringValue;
    
    if (searchTerm.length == 0) {
        self.currentSearchResults = nil;
        return;
    }
    
    if (self.isStaticMode) {
        // 🔵 STATIC MODE: Search in saved data
        [self performSavedDataSearch:searchTerm];
    } else {
        // 🔴 NORMAL MODE: Search live symbols
        [self performLiveSymbolSearch:searchTerm];
    }
}

// This method should be updated in the main ChartWidget.m file
- (void)controlTextDidEndEditingUnified:(NSNotification *)notification {
    NSDictionary *info = notification.userInfo;
    NSNumber *movement = info[@"NSTextMovement"];
    
    if (movement.intValue != NSReturnTextMovement) return;
    
    NSControl *control = notification.object;
    
    // Handle base widget delegate first
    if (control == self.titleComboBox) {
        [super controlTextDidEndEditing:notification];
        return;
    }
    
    if (control == self.symbolTextField) {
        NSString *inputText = [control.stringValue stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        
        if (inputText.length == 0) return;
        
        if (self.isStaticMode) {
            // 🔵 STATIC MODE: Load best matching saved data
            [self executeStaticModeSearch:inputText];
        } else {
            // 🔴 NORMAL MODE: Execute symbol change (existing logic)
            [self executeNormalModeEntry:inputText];
        }
    }
}

#pragma mark - Static Mode Search Implementation

- (void)performSavedDataSearch:(NSString *)searchTerm {
    StorageMetadataCache *cache = [StorageMetadataCache sharedCache];
    NSArray<StorageMetadataItem *> *allItems = [cache allItems];
    
    if (allItems.count == 0) {
        self.currentSearchResults = @[];
        return;
    }
    
    // Flexible search predicate
    NSString *searchLower = searchTerm.lowercaseString;
    NSPredicate *predicate = [NSPredicate predicateWithFormat:
        @"symbol CONTAINS[c] %@ OR timeframe CONTAINS[c] %@ OR displayName CONTAINS[c] %@",
        searchLower, searchLower, searchLower];
    
    NSArray<StorageMetadataItem *> *matches = [allItems filteredArrayUsingPredicate:predicate];
    
    // Sort by relevance: exact symbol match first, then by recency
    self.currentSearchResults = [matches sortedArrayUsingComparator:^NSComparisonResult(StorageMetadataItem *obj1, StorageMetadataItem *obj2) {
        BOOL obj1Exact = [obj1.symbol.lowercaseString isEqualToString:searchLower];
        BOOL obj2Exact = [obj2.symbol.lowercaseString isEqualToString:searchLower];
        
        if (obj1Exact && !obj2Exact) return NSOrderedAscending;
        if (!obj1Exact && obj2Exact) return NSOrderedDescending;
        
        // Sort by modification time (newest first)
        return [@(obj2.fileModificationTime) compare:@(obj1.fileModificationTime)];
    }];
    
    // Limit results for UI performance
    if (self.currentSearchResults.count > 10) {
        self.currentSearchResults = [self.currentSearchResults subarrayWithRange:NSMakeRange(0, 10)];
    }
    
    NSLog(@"🔍 Found %ld matches for '%@' in saved data", (long)self.currentSearchResults.count, searchTerm);
    
    // Refresh dropdown if it's a combo box
    if ([self.symbolTextField isKindOfClass:[NSComboBox class]]) {
        [(NSComboBox *)self.symbolTextField reloadData];
    }
}

- (void)executeStaticModeSearch:(NSString *)searchTerm {
    [self performSavedDataSearch:searchTerm];
    
    if (self.currentSearchResults.count == 0) {
        [self showTemporaryMessage:[NSString stringWithFormat:@"❌ No saved data found for '%@'", searchTerm]];
        return;
    }
    
    // Load best match
    StorageMetadataItem *bestMatch = self.currentSearchResults.firstObject;
    
    NSLog(@"✅ Loading best match: %@", bestMatch.displayName);
    
    [self loadSavedDataFromFile:bestMatch.filePath completion:^(BOOL success, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (success) {
                NSString *icon = bestMatch.isContinuous ? @"📊" : @"📸";
                NSString *message = [NSString stringWithFormat:@"%@ %@ [%@]",
                                   icon, bestMatch.symbol, bestMatch.timeframe];
                [self showTemporaryMessage:message];
                
                // Update field to show loaded symbol
                self.symbolTextField.stringValue = bestMatch.symbol;
                
            } else {
                [self showTemporaryMessage:[NSString stringWithFormat:@"❌ Failed to load %@", bestMatch.displayName]];
                NSLog(@"❌ Error: %@", error.localizedDescription);
            }
        });
    }];
}

#pragma mark - Normal Mode Search Implementation

- (void)performLiveSymbolSearch:(NSString *)searchTerm {
    // TODO: Future integration with SearchQuote API
    NSLog(@"🔴 Live symbol search for '%@' (SearchQuote API needed)", searchTerm);
    
    // For now, clear results in normal mode
    self.currentSearchResults = @[];
    
    // Future: This would call DataHub/broker API to get live symbol matches
    // and populate self.currentSearchResults with symbol results
}

- (void)executeNormalModeEntry:(NSString *)inputText {
    // Use existing ChartWidget smart entry logic
    if ([inputText containsString:@","]) {
        [self processSmartSymbolInput:inputText];
    } else {
        [self symbolChanged:inputText];
    }
}

#pragma mark - Combo Box Data Source (for dropdown results)

- (NSInteger)numberOfItemsInComboBox:(NSComboBox *)comboBox {
    if (comboBox == (NSComboBox *)self.symbolTextField && self.currentSearchResults) {
        return self.currentSearchResults.count;
    }
    return 0;
}

- (id)comboBox:(NSComboBox *)comboBox objectValueForItemAtIndex:(NSInteger)index {
    if (comboBox == (NSComboBox *)self.symbolTextField &&
        self.currentSearchResults &&
        index < self.currentSearchResults.count) {
        
        StorageMetadataItem *item = self.currentSearchResults[index];
        
        if (self.isStaticMode) {
            // Rich display for saved data
            NSString *typeStr = item.isContinuous ? @"CONT" : @"SNAP";
            return [NSString stringWithFormat:@"%@ %@ [%@] %ld bars - %@",
                   item.symbol, item.timeframe, typeStr,
                   (long)item.barCount, item.dateRangeString ?: @""];
        } else {
            // Simple display for live symbols
            return item.symbol;
        }
    }
    return @"";
}

- (void)comboBoxSelectionDidChange:(NSNotification *)notification {
    NSComboBox *comboBox = notification.object;
    
    if (comboBox != (NSComboBox *)self.symbolTextField) return;
    
    NSInteger selectedIndex = comboBox.indexOfSelectedItem;
    if (selectedIndex >= 0 && selectedIndex < self.currentSearchResults.count) {
        StorageMetadataItem *selectedItem = self.currentSearchResults[selectedIndex];
        
        if (self.isStaticMode) {
            // Load selected saved data
            [self loadSavedDataFromFile:selectedItem.filePath completion:^(BOOL success, NSError *error) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (success) {
                        NSString *message = [NSString stringWithFormat:@"📊 Loaded %@", selectedItem.symbol];
                        [self showTemporaryMessage:message];
                        self.symbolTextField.stringValue = selectedItem.symbol;
                    }
                });
            }];
        } else {
            // Set symbol for live mode
            [self symbolChanged:selectedItem.symbol];
        }
    }
}

@end
