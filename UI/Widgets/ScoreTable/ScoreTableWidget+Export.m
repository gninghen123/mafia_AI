//
//  ScoreTableWidget+Export.m
//  TradingApp
//
//  CSV Export to Clipboard
//

#import "ScoreTableWidget+Export.h"
#import <AppKit/AppKit.h>

@implementation ScoreTableWidget (Export)

#pragma mark - Export to Clipboard

- (void)exportSelectionToClipboard:(id)sender {
    NSIndexSet *selectedRows = self.scoreTableView.selectedRowIndexes;
    
    if (selectedRows.count == 0) {
        NSLog(@"⚠️ No rows selected for export");
        self.statusLabel.stringValue = @"No rows selected";
        return;
    }
    
    NSMutableArray<ScoreResult *> *selectedResults = [NSMutableArray array];
    [selectedRows enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop) {
        if (idx < self.scoreResults.count) {
            [selectedResults addObject:self.scoreResults[idx]];
        }
    }];
    
    [self exportResultsToClipboard:selectedResults];
    
    self.statusLabel.stringValue = [NSString stringWithFormat:@"Exported %lu rows to clipboard", (unsigned long)selectedResults.count];
    NSLog(@"✅ Exported %lu selected rows to clipboard", (unsigned long)selectedResults.count);
}

- (void)exportAllToClipboard:(id)sender {
    if (self.scoreResults.count == 0) {
        NSLog(@"⚠️ No data to export");
        self.statusLabel.stringValue = @"No data to export";
        return;
    }
    
    [self exportResultsToClipboard:self.scoreResults];
    
    self.statusLabel.stringValue = [NSString stringWithFormat:@"Exported %lu rows to clipboard", (unsigned long)self.scoreResults.count];
    NSLog(@"✅ Exported all %lu rows to clipboard", (unsigned long)self.scoreResults.count);
}

#pragma mark - CSV Generation

- (void)exportResultsToClipboard:(NSArray<ScoreResult *> *)results {
    NSMutableString *csv = [NSMutableString string];
    
    // Header row
    [csv appendString:@"Symbol\tTotal Score"];
    if (self.currentStrategy) {
        for (IndicatorConfig *indicator in self.currentStrategy.indicators) {
            if (indicator.isEnabled) {
                [csv appendFormat:@"\t%@", indicator.displayName];
            }
        }
    }
    [csv appendString:@"\n"];
    
    // Data rows
    for (ScoreResult *result in results) {
        [csv appendFormat:@"%@\t%.2f", result.symbol, result.totalScore];
        
        if (self.currentStrategy) {
            for (IndicatorConfig *indicator in self.currentStrategy.indicators) {
                if (indicator.isEnabled) {
                    CGFloat score = [result scoreForIndicator:indicator.indicatorType];
                    [csv appendFormat:@"\t%.1f", score];
                }
            }
        }
        [csv appendString:@"\n"];
    }
    
    // Copy to clipboard
    NSPasteboard *pasteboard = [NSPasteboard generalPasteboard];
    [pasteboard clearContents];
    [pasteboard setString:csv forType:NSPasteboardTypeString];
    
    NSLog(@"📋 CSV copied to clipboard:\n%@", csv);
}

@end
