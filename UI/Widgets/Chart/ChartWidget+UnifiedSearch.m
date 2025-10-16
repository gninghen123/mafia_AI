
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
#import "ChartWidget+InteractionHandlers.h"  // ✅ AGGIUNTO: Import per handleSymbolChange:forceReload:
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

// (void)setupUnifiedSearchField - Metodo corretto

-(void)setupUnifiedSearchField {
    if (!self.symbolTextField) {
        NSLog(@"⚠️ symbolTextField is nil - check IBOutlet connection");
        return;
    }
    
    // 1. Assegna il Delegate Generale per tutte le funzionalità di editing/controllo.
    // Questo gestisce sia NSTextField che l'NSComboBox sottostante.
    self.symbolTextField.delegate = self;
    
    // 2. Se è un ComboBox, configura i delegate e data source specifici.
    if ([self.symbolTextField isKindOfClass:[NSComboBox class]]) {
        NSComboBox *comboBox = (NSComboBox *)self.symbolTextField;
        
        // Assegna la sorgente dati per popolare l'elenco a discesa.
        comboBox.dataSource = self;
        
        // NB: La riga 'comboBox.delegate = self;' è ridondante qui.
        // L'oggetto NSComboBox usa già il delegate assegnato a self.symbolTextField
        // per le funzionalità sia di NSTextFieldDelegate che di NSComboBoxDelegate.
        // Tuttavia, AppKit la gestisce correttamente anche se ripetuta.
        // Per massima chiarezza e per evitare ridondanza, la si può omettere.
        
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
        self.symbolTextField.layer.cornerRadius = 6.0;
        self.symbolTextField.layer.borderColor = [NSColor systemBlueColor].CGColor;
        self.symbolTextField.layer.borderWidth = 2.0;
        
        NSLog(@"🔍 Search field configured for static mode (saved data)");
        
    } else {
        // 🔴 NORMAL MODE: Live symbol search + smart entry
        self.symbolTextField.placeholderString = @"Symbol or search...";
        self.symbolTextField.wantsLayer = YES;

        // Accent color styling for normal mode
        self.symbolTextField.layer.cornerRadius = 6.0;
        self.symbolTextField.layer.borderColor = [NSColor controlAccentColor].CGColor;
        self.symbolTextField.layer.borderWidth = 1.0;
        
        NSLog(@"📈 Search field configured for normal mode (live symbols)");
    }
}

#pragma mark - Text Field Delegate

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
    // ✅ CORRECTED ARCHITECTURE: Use DataHub (which now properly uses DataManager → DownloadManager)
    DataHub *dataHub = [DataHub shared];
    
    // Use the corrected DataHub method that now follows proper architecture
    [dataHub searchSymbolsWithQuery:searchTerm
                               limit:8  // Limit for dropdown
                          completion:^(NSArray<SymbolSearchResult *> * _Nullable results, NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (error) {
                NSLog(@"🔴 Live symbol search error: %@", error.localizedDescription);
                self.currentSearchResults = @[];
            } else {
                // Convert SymbolSearchResult to StorageMetadataItem-like objects for consistent UI
                NSMutableArray<StorageMetadataItem *> *searchResults = [NSMutableArray array];
                
                for (SymbolSearchResult *result in results) {
                    // Create a minimal StorageMetadataItem for display consistency
                    StorageMetadataItem *displayItem = [[StorageMetadataItem alloc] init];
                    displayItem.symbol = result.symbol ?: @"";
                    displayItem.dataType = SavedChartDataTypeSnapshot; // Mark as not continuous for UI logic
                    displayItem.barCount = 0; // No bar count for live symbols
                    
                    // Add exchange info if available
                    if (result.exchange && result.exchange.length > 0) {
                        displayItem.timeframe = [NSString stringWithFormat:@"%@",
                                               result.companyName];
                    }
                    
                    [searchResults addObject:displayItem];
                }
                
                self.currentSearchResults = [searchResults copy];
                
                NSLog(@"🔴 Found %ld live symbols for '%@' via corrected architecture",
                      (long)results.count, searchTerm);
                
                // Refresh dropdown if it's a combo box
                if ([self.symbolTextField isKindOfClass:[NSComboBox class]]) {
                    [(NSComboBox *)self.symbolTextField reloadData];
                }
            }
        });
    }];
}

- (void)executeNormalModeEntry:(NSString *)inputText {
    // Use existing ChartWidget methods - avoid direct method calls that might not be visible
    
    if ([inputText containsString:@","]) {
        // Smart symbol input - check if method exists and call it
        if ([self respondsToSelector:@selector(processSmartSymbolInput:)]) {
            [self processSmartSymbolInput:inputText];
        } else {
            NSLog(@"⚠️ processSmartSymbolInput: method not available");
            // Fallback to simple symbol change
            [self handleSimpleSymbolChange:inputText];
        }
    } else {
        // Simple symbol change
        [self handleSimpleSymbolChange:inputText];
    }
}

// Helper method to handle symbol change using available public interface
- (void)handleSimpleSymbolChange:(NSString *)symbol {
    // Use the interaction handler if available (more robust)
    if ([self respondsToSelector:@selector(handleSymbolChange:forceReload:)]) {
        [self handleSymbolChange:symbol forceReload:NO];
    } else {
        // Fallback: directly set properties and load data
        self.currentSymbol = symbol;
        self.symbolTextField.stringValue = symbol;
        
        // Trigger data load if method exists
        if ([self respondsToSelector:@selector(loadDataWithCurrentSettings)]) {
            [self loadDataWithCurrentSettings];
        } else {
            NSLog(@"⚠️ No available method to load data for symbol: %@", symbol);
        }
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
            NSString *typeStr = [NSString stringWithFormat:@"%@ %@ [%@] %ld bars - %@",
                                 item.symbol, item.timeframe, item.isContinuous ? @"CONT" : @"SNAP",
                                 (long)item.barCount, item.dateRangeString ?: @""];
            
            return typeStr;
        } else {
            // Display for live symbol search results
            if (item.barCount == 0 && [item.timeframe isEqualToString:@"Live"]) {
                // This is a live search result, show company name if available
                return [NSString stringWithFormat:@"%@ - %@", item.symbol, item.timeframe];
            } else {
                // Fallback display
                return item.symbol;
            }
        }
    }
    return @"";
}



- (NSUInteger)comboBox:(NSComboBox *)comboBox indexOfItemWithStringValue:(NSString *)string {
    if (comboBox == (NSComboBox *)self.symbolTextField && self.currentSearchResults) {
        for (NSUInteger i = 0; i < self.currentSearchResults.count; i++) {
            StorageMetadataItem *item = self.currentSearchResults[i];
            
            if (self.isStaticMode) {
                // Per saved data, confronta il simbolo
                if ([item.symbol isEqualToString:string]) {
                    return i;
                }
            } else {
                // Per live symbols, confronta il simbolo
                if ([item.symbol isEqualToString:string]) {
                    return i;
                }
            }
        }
    }
    return NSNotFound;
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
                    } else {
                        NSString *errorMessage = [NSString stringWithFormat:@"❌ Failed to load %@", selectedItem.displayName];
                        [self showTemporaryMessage:errorMessage];
                    }
                });
            }];
        } else {
            // Load selected live symbol
            [self handleSimpleSymbolChange:selectedItem.symbol];
            self.symbolTextField.stringValue = selectedItem.symbol;
        }
    }
}

@end
