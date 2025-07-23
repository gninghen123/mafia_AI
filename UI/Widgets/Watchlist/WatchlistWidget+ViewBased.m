//
//  WatchlistWidget+ViewBased.m
//  mafia_AI
//
//  View-based table view implementation for WatchlistWidget
//

#import "WatchlistWidget.h"
#import "DataHub.h"
#import "Watchlist.h"

@implementation WatchlistWidget (ViewBasedTable)

#pragma mark - NSTableViewDelegate (View-Based)

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    // Handle sidebar table view
    if (tableView.tag == 1002) {
        return [self viewForSidebarTableColumn:tableColumn row:row];
    }
    
    // Handle main table view
    NSString *identifier = tableColumn.identifier;
    
    // Check if we're beyond data bounds
    if (row >= self.filteredSymbols.count) {
        return nil;
    }
    
    NSString *symbol = self.filteredSymbols[row];
    BOOL isLastRow = (row == self.filteredSymbols.count - 1);
    BOOL isEmpty = (symbol.length == 0);
    
    // Symbol column
    if ([identifier isEqualToString:@"symbol"]) {
        WatchlistSymbolCellView *cellView = [tableView makeViewWithIdentifier:@"SymbolCell" owner:self];
        if (!cellView) {
            cellView = [[WatchlistSymbolCellView alloc] init];
            cellView.identifier = @"SymbolCell";
        }
        
        cellView.isEditable = isLastRow;
        
        if (isEmpty && isLastRow) {
            cellView.symbolField.placeholderString = @"Type symbol...";
            cellView.symbolField.stringValue = @"";
            cellView.symbolField.delegate = self;
        } else {
            cellView.symbolField.stringValue = symbol;
            cellView.symbolField.placeholderString = nil;
        }
        
        return cellView;
    }
    
    // For empty rows, return empty cells
    if (isEmpty) {
        NSTableCellView *emptyCell = [tableView makeViewWithIdentifier:@"EmptyCell" owner:self];
        if (!emptyCell) {
            emptyCell = [[NSTableCellView alloc] init];
            emptyCell.identifier = @"EmptyCell";
            
            NSTextField *textField = [NSTextField labelWithString:@"--"];
            textField.font = [NSFont systemFontOfSize:12];
            textField.textColor = [NSColor tertiaryLabelColor];
            textField.alignment = NSTextAlignmentCenter;
            textField.translatesAutoresizingMaskIntoConstraints = NO;
            
            [emptyCell addSubview:textField];
            [NSLayoutConstraint activateConstraints:@[
                [textField.centerXAnchor constraintEqualToAnchor:emptyCell.centerXAnchor],
                [textField.centerYAnchor constraintEqualToAnchor:emptyCell.centerYAnchor]
            ]];
        }
        return emptyCell;
    }
    
    // Get cached data for symbol
    NSDictionary *data = self.symbolDataCache[symbol];
    
    // Price column
    if ([identifier isEqualToString:@"price"]) {
        WatchlistPriceCellView *cellView = [tableView makeViewWithIdentifier:@"PriceCell" owner:self];
        if (!cellView) {
            cellView = [[WatchlistPriceCellView alloc] init];
            cellView.identifier = @"PriceCell";
        }
        
        NSNumber *price = data[@"price"];
        if (price) {
            cellView.priceField.stringValue = [NSString stringWithFormat:@"$%.2f", price.doubleValue];
            cellView.priceField.textColor = [NSColor labelColor];
        } else {
            cellView.priceField.stringValue = @"--";
            cellView.priceField.textColor = [NSColor tertiaryLabelColor];
        }
        
        return cellView;
    }
    
    // Change column
    else if ([identifier isEqualToString:@"change"]) {
        WatchlistChangeCellView *cellView = [tableView makeViewWithIdentifier:@"ChangeCell" owner:self];
        if (!cellView) {
            cellView = [[WatchlistChangeCellView alloc] init];
            cellView.identifier = @"ChangeCell";
        }
        
        NSNumber *change = data[@"change"];
        NSNumber *changePercent = data[@"changePercent"];
        
        if (change && changePercent) {
            [cellView setChangeValue:change.doubleValue percentChange:changePercent.doubleValue];
        } else {
            cellView.changeField.stringValue = @"--";
            cellView.percentField.stringValue = @"";
            cellView.trendIcon.image = nil;
            cellView.changeField.textColor = [NSColor tertiaryLabelColor];
        }
        
        return cellView;
    }
    
    // Change Percent column (if separate)
    else if ([identifier isEqualToString:@"changePercent"]) {
        // If you want a separate column for percentage only
        NSTableCellView *cellView = [tableView makeViewWithIdentifier:@"PercentCell" owner:self];
        if (!cellView) {
            cellView = [[NSTableCellView alloc] init];
            cellView.identifier = @"PercentCell";
            
            NSTextField *textField = [[NSTextField alloc] init];
            textField.bordered = NO;
            textField.editable = NO;
            textField.backgroundColor = [NSColor clearColor];
            textField.font = [NSFont monospacedDigitSystemFontOfSize:12 weight:NSFontWeightRegular];
            textField.alignment = NSTextAlignmentRight;
            textField.translatesAutoresizingMaskIntoConstraints = NO;
            
            [cellView addSubview:textField];
            cellView.textField = textField;
            
            [NSLayoutConstraint activateConstraints:@[
                [textField.leadingAnchor constraintEqualToAnchor:cellView.leadingAnchor constant:8],
                [textField.trailingAnchor constraintEqualToAnchor:cellView.trailingAnchor constant:-8],
                [textField.centerYAnchor constraintEqualToAnchor:cellView.centerYAnchor]
            ]];
        }
        
        NSNumber *changePercent = data[@"changePercent"];
        if (changePercent) {
            double percent = changePercent.doubleValue;
            cellView.textField.stringValue = [NSString stringWithFormat:@"%@%.2f%%", percent >= 0 ? @"+" : @"", percent];
            cellView.textField.textColor = percent >= 0 ? [NSColor systemGreenColor] : [NSColor systemRedColor];
        } else {
            cellView.textField.stringValue = @"--";
            cellView.textField.textColor = [NSColor tertiaryLabelColor];
        }
        
        return cellView;
    }
    
    // Volume column
    else if ([identifier isEqualToString:@"volume"]) {
        WatchlistVolumeCellView *cellView = [tableView makeViewWithIdentifier:@"VolumeCell" owner:self];
        if (!cellView) {
            cellView = [[WatchlistVolumeCellView alloc] init];
            cellView.identifier = @"VolumeCell";
        }
        
        NSNumber *volume = data[@"volume"];
        NSNumber *avgVolume = data[@"avgVolume"];
        [cellView setVolume:volume avgVolume:avgVolume];
        
        return cellView;
    }
    
    // Market Cap column
    else if ([identifier isEqualToString:@"marketCap"]) {
        WatchlistMarketCapCellView *cellView = [tableView makeViewWithIdentifier:@"MarketCapCell" owner:self];
        if (!cellView) {
            cellView = [[WatchlistMarketCapCellView alloc] init];
            cellView.identifier = @"MarketCapCell";
        }
        
        NSNumber *marketCap = data[@"marketCap"];
        [cellView setMarketCap:marketCap];
        
        return cellView;
    }
    
    return nil;
}

- (NSView *)viewForSidebarTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    if (row >= self.watchlists.count) return nil;
    
    WatchlistSidebarCellView *cellView = [self.sidebarTableView makeViewWithIdentifier:@"SidebarCell" owner:self];
    if (!cellView) {
        cellView = [[WatchlistSidebarCellView alloc] init];
        cellView.identifier = @"SidebarCell";
    }
    
    Watchlist *watchlist = self.watchlists[row];
    
    // Set icon
    cellView.iconView.image = [NSImage imageWithSystemSymbolName:@"list.bullet"
                                    accessibilityDescription:nil];
    cellView.iconView.contentTintColor = [NSColor secondaryLabelColor];
    
    // Highlight current watchlist
    if (watchlist == self.currentWatchlist) {
        cellView.iconView.contentTintColor = [NSColor controlAccentColor];
        cellView.nameField.textColor = [NSColor controlAccentColor];
    } else {
        cellView.nameField.textColor = [NSColor labelColor];
    }
    
    // Set text
    cellView.nameField.stringValue = watchlist.name;
    cellView.countField.stringValue = [NSString stringWithFormat:@"%lu", watchlist.symbols.count];
    
    return cellView;
}

- (CGFloat)tableView:(NSTableView *)tableView heightOfRow:(NSInteger)row {
    // Standard row height for main table
    if (tableView.tag == 1001) {
        return 28.0; // Slightly taller for better visual separation
    }
    // Sidebar rows
    return 24.0;
}

- (BOOL)tableView:(NSTableView *)tableView shouldEditTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    // Only allow editing the symbol column on the last row
    if (tableView.tag == 1001 && [tableColumn.identifier isEqualToString:@"symbol"]) {
        return row == self.filteredSymbols.count - 1;
    }
    return NO;
}

#pragma mark - NSTextFieldDelegate

- (void)controlTextDidEndEditing:(NSNotification *)notification {
    NSTextField *textField = notification.object;
    if ([textField.superview isKindOfClass:[WatchlistSymbolCellView class]]) {
        NSString *newSymbol = textField.stringValue;
        
        if (newSymbol.length > 0) {
            // Add the new symbol
            NSString *upperSymbol = [newSymbol uppercaseString];
            
            // Check if symbol already exists
            if (![self.symbols containsObject:upperSymbol]) {
                // Add to current watchlist
                [[DataHub shared] addSymbol:upperSymbol toWatchlist:self.currentWatchlist];
                
                // Reload data
                [self loadSymbolsForCurrentWatchlist];
                
                // Refresh data for new symbol
                [self refreshSymbolData];
            } else {
                // Symbol already exists - show alert
                NSAlert *alert = [[NSAlert alloc] init];
                alert.messageText = @"Symbol Already Exists";
                alert.informativeText = [NSString stringWithFormat:@"'%@' is already in this watchlist.", upperSymbol];
                [alert addButtonWithTitle:@"OK"];
                [alert runModal];
            }
        }
        
        // Clear the field
        textField.stringValue = @"";
    }
}

- (BOOL)control:(NSControl *)control textView:(NSTextView *)textView doCommandBySelector:(SEL)commandSelector {
    // Handle Enter key in symbol field
    if (commandSelector == @selector(insertNewline:)) {
        [control.window makeFirstResponder:nil]; // End editing
        return YES;
    }
    return NO;
}

@end
