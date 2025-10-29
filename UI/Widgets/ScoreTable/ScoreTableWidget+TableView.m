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
    
    NSLog(@"📊 Sorted by %@ (%@)", key, ascending ? @"ascending" : @"descending");
}

#pragma mark - Color Coding

- (NSColor *)colorForScore:(CGFloat)score {
    if (score >= 75) {
        return [NSColor colorWithRed:0.0 green:0.7 blue:0.0 alpha:1.0]; // Dark green
    } else if (score >= 50) {
        return [NSColor colorWithRed:0.4 green:0.7 blue:0.2 alpha:1.0]; // Medium green
    } else if (score >= 25) {
        return [NSColor colorWithRed:0.7 green:0.7 blue:0.0 alpha:1.0]; // Yellow
    } else if (score >= 0) {
        return [NSColor colorWithRed:0.8 green:0.5 blue:0.0 alpha:1.0]; // Orange
    } else {
        return [NSColor colorWithRed:0.8 green:0.0 blue:0.0 alpha:1.0]; // Red
    }
}

@end
