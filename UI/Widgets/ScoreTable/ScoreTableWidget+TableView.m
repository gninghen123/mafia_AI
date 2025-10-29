//
//  ScoreTableWidget+TableView.m
//  TradingApp
//
//  TableView DataSource/Delegate and UI logic
//

#import "ScoreTableWidget.h"

@implementation ScoreTableWidget (TableView)

#pragma mark - NSTableViewDataSource

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    return self.scoreResults.count;
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    if (row < 0 || row >= self.scoreResults.count) return nil;
    
    ScoreResult *result = self.scoreResults[row];
    NSString *identifier = tableColumn.identifier;
    
    if ([identifier isEqualToString:@"symbol"]) {
        return result.symbol;
    }
    else if ([identifier isEqualToString:@"totalScore"]) {
        return [NSString stringWithFormat:@"%.2f", result.totalScore];
    }
    else {
        // Dynamic indicator column
        CGFloat score = [result scoreForIndicator:identifier];
        return [NSString stringWithFormat:@"%.1f", score];
    }
}

#pragma mark - NSTableViewDelegate

- (void)tableView:(NSTableView *)tableView willDisplayCell:(id)cell forTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    if (row < 0 || row >= self.scoreResults.count) return;
    
    if (![cell isKindOfClass:[NSTextFieldCell class]]) return;
    NSTextFieldCell *textCell = (NSTextFieldCell *)cell;
    
    ScoreResult *result = self.scoreResults[row];
    NSString *identifier = tableColumn.identifier;
    
    // Color coding for scores
    if ([identifier isEqualToString:@"totalScore"]) {
        CGFloat score = result.totalScore;
        [textCell setTextColor:[self colorForScore:score]];
    }
    else if (![identifier isEqualToString:@"symbol"]) {
        // Indicator column
        CGFloat score = [result scoreForIndicator:identifier];
        [textCell setTextColor:[self colorForScore:score]];
    }
}

- (void)tableView:(NSTableView *)tableView sortDescriptorsDidChange:(NSArray<NSSortDescriptor *> *)oldDescriptors {
    NSArray<NSSortDescriptor *> *newDescriptors = tableView.sortDescriptors;
    
    if (newDescriptors.count == 0) return;
    
    NSSortDescriptor *primarySort = newDescriptors.firstObject;
    NSString *key = primarySort.key;
    BOOL ascending = primarySort.ascending;
    
    [self.scoreResults sortUsingComparator:^NSComparisonResult(ScoreResult *obj1, ScoreResult *obj2) {
        CGFloat value1, value2;
        
        if ([key isEqualToString:@"totalScore"]) {
            value1 = obj1.totalScore;
            value2 = obj2.totalScore;
        } else {
            value1 = [obj1 scoreForIndicator:key];
            value2 = [obj2 scoreForIndicator:key];
        }
        
        if (value1 < value2) {
            return ascending ? NSOrderedAscending : NSOrderedDescending;
        } else if (value1 > value2) {
            return ascending ? NSOrderedDescending : NSOrderedAscending;
        }
        return NSOrderedSame;
    }];
    
    [tableView reloadData];
}

#pragma mark - Single Click → Chain

- (void)tableViewSelectionDidChange:(NSNotification *)notification {
    NSTableView *tableView = notification.object;
    NSInteger selectedRow = tableView.selectedRow;
    
    if (selectedRow < 0 || selectedRow >= self.scoreResults.count) return;
    
    // ✅ SINGLE CLICK → Send to Chain
    ScoreResult *result = self.scoreResults[selectedRow];
    NSString *symbol = result.symbol;
    
    if (symbol) {
        [self sendChainAction:@"symbolSelected" withData:@{@"symbols": @[symbol]}];
        [self showChainFeedback:[NSString stringWithFormat:@"📤 %@", symbol]];
        NSLog(@"📤 Single-click: Sent %@ to chain", symbol);
    }
}

#pragma mark - Context Menu

- (NSMenu *)tableView:(NSTableView *)tableView menuForTableColumn:(NSTableColumn *)column row:(NSInteger)row {
    NSMenu *menu = [[NSMenu alloc] init];
    
    // Export Section
    NSMenuItem *exportSelectionItem = [[NSMenuItem alloc] initWithTitle:@"Export Selection to Clipboard"
                                                                  action:@selector(exportSelectionToClipboard:)
                                                           keyEquivalent:@""];
    exportSelectionItem.target = self;
    [menu addItem:exportSelectionItem];
    
    NSMenuItem *exportAllItem = [[NSMenuItem alloc] initWithTitle:@"Export All to Clipboard"
                                                           action:@selector(exportAllToClipboard:)
                                                    keyEquivalent:@""];
    exportAllItem.target = self;
    [menu addItem:exportAllItem];
    
    [menu addItem:[NSMenuItem separatorItem]];
    
    // Chain Section
    NSMenuItem *sendSelectedItem = [[NSMenuItem alloc] initWithTitle:@"Send Selected to Chain"
                                                              action:@selector(sendSelectedToChain:)
                                                       keyEquivalent:@""];
    sendSelectedItem.target = self;
    [menu addItem:sendSelectedItem];
    
    NSMenuItem *sendAllItem = [[NSMenuItem alloc] initWithTitle:@"Send All to Chain"
                                                         action:@selector(sendAllToChain:)
                                                  keyEquivalent:@""];
    sendAllItem.target = self;
    [menu addItem:sendAllItem];
    
    return menu;
}

#pragma mark - Chain Actions

- (void)sendSelectedToChain:(id)sender {
    NSIndexSet *selectedRows = self.scoreTableView.selectedRowIndexes;
    if (selectedRows.count == 0) return;
    
    NSMutableArray<NSString *> *symbols = [NSMutableArray array];
    [selectedRows enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop) {
        if (idx < self.scoreResults.count) {
            [symbols addObject:self.scoreResults[idx].symbol];
        }
    }];
    
    if (symbols.count > 0) {
        [self sendChainAction:@"symbolSelected" withData:@{@"symbols": symbols}];
        [self showChainFeedback:[NSString stringWithFormat:@"📤 Sent %lu symbols to chain", (unsigned long)symbols.count]];
        NSLog(@"📤 Sent %lu selected symbols to chain", (unsigned long)symbols.count);
    }
}

- (void)sendAllToChain:(id)sender {
    if (self.scoreResults.count == 0) return;
    
    NSMutableArray<NSString *> *symbols = [NSMutableArray array];
    for (ScoreResult *result in self.scoreResults) {
        [symbols addObject:result.symbol];
    }
    
    [self sendChainAction:@"symbolSelected" withData:@{@"symbols": symbols}];
    [self showChainFeedback:[NSString stringWithFormat:@"📤 Sent all %lu symbols to chain", (unsigned long)symbols.count]];
    NSLog(@"📤 Sent all %lu symbols to chain", (unsigned long)symbols.count);
}

@end
