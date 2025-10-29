//
//  ScoreTableWidget+Chain.m
//  TradingApp
//
//  Widget Chain Integration
//

#import "ScoreTableWidget.h"
#import "ChainDataValidator.h"
#import "DataRequirementCalculator.h"

@implementation ScoreTableWidget (Chain)

#pragma mark - Chain Integration

- (void)handleChainAction:(NSString *)action withData:(id)data fromWidget:(BaseWidget *)sender {
    if ([action isEqualToString:@"loadScreenerData"]) {
        [self loadScreenerDataFromChain:data fromWidget:sender];
    } else {
        [super handleChainAction:action withData:data fromWidget:sender];
    }
}

- (void)loadScreenerDataFromChain:(NSDictionary *)chainData fromWidget:(BaseWidget *)sender {
    NSLog(@"🔗 Received screener data from %@", NSStringFromClass([sender class]));
    
    // Extract symbols data
    NSDictionary *symbolsData = chainData[@"symbolsData"];
    if (!symbolsData || symbolsData.count == 0) {
        NSLog(@"⚠️ No symbol data in chain");
        [self showChainFeedback:@"❌ No data received"];
        return;
    }
    
    // Calculate requirements
    DataRequirements *requirements = [DataRequirementCalculator calculateRequirementsForStrategy:self.currentStrategy];
    
    // Validate and categorize
    NSMutableDictionary *validData = [NSMutableDictionary dictionary];
    NSMutableArray *needsMoreData = [NSMutableArray array];
    
    for (NSString *symbol in symbolsData.allKeys) {
        NSDictionary *symbolData = symbolsData[symbol];
        NSArray<HistoricalBarModel *> *bars = symbolData[@"historicalBars"];
        
        ValidationResult *validation = nil;
        BOOL isValid = [ChainDataValidator validateChainData:symbolData
                                             forRequirements:requirements
                                                      result:&validation];
        
        if (isValid) {
            validData[symbol] = bars;
            self.symbolDataCache[symbol] = bars;  // Cache it
            NSLog(@"✅ %@ - Valid from chain (%lu bars)", symbol, (unsigned long)bars.count);
        } else {
            [needsMoreData addObject:symbol];
            NSLog(@"⚠️ %@ - Needs more data: %@", symbol, validation.reason);
        }
    }
    
    // Update symbol input
    NSMutableArray *allSymbols = [NSMutableArray arrayWithArray:validData.allKeys];
    [allSymbols addObjectsFromArray:needsMoreData];
    self.symbolInputTextView.string = [allSymbols componentsJoinedByString:@", "];
    
    // Calculate scores for valid symbols immediately
    if (validData.count > 0) {
        [self calculateScoresWithData:validData];
    }
    
    // Fetch missing data if needed
    if (needsMoreData.count > 0) {
        [self showLoadingForSymbols:needsMoreData];
        [self fetchDataForSymbols:needsMoreData
                     requirements:requirements
                       completion:^(NSDictionary *additionalData, NSError *error) {
            if (error) {
                NSLog(@"❌ Error fetching additional data: %@", error);
                [self hideLoadingForSymbols:needsMoreData];
                return;
            }
            
            // Merge with existing valid data
            NSMutableDictionary *allData = [NSMutableDictionary dictionaryWithDictionary:validData];
            [allData addEntriesFromDictionary:additionalData];
            
            // Recalculate all scores
            [self calculateScoresWithData:allData];
            [self hideLoadingForSymbols:needsMoreData];
        }];
    }
    
    NSString *message = [NSString stringWithFormat:@"📊 Loaded %lu symbols from screener", (unsigned long)symbolsData.count];
    [self showChainFeedback:message];
}

- (void)showLoadingForSymbols:(NSArray<NSString *> *)symbols {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.statusLabel.stringValue = [NSString stringWithFormat:@"Loading %lu additional symbols...", (unsigned long)symbols.count];
        [self.loadingIndicator startAnimation:nil];
    });
}

- (void)hideLoadingForSymbols:(NSArray<NSString *> *)symbols {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.loadingIndicator stopAnimation:nil];
    });
}

#pragma mark - Export

- (void)exportToCSV {
    if (self.scoreResults.count == 0) {
        NSLog(@"⚠️ No results to export");
        
        NSAlert *alert = [[NSAlert alloc] init];
        alert.messageText = @"No Data";
        alert.informativeText = @"No scores available to export.";
        [alert addButtonWithTitle:@"OK"];
        [alert runModal];
        return;
    }
    
    // Build CSV content
    NSMutableString *csv = [NSMutableString string];
    
    // Header row
    NSMutableArray *headers = [NSMutableArray arrayWithObjects:@"Symbol", @"Total Score", nil];
    for (IndicatorConfig *indicator in self.currentStrategy.indicators) {
        if (indicator.isEnabled) {
            [headers addObject:indicator.displayName];
        }
    }
    [csv appendFormat:@"%@\n", [headers componentsJoinedByString:@","]];
    
    // Data rows
    for (ScoreResult *result in self.scoreResults) {
        NSMutableArray *row = [NSMutableArray array];
        
        [row addObject:result.symbol];
        [row addObject:[NSString stringWithFormat:@"%.2f", result.totalScore]];
        
        for (IndicatorConfig *indicator in self.currentStrategy.indicators) {
            if (indicator.isEnabled) {
                CGFloat score = [result scoreForIndicator:indicator.indicatorType];
                [row addObject:[NSString stringWithFormat:@"%.2f", score]];
            }
        }
        
        [csv appendFormat:@"%@\n", [row componentsJoinedByString:@","]];
    }
    
    // Save dialog
    NSSavePanel *savePanel = [NSSavePanel savePanel];
    savePanel.allowedFileTypes = @[@"csv"];
    savePanel.nameFieldStringValue = @"ScoreTable_Export.csv";
    
    [savePanel beginSheetModalForWindow:self.view.window completionHandler:^(NSModalResponse result) {
        if (result == NSModalResponseOK) {
            NSURL *url = savePanel.URL;
            NSError *error;
            BOOL success = [csv writeToURL:url atomically:YES encoding:NSUTF8StringEncoding error:&error];
            
            if (success) {
                NSLog(@"✅ Exported to: %@", url.path);
                self.statusLabel.stringValue = @"Export successful";
            } else {
                NSLog(@"❌ Export failed: %@", error);
                
                NSAlert *alert = [[NSAlert alloc] init];
                alert.messageText = @"Export Failed";
                alert.informativeText = error.localizedDescription;
                [alert addButtonWithTitle:@"OK"];
                [alert runModal];
            }
        }
    }];
}

#pragma mark - Notifications

- (void)handleDataHubUpdate:(NSNotification *)notification {
    // Could be used to auto-refresh when new data arrives
    // For now, user must click refresh manually
}

@end
