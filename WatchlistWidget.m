//
//  WatchlistWidget.m
//  TradingApp
//

#import "WatchlistWidget.h"
#import "BaseWidget.h"
#import "WatchlistManager.h"
#import "DataManager.h"
#import "MarketDataModels.h"
#import <objc/runtime.h>  // <-- QUESTO IMPORT RISOLVE IL PROBLEMA

#pragma mark - WatchlistRule Implementation

@implementation WatchlistRule

- (instancetype)initWithName:(NSString *)name
                       field:(WatchlistRuleField)field
                   condition:(WatchlistRuleCondition)condition
                       value:(id)value {
    self = [super init];
    if (self) {
        _name = name;
        _field = field;
        _condition = condition;
        _value = value;
        _enabled = YES;
        _highlightColor = [NSColor systemYellowColor];
    }
    return self;
}

- (BOOL)evaluateWithData:(NSDictionary *)data {
    if (!self.enabled || !data) return NO;
    
    id fieldValue = [self extractFieldValue:data];
    if (!fieldValue) return NO;
    
    return [self evaluateValue:fieldValue];
}

- (id)extractFieldValue:(NSDictionary *)data {
    switch (self.field) {
        case WatchlistRuleFieldPrice:
            return data[@"last"];
        case WatchlistRuleFieldChange:
            return data[@"change"];
        case WatchlistRuleFieldChangePercent:
            return data[@"changePercent"];
        case WatchlistRuleFieldVolume:
            return data[@"volume"];
        case WatchlistRuleFieldSymbol:
            return data[@"symbol"];
        default:
            return nil;
    }
}

- (BOOL)evaluateValue:(id)fieldValue {
    if (self.field == WatchlistRuleFieldSymbol) {
        return [self evaluateStringValue:fieldValue];
    } else {
        return [self evaluateNumericValue:fieldValue];
    }
}

- (BOOL)evaluateStringValue:(NSString *)stringValue {
    NSString *targetValue = self.value;
    if (!targetValue) return NO;
    
    switch (self.condition) {
        case WatchlistRuleConditionEqual:
            return [stringValue isEqualToString:targetValue];
        case WatchlistRuleConditionNotEqual:
            return ![stringValue isEqualToString:targetValue];
        case WatchlistRuleConditionContains:
            return [stringValue localizedCaseInsensitiveContainsString:targetValue];
        default:
            return NO;
    }
}

- (BOOL)evaluateNumericValue:(NSNumber *)numericValue {
    NSNumber *targetValue = self.value;
    if (!targetValue) return NO;
    
    NSComparisonResult comparison = [numericValue compare:targetValue];
    
    switch (self.condition) {
        case WatchlistRuleConditionGreaterThan:
            return comparison == NSOrderedDescending;
        case WatchlistRuleConditionLessThan:
            return comparison == NSOrderedAscending;
        case WatchlistRuleConditionEqual:
            return comparison == NSOrderedSame;
        case WatchlistRuleConditionNotEqual:
            return comparison != NSOrderedSame;
        case WatchlistRuleConditionBetween:
            if (self.secondaryValue) {
                NSNumber *minValue = [targetValue compare:self.secondaryValue] == NSOrderedAscending ? targetValue : self.secondaryValue;
                NSNumber *maxValue = [targetValue compare:self.secondaryValue] == NSOrderedDescending ? targetValue : self.secondaryValue;
                return [numericValue compare:minValue] != NSOrderedAscending && [numericValue compare:maxValue] != NSOrderedDescending;
            }
            return NO;
        default:
            return NO;
    }
}

+ (NSArray<WatchlistRule *> *)defaultRules {
    return @[
        [[WatchlistRule alloc] initWithName:@"High Volume"
                                      field:WatchlistRuleFieldVolume
                                  condition:WatchlistRuleConditionGreaterThan
                                      value:@1000000],
        [[WatchlistRule alloc] initWithName:@"Big Gainer"
                                      field:WatchlistRuleFieldChangePercent
                                  condition:WatchlistRuleConditionGreaterThan
                                      value:@5.0],
        [[WatchlistRule alloc] initWithName:@"Big Loser"
                                      field:WatchlistRuleFieldChangePercent
                                  condition:WatchlistRuleConditionLessThan
                                      value:@(-5.0)]
    ];
}

@end

#pragma mark - WatchlistWidget Implementation

@interface WatchlistWidget ()
- (void)broadcastUpdate:(NSDictionary *)update;

@property (nonatomic, strong) NSTableView *tableViewInternal;
@property (nonatomic, strong) NSScrollView *scrollViewInternal;
@property (nonatomic, strong) NSTextField *symbolInputFieldInternal;
@property (nonatomic, strong) NSButton *removeButtonInternal;
@property (nonatomic, strong) NSComboBox *watchlistComboBoxInternal;
@property (nonatomic, strong) NSButton *watchlistMenuButton;
@property (nonatomic, strong) NSMutableDictionary<NSString *, MarketData *> *marketDataCache;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSColor *> *symbolColors;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSSet<NSString *> *> *symbolTags;
@property (nonatomic, strong) DataManager *dataManager;
@property (nonatomic, strong) NSTimer *refreshTimer;
@property (nonatomic, strong) WatchlistManager *watchlistManager;
@property (nonatomic, strong) WatchlistData *currentWatchlist;
@end

@implementation WatchlistWidget

- (instancetype)initWithType:(NSString *)type panelType:(PanelType)panelType {
    self = [super initWithType:type panelType:panelType];
    if (self) {
        self.widgetType = @"Watchlist";
        _symbols = [NSMutableArray array];
        _rules = [NSMutableArray array];
        _marketDataCache = [NSMutableDictionary dictionary];
        _symbolColors = [NSMutableDictionary dictionary];
        _symbolTags = [NSMutableDictionary dictionary];
        _dataManager = [DataManager sharedManager];
        _watchlistManager = [WatchlistManager sharedManager];
        
        [_dataManager addDelegate:self];
        
        // Load default watchlist
        _watchlistName = @"Default";
        [self loadWatchlist:_watchlistName];
        
        // Set up refresh timer for periodic updates
        _refreshTimer = [NSTimer scheduledTimerWithTimeInterval:30.0
                                                         target:self
                                                       selector:@selector(refreshData)
                                                       userInfo:nil
                                                        repeats:YES];
    }
    return self;
}

- (void)setupContentView {
    [super setupContentView];
    
    // Create main stack view
    NSStackView *mainStack = [[NSStackView alloc] init];
    mainStack.orientation = NSUserInterfaceLayoutOrientationVertical;
    mainStack.spacing = 10;
    mainStack.edgeInsets = NSEdgeInsetsMake(10, 10, 10, 10);
    
    // Input section
    NSView *inputSection = [self createInputSection];
    
    // Table view
    [self createTableView];
    
    // Add to stack
    [mainStack addArrangedSubview:inputSection];
    [mainStack addArrangedSubview:self.scrollViewInternal];
    
    // Add stack to content view
    [self.contentView addSubview:mainStack];
    mainStack.translatesAutoresizingMaskIntoConstraints = NO;
    [NSLayoutConstraint activateConstraints:@[
        [mainStack.topAnchor constraintEqualToAnchor:self.contentView.topAnchor],
        [mainStack.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor],
        [mainStack.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor],
        [mainStack.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor]
    ]];
    
    // Request initial quotes for all symbols
    [self refreshData];
}

- (NSView *)createInputSection {
    NSView *container = [[NSView alloc] init];
    
    // Prima riga: Watchlist selector e menu
    NSTextField *titleLabel = [[NSTextField alloc] init];
    titleLabel.stringValue = @"Watchlist:";
    titleLabel.editable = NO;
    titleLabel.bordered = NO;
    titleLabel.backgroundColor = [NSColor clearColor];
    titleLabel.font = [NSFont systemFontOfSize:12 weight:NSFontWeightMedium];
    titleLabel.textColor = [NSColor secondaryLabelColor];
    
    // ComboBox per selezionare/digitare nome watchlist
    self.watchlistComboBoxInternal = [[NSComboBox alloc] init];
    self.watchlistComboBoxInternal.editable = YES;
    self.watchlistComboBoxInternal.usesDataSource = YES;
    self.watchlistComboBoxInternal.dataSource = self;
    self.watchlistComboBoxInternal.delegate = self;
    self.watchlistComboBoxInternal.completes = YES;  // Enable autocompletion
    self.watchlistComboBoxInternal.hasVerticalScroller = YES;
    self.watchlistComboBoxInternal.intercellSpacing = NSMakeSize(0, 2);
    self.watchlistComboBoxInternal.itemHeight = 20;
    self.watchlistComboBoxInternal.numberOfVisibleItems = 10;
    self.watchlistComboBoxInternal.stringValue = self.watchlistName;
    [self.watchlistComboBoxInternal reloadData];
    
    // Bottone menu per azioni watchlist
    self.watchlistMenuButton = [[NSButton alloc] init];
    self.watchlistMenuButton.title = @"⚙";
    self.watchlistMenuButton.bezelStyle = NSBezelStyleRegularSquare;
    self.watchlistMenuButton.bordered = YES;
    self.watchlistMenuButton.target = self;
    self.watchlistMenuButton.action = @selector(showWatchlistMenu:);
    [self.watchlistMenuButton.widthAnchor constraintEqualToConstant:30].active = YES;
    
    // Stack per prima riga
    NSStackView *titleStack = [[NSStackView alloc] init];
    titleStack.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    titleStack.spacing = 8;
    titleStack.alignment = NSLayoutAttributeCenterY;
    
    [titleStack addArrangedSubview:titleLabel];
    [titleStack addArrangedSubview:self.watchlistComboBoxInternal];
    [titleStack addArrangedSubview:self.watchlistMenuButton];
    
    // Imposta priorità di contenuto
    [self.watchlistComboBoxInternal setContentHuggingPriority:NSLayoutPriorityDefaultLow forOrientation:NSLayoutConstraintOrientationHorizontal];
    
    // Seconda riga: Input simboli
    self.symbolInputFieldInternal = [[NSTextField alloc] init];
    self.symbolInputFieldInternal.placeholderString = @"Enter symbols (AAPL, MSFT GOOGL)...";
    self.symbolInputFieldInternal.target = self;
    self.symbolInputFieldInternal.action = @selector(addSymbolsFromInput:);
    
    self.removeButtonInternal = [[NSButton alloc] init];
    self.removeButtonInternal.title = @"-";
    self.removeButtonInternal.bezelStyle = NSBezelStyleRounded;
    self.removeButtonInternal.target = self;
    self.removeButtonInternal.action = @selector(removeSelectedSymbols:);
    
    // Stack per seconda riga
    NSStackView *symbolStack = [[NSStackView alloc] init];
    symbolStack.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    symbolStack.spacing = 5;
    
    [symbolStack addArrangedSubview:self.symbolInputFieldInternal];
    [symbolStack addArrangedSubview:self.removeButtonInternal];
    
    // Stack principale verticale
    NSStackView *mainStack = [[NSStackView alloc] init];
    mainStack.orientation = NSUserInterfaceLayoutOrientationVertical;
    mainStack.spacing = 8;
    
    [mainStack addArrangedSubview:titleStack];
    [mainStack addArrangedSubview:symbolStack];
    
    [container addSubview:mainStack];
    mainStack.translatesAutoresizingMaskIntoConstraints = NO;
    [NSLayoutConstraint activateConstraints:@[
        [mainStack.topAnchor constraintEqualToAnchor:container.topAnchor],
        [mainStack.leadingAnchor constraintEqualToAnchor:container.leadingAnchor],
        [mainStack.trailingAnchor constraintEqualToAnchor:container.trailingAnchor],
        [mainStack.bottomAnchor constraintEqualToAnchor:container.bottomAnchor],
        [mainStack.heightAnchor constraintEqualToConstant:60]
    ]];
    
    return container;
}

- (void)createTableView {
    self.tableViewInternal = [[NSTableView alloc] init];
    
    // Enable multiple selection
    self.tableViewInternal.allowsMultipleSelection = YES;
    
    // Create columns with sorting
    NSTableColumn *symbolColumn = [[NSTableColumn alloc] initWithIdentifier:@"symbol"];
    symbolColumn.title = @"Symbol";
    symbolColumn.width = 80;
    symbolColumn.sortDescriptorPrototype = [[NSSortDescriptor alloc] initWithKey:@"symbol" ascending:YES];
    [self.tableViewInternal addTableColumn:symbolColumn];
    
    NSTableColumn *priceColumn = [[NSTableColumn alloc] initWithIdentifier:@"price"];
    priceColumn.title = @"Price";
    priceColumn.width = 80;
    priceColumn.sortDescriptorPrototype = [[NSSortDescriptor alloc] initWithKey:@"price" ascending:NO];
    [self.tableViewInternal addTableColumn:priceColumn];
    
    NSTableColumn *changeColumn = [[NSTableColumn alloc] initWithIdentifier:@"change"];
    changeColumn.title = @"Change %";
    changeColumn.width = 100;
    changeColumn.sortDescriptorPrototype = [[NSSortDescriptor alloc] initWithKey:@"changePercent" ascending:NO];
    [self.tableViewInternal addTableColumn:changeColumn];
    
    NSTableColumn *tagsColumn = [[NSTableColumn alloc] initWithIdentifier:@"tags"];
    tagsColumn.title = @"Tags";
    tagsColumn.width = 120;
    [self.tableViewInternal addTableColumn:tagsColumn];
    
    self.tableViewInternal.dataSource = self;
    self.tableViewInternal.delegate = self;
    
    // Enable sorting
    [self.tableViewInternal setSortDescriptors:@[]];
    
    // Add context menu
    NSMenu *contextMenu = [[NSMenu alloc] init];
    contextMenu.delegate = self;
    self.tableViewInternal.menu = contextMenu;
    
    self.scrollViewInternal = [[NSScrollView alloc] init];
    self.scrollViewInternal.documentView = self.tableViewInternal;
    self.scrollViewInternal.hasVerticalScroller = YES;
}

#pragma mark - Context Menu (NSMenuDelegate)

- (void)menuNeedsUpdate:(NSMenu *)menu {
    [menu removeAllItems];
    
    NSIndexSet *selectedRows = self.tableViewInternal.selectedRowIndexes;
    BOOL hasSelection = selectedRows.count > 0;
    
    if (hasSelection) {
        // Color submenu
        NSMenuItem *colorMenuItem = [[NSMenuItem alloc] initWithTitle:@"Set Color" action:nil keyEquivalent:@""];
        NSMenu *colorSubmenu = [[NSMenu alloc] init];
        
        NSArray *colors = @[
            @{@"name": @"Reset (Default)", @"color": [NSNull null]},
            @{@"name": @"Red", @"color": [NSColor systemRedColor]},
            @{@"name": @"Green", @"color": [NSColor systemGreenColor]},
            @{@"name": @"Blue", @"color": [NSColor systemBlueColor]},
            @{@"name": @"Orange", @"color": [NSColor systemOrangeColor]},
            @{@"name": @"Purple", @"color": [NSColor systemPurpleColor]},
            @{@"name": @"Yellow", @"color": [NSColor systemYellowColor]}
        ];
        
        for (NSDictionary *colorInfo in colors) {
            NSMenuItem *colorItem = [[NSMenuItem alloc] initWithTitle:colorInfo[@"name"]
                                                               action:@selector(setSymbolColor:)
                                                        keyEquivalent:@""];
            colorItem.target = self;
            colorItem.representedObject = colorInfo[@"color"];
            [colorSubmenu addItem:colorItem];
        }
        
        colorMenuItem.submenu = colorSubmenu;
        [menu addItem:colorMenuItem];
        
        // Tags submenu
        NSMenuItem *tagsMenuItem = [[NSMenuItem alloc] initWithTitle:@"Tags" action:nil keyEquivalent:@""];
        NSMenu *tagsSubmenu = [[NSMenu alloc] init];
        
        NSMenuItem *addTagItem = [[NSMenuItem alloc] initWithTitle:@"Add Tag..."
                                                            action:@selector(addTagToSelectedSymbols:)
                                                     keyEquivalent:@""];
        addTagItem.target = self;
        [tagsSubmenu addItem:addTagItem];
        
        NSMenuItem *removeTagItem = [[NSMenuItem alloc] initWithTitle:@"Remove Tag..."
                                                               action:@selector(removeTagFromSelectedSymbols:)
                                                        keyEquivalent:@""];
        removeTagItem.target = self;
        [tagsSubmenu addItem:removeTagItem];
        
        tagsMenuItem.submenu = tagsSubmenu;
        [menu addItem:tagsMenuItem];
        
        [menu addItem:[NSMenuItem separatorItem]];
        
        // Watchlist operations
        NSMenuItem *newListItem = [[NSMenuItem alloc] initWithTitle:@"Create New List from Selection"
                                                             action:@selector(createNewListFromSelection:)
                                                      keyEquivalent:@""];
        newListItem.target = self;
        [menu addItem:newListItem];
        
        [menu addItem:[NSMenuItem separatorItem]];
        
        NSString *removeTitle = selectedRows.count > 1 ?
            [NSString stringWithFormat:@"Remove %lu Symbols", (unsigned long)selectedRows.count] :
            @"Remove Symbol";
        NSMenuItem *removeItem = [[NSMenuItem alloc] initWithTitle:removeTitle
                                                            action:@selector(removeSelectedSymbols:)
                                                     keyEquivalent:@""];
        removeItem.target = self;
        [menu addItem:removeItem];
        
        [menu addItem:[NSMenuItem separatorItem]];
        
        // Copy functions
        NSMenuItem *copyItem = [[NSMenuItem alloc] initWithTitle:@"Copy Symbol(s)"
                                                          action:@selector(copySelectedSymbols:)
                                                   keyEquivalent:@""];
        copyItem.target = self;
        [menu addItem:copyItem];
        
        NSMenuItem *exportItem = [[NSMenuItem alloc] initWithTitle:@"Export Selection to CSV..."
                                                            action:@selector(exportSelectionToCSV:)
                                                     keyEquivalent:@""];
        exportItem.target = self;
        [menu addItem:exportItem];
    } else {
        // No selection - show general options
        NSMenuItem *refreshItem = [[NSMenuItem alloc] initWithTitle:@"Refresh All Data"
                                                             action:@selector(refreshData)
                                                      keyEquivalent:@""];
        refreshItem.target = self;
        [menu addItem:refreshItem];
        
        [menu addItem:[NSMenuItem separatorItem]];
        
        NSMenuItem *importItem = [[NSMenuItem alloc] initWithTitle:@"Import CSV..."
                                                            action:@selector(importCSV:)
                                                     keyEquivalent:@""];
        importItem.target = self;
        [menu addItem:importItem];
        
        NSMenuItem *exportAllItem = [[NSMenuItem alloc] initWithTitle:@"Export All to CSV..."
                                                               action:@selector(exportCSV:)
                                                        keyEquivalent:@""];
        exportAllItem.target = self;
        [menu addItem:exportAllItem];
        
        [menu addItem:[NSMenuItem separatorItem]];
        
        NSMenuItem *clearItem = [[NSMenuItem alloc] initWithTitle:@"Clear Watchlist"
                                                           action:@selector(clearWatchlist)
                                                    keyEquivalent:@""];
        clearItem.target = self;
        [menu addItem:clearItem];
    }
}

#pragma mark - Context Menu Actions

- (void)setSymbolColor:(NSMenuItem *)sender {
    NSColor *color = [sender.representedObject isKindOfClass:[NSNull class]] ? nil : sender.representedObject;
    NSIndexSet *selectedRows = self.tableViewInternal.selectedRowIndexes;
    
    [selectedRows enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop) {
        if (idx < self.symbols.count) {
            NSString *symbol = self.symbols[idx];
            if (color) {
                self.symbolColors[symbol] = color;
            } else {
                [self.symbolColors removeObjectForKey:symbol];
            }
        }
    }];
    
    [self.tableViewInternal reloadData];
}

- (void)addTagToSelectedSymbols:(id)sender {
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"Add Tag";
    alert.informativeText = @"Enter a tag name:";
    
    NSTextField *input = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 200, 24)];
    input.placeholderString = @"Tag name";
    alert.accessoryView = input;
    
    [alert addButtonWithTitle:@"Add"];
    [alert addButtonWithTitle:@"Cancel"];
    
    NSModalResponse response = [alert runModal];
    
    if (response == NSAlertFirstButtonReturn) {
        NSString *tagName = input.stringValue.length > 0 ? input.stringValue : nil;
        if (tagName) {
            NSIndexSet *selectedRows = self.tableViewInternal.selectedRowIndexes;
            [self addTag:tagName toSymbols:selectedRows];
        }
    }
}

- (void)removeTagFromSelectedSymbols:(id)sender {
    // Get all unique tags from selected symbols
    NSMutableSet *allTags = [NSMutableSet set];
    NSIndexSet *selectedRows = self.tableViewInternal.selectedRowIndexes;
    
    [selectedRows enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop) {
        if (idx < self.symbols.count) {
            NSString *symbol = self.symbols[idx];
            NSSet *symbolTags = self.symbolTags[symbol];
            if (symbolTags) {
                [allTags unionSet:symbolTags];
            }
        }
    }];
    
    if (allTags.count == 0) {
        NSAlert *alert = [[NSAlert alloc] init];
        alert.messageText = @"No Tags";
        alert.informativeText = @"Selected symbols have no tags to remove.";
        [alert addButtonWithTitle:@"OK"];
        [alert runModal];
        return;
    }
    
    // Show selection dialog
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"Remove Tag";
    alert.informativeText = @"Select tag to remove:";
    
    NSPopUpButton *popup = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(0, 0, 200, 24)];
    for (NSString *tag in allTags.allObjects) {
        [popup addItemWithTitle:tag];
    }
    alert.accessoryView = popup;
    
    [alert addButtonWithTitle:@"Remove"];
    [alert addButtonWithTitle:@"Cancel"];
    
    NSModalResponse response = [alert runModal];
    
    if (response == NSAlertFirstButtonReturn) {
        NSString *tagToRemove = popup.titleOfSelectedItem;
        if (tagToRemove) {
            [self removeTag:tagToRemove fromSymbols:selectedRows];
        }
    }
}




- (void)sendSelectedSymbolsToCharts:(id)sender {
    NSIndexSet *selectedRows = [self.tableViewInternal selectedRowIndexes];
    NSMutableArray *selectedSymbols = [NSMutableArray array];
    
    [selectedRows enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop) {
        if (idx < self.symbols.count) {
            [selectedSymbols addObject:self.symbols[idx]];
        }
    }];
    
    if (selectedSymbols.count > 0) {
        [self sendSymbolsToChainedWidgets:selectedSymbols];
        
        // Mostra feedback visivo
        [self showTemporaryMessage:[NSString stringWithFormat:@"📤 Sent %ld symbol%@ to charts",
                                   selectedSymbols.count,
                                   selectedSymbols.count == 1 ? @"" : @"s"]];
    }
}

- (void)sendEntireWatchlistToCharts:(id)sender {
    if (self.symbols.count > 0) {
        [self sendSymbolsToChainedWidgets:[self.symbols copy]];
        
        // Mostra feedback visivo
        [self showTemporaryMessage:[NSString stringWithFormat:@"📤 Sent entire watchlist (%ld symbols) to charts", self.symbols.count]];
    }
}

- (void)sendSymbolsToChainedWidgets:(NSArray<NSString *> *)symbols {
    if (self.chainedWidgets.count == 0) {
        [self showTemporaryMessage:@"⚠️ No charts connected. Use 🔗 to connect to MultiChart widget"];
        return;
    }
    
    // Crea update dictionary con lista di simboli
    NSDictionary *update = @{
        @"action": @"setSymbols",
        @"symbols": symbols,
        @"source": @"watchlist",
        @"watchlistName": self.watchlistName ?: @"Default"
    };
    
    // Broadcast ai widget connessi
    [self broadcastUpdate:update];
    
    NSLog(@"📤 WatchlistWidget: Sent %ld symbols to %ld connected chart widgets",
          symbols.count, self.chainedWidgets.count);
}

- (void)showTemporaryMessage:(NSString *)message {
    // Crea un overlay temporaneo per mostrare feedback
    NSTextField *messageLabel = [[NSTextField alloc] init];
    messageLabel.stringValue = message;
    messageLabel.backgroundColor = [NSColor controlAccentColor];
    messageLabel.textColor = [NSColor controlAlternatingRowBackgroundColors].firstObject;
    messageLabel.font = [NSFont systemFontOfSize:11 weight:NSFontWeightMedium];
    messageLabel.alignment = NSTextAlignmentCenter;
    messageLabel.bordered = NO;
    messageLabel.editable = NO;
    messageLabel.selectable = NO;
    messageLabel.wantsLayer = YES;
    messageLabel.layer.cornerRadius = 4;
    messageLabel.layer.opacity = 0.95;
    
    messageLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:messageLabel];
    
    [NSLayoutConstraint activateConstraints:@[
        [messageLabel.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [messageLabel.topAnchor constraintEqualToAnchor:self.view.topAnchor constant:8],
        [messageLabel.widthAnchor constraintLessThanOrEqualToAnchor:self.view.widthAnchor constant:-16],
        [messageLabel.heightAnchor constraintEqualToConstant:28]
    ]];
    
    // Anima l'apparizione
    messageLabel.layer.opacity = 0;
    [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
        context.duration = 0.3;
        messageLabel.animator.layer.opacity = 0.95;
    } completionHandler:^{
        // Rimuovi dopo 2 secondi
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
                context.duration = 0.3;
                messageLabel.animator.layer.opacity = 0;
            } completionHandler:^{
                [messageLabel removeFromSuperview];
            }];
        });
    }];
}


- (void)createNewListFromSelection:(id)sender {
    NSIndexSet *selectedRows = self.tableViewInternal.selectedRowIndexes;
    if (selectedRows.count == 0) return;
    
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"New Watchlist";
    alert.informativeText = @"Enter name for new watchlist:";
    
    NSTextField *input = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 200, 24)];
    input.placeholderString = @"Watchlist name";
    alert.accessoryView = input;
    
    [alert addButtonWithTitle:@"Create"];
    [alert addButtonWithTitle:@"Cancel"];
    
    NSModalResponse response = [alert runModal];
    
    if (response == NSAlertFirstButtonReturn) {
        NSString *newListName = input.stringValue.length > 0 ? input.stringValue : @"New List";
        
        // Get selected symbols
        NSMutableArray *selectedSymbols = [NSMutableArray array];
        [selectedRows enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop) {
            if (idx < self.symbols.count) {
                [selectedSymbols addObject:self.symbols[idx]];
            }
        }];
        
        // Create new watchlist using WatchlistManager
        WatchlistData *newWatchlist = [self.watchlistManager createWatchlistWithName:newListName];
        [newWatchlist.symbols addObjectsFromArray:selectedSymbols];
        [self.watchlistManager saveWatchlist:newWatchlist];
        
        [self.watchlistComboBoxInternal reloadData];
        
        // Show confirmation
        NSAlert *confirmAlert = [[NSAlert alloc] init];
        confirmAlert.messageText = @"Watchlist Created";
        confirmAlert.informativeText = [NSString stringWithFormat:@"Created '%@' with %lu symbols",
                                       newListName, (unsigned long)selectedSymbols.count];
        [confirmAlert addButtonWithTitle:@"Switch to New List"];
        [confirmAlert addButtonWithTitle:@"Stay Here"];
        
        NSModalResponse confirmResponse = [confirmAlert runModal];
        if (confirmResponse == NSAlertFirstButtonReturn) {
            [self loadWatchlist:newListName];
            self.watchlistComboBoxInternal.stringValue = newListName;
        }
    }
}

- (void)copySelectedSymbols:(id)sender {
    NSIndexSet *selectedRows = self.tableViewInternal.selectedRowIndexes;
    if (selectedRows.count == 0) return;
    
    NSMutableArray *symbolsToCopy = [NSMutableArray array];
    [selectedRows enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop) {
        if (idx < self.symbols.count) {
            [symbolsToCopy addObject:self.symbols[idx]];
        }
    }];
    
    NSString *symbolsString = [symbolsToCopy componentsJoinedByString:@", "];
    NSPasteboard *pasteboard = [NSPasteboard generalPasteboard];
    [pasteboard clearContents];
    [pasteboard setString:symbolsString forType:NSPasteboardTypeString];
}

- (void)exportSelectionToCSV:(id)sender {
    NSIndexSet *selectedRows = self.tableViewInternal.selectedRowIndexes;
    if (selectedRows.count == 0) return;
    
    NSSavePanel *savePanel = [NSSavePanel savePanel];
    savePanel.allowedFileTypes = @[@"csv"];
    savePanel.nameFieldStringValue = [NSString stringWithFormat:@"%@_selection.csv", self.watchlistName];
    
    NSModalResponse response = [savePanel runModal];
    
    if (response == NSModalResponseOK) {
        NSURL *fileURL = savePanel.URL;
        [self exportSelectedSymbolsToURL:fileURL withIndexes:selectedRows];
    }
}

#pragma mark - Tag Management

- (void)addTag:(NSString *)tagName toSymbols:(NSIndexSet *)selectedIndexes {
    [selectedIndexes enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop) {
        if (idx < self.symbols.count) {
            NSString *symbol = self.symbols[idx];
            NSMutableSet *symbolTags = [self.symbolTags[symbol] mutableCopy] ?: [NSMutableSet set];
            [symbolTags addObject:tagName];
            self.symbolTags[symbol] = symbolTags;
        }
    }];
    
    [self.tableViewInternal reloadData];
}

- (void)removeTag:(NSString *)tagName fromSymbols:(NSIndexSet *)selectedIndexes {
    [selectedIndexes enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop) {
        if (idx < self.symbols.count) {
            NSString *symbol = self.symbols[idx];
            NSMutableSet *symbolTags = [self.symbolTags[symbol] mutableCopy];
            if (symbolTags) {
                [symbolTags removeObject:tagName];
                if (symbolTags.count > 0) {
                    self.symbolTags[symbol] = symbolTags;
                } else {
                    [self.symbolTags removeObjectForKey:symbol];
                }
            }
        }
    }];
    
    [self.tableViewInternal reloadData];
}

#pragma mark - Watchlist Management

- (void)loadWatchlist:(NSString *)name {
    self.currentWatchlist = [self.watchlistManager watchlistWithName:name];
    
    if (!self.currentWatchlist) {
        // Create new watchlist if it doesn't exist
        self.currentWatchlist = [self.watchlistManager createWatchlistWithName:name];
    }
    
    // Update dynamic watchlist if needed
    if (self.currentWatchlist.isDynamic) {
        [self.watchlistManager updateDynamicWatchlists];
        // Reload from manager to get updated symbols
        self.currentWatchlist = [self.watchlistManager watchlistWithName:name];
    }
    
    self.watchlistName = self.currentWatchlist.name;
    
    // Update symbols array
    [self.symbols removeAllObjects];
    [self.symbols addObjectsFromArray:self.currentWatchlist.symbols];
    
    // Unsubscribe from old symbols and subscribe to new ones
    [self.dataManager unsubscribeFromQuotes:self.marketDataCache.allKeys];
    [self.marketDataCache removeAllObjects];
    
    if (self.symbols.count > 0) {
        [self.dataManager subscribeToQuotes:self.symbols];
        [self refreshData];
    }
    
    [self.tableViewInternal reloadData];
    
    // Update UI to show dynamic status
    [self updateWatchlistDisplayInfo];
}

- (void)updateWatchlistDisplayInfo {
    // Update the combo box to show if watchlist is dynamic
    if (self.currentWatchlist.isDynamic) {
     /*   NSString *displayName = [NSString stringWithFormat:@"%@ (Dynamic: #%@)",
                                self.currentWatchlist.name,
                                self.currentWatchlist.dynamicTag];
        // Note: We only show this info visually, the actual combo box value remains the same*/
    }
}

- (void)showWatchlistMenu:(NSButton *)sender {
    NSMenu *menu = [[NSMenu alloc] init];
    
    // === SEZIONE CHAIN/INVIO (se ci sono simboli e connessioni) ===
    if (self.symbols.count > 0) {
        // Controlla se ci sono widget connessi che possono ricevere simboli
        BOOL hasChartConnections = [self hasConnectedChartWidgets];
        
        if (hasChartConnections) {
            NSMenuItem *chainHeader = [[NSMenuItem alloc] initWithTitle:@"📤 Send to Connected Charts" action:nil keyEquivalent:@""];
            chainHeader.enabled = NO;
            [menu addItem:chainHeader];
            
            // Opzione per inviare selezione corrente (se c'è)
            NSIndexSet *selectedRows = [self.tableViewInternal selectedRowIndexes];
            if (selectedRows.count > 0) {
                NSString *title = selectedRows.count == 1 ?
                    @"Send Selected Symbol" :
                    [NSString stringWithFormat:@"Send Selected (%ld symbols)", selectedRows.count];
                NSMenuItem *sendSelectedItem = [[NSMenuItem alloc] initWithTitle:title
                                                                          action:@selector(sendSelectedSymbolsToCharts:)
                                                                   keyEquivalent:@""];
                sendSelectedItem.target = self;
                [menu addItem:sendSelectedItem];
            }
            
            // Opzione per inviare intera watchlist
            NSString *watchlistTitle = [NSString stringWithFormat:@"Send Entire Watchlist (%ld symbols)", self.symbols.count];
            NSMenuItem *sendAllItem = [[NSMenuItem alloc] initWithTitle:watchlistTitle
                                                                 action:@selector(sendEntireWatchlistToCharts:)
                                                          keyEquivalent:@""];
            sendAllItem.target = self;
            [menu addItem:sendAllItem];
            
            [menu addItem:[NSMenuItem separatorItem]];
        } else if (self.symbols.count > 0) {
            // Mostra opzione per connettere se non ci sono connessioni
            NSMenuItem *connectHint = [[NSMenuItem alloc] initWithTitle:@"🔗 Connect to MultiChart to send symbols" action:nil keyEquivalent:@""];
            connectHint.enabled = NO;
            [menu addItem:connectHint];
            [menu addItem:[NSMenuItem separatorItem]];
        }
    }
    
    // === SEZIONI ORIGINALI ===
    [menu addItemWithTitle:@"New Watchlist..." action:@selector(createNewWatchlist:) keyEquivalent:@""];
    [menu addItemWithTitle:@"New Dynamic Watchlist..." action:@selector(createDynamicWatchlist:) keyEquivalent:@""];
    [menu addItemWithTitle:@"Duplicate Current" action:@selector(duplicateWatchlist:) keyEquivalent:@""];
    [menu addItem:[NSMenuItem separatorItem]];
    [menu addItemWithTitle:@"Import CSV..." action:@selector(importCSV:) keyEquivalent:@""];
    [menu addItemWithTitle:@"Export CSV..." action:@selector(exportCSV:) keyEquivalent:@""];
    [menu addItem:[NSMenuItem separatorItem]];
    [menu addItemWithTitle:@"Delete Current" action:@selector(deleteCurrentWatchlist:) keyEquivalent:@""];
    
    // Set target for all menu items
    for (NSMenuItem *item in menu.itemArray) {
        if (item.action && !item.target) {
            item.target = self;
        }
    }
    
    // Show menu anchored to button
    NSRect buttonFrame = sender.bounds;
    NSPoint menuOrigin = NSMakePoint(buttonFrame.origin.x, buttonFrame.origin.y);
    
    [menu popUpMenuPositioningItem:menu.itemArray.firstObject
                        atLocation:menuOrigin
                            inView:sender];
}

- (void)createNewWatchlist:(id)sender {
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"Create New Watchlist";
    alert.informativeText = @"Enter a name for the new watchlist:";
    
    NSTextField *input = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 200, 24)];
    input.placeholderString = @"Watchlist name";
    alert.accessoryView = input;
    
    [alert addButtonWithTitle:@"Create"];
    [alert addButtonWithTitle:@"Cancel"];
    
    NSModalResponse response = [alert runModal];
    
    if (response == NSAlertFirstButtonReturn && input.stringValue.length > 0) {
        WatchlistData *newWatchlist = [self.watchlistManager createWatchlistWithName:input.stringValue];
        [self loadWatchlist:newWatchlist.name];
        self.watchlistComboBoxInternal.stringValue = newWatchlist.name;
        [self.watchlistComboBoxInternal reloadData];
    }
}

- (void)createDynamicWatchlist:(id)sender {
    NSArray *availableTags = [self.watchlistManager availableTags];
    
    if (availableTags.count == 0) {
        NSAlert *alert = [[NSAlert alloc] init];
        alert.messageText = @"No Tags Available";
        alert.informativeText = @"You need to add tags to symbols first before creating dynamic watchlists.";
        [alert addButtonWithTitle:@"OK"];
        [alert runModal];
        return;
    }
    
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"Create Dynamic Watchlist";
    alert.informativeText = @"Select a tag for the dynamic watchlist:";
    
    // Create popup button for tag selection
    NSPopUpButton *tagPopup = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(0, 30, 200, 24)];
    for (NSString *tag in availableTags) {
        [tagPopup addItemWithTitle:[NSString stringWithFormat:@"#%@", tag]];
        [[tagPopup lastItem] setRepresentedObject:tag];
    }
    
    // Create text field for custom name
    NSTextField *nameField = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 200, 24)];
    nameField.placeholderString = @"Optional: Custom name";
    
    // Create container view
    NSView *accessoryView = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 200, 60)];
    [accessoryView addSubview:tagPopup];
    [accessoryView addSubview:nameField];
    
    alert.accessoryView = accessoryView;
    
    [alert addButtonWithTitle:@"Create"];
    [alert addButtonWithTitle:@"Cancel"];
    
    NSModalResponse response = [alert runModal];
    
    if (response == NSAlertFirstButtonReturn) {
        NSMenuItem *selectedItem = [tagPopup selectedItem];
        NSString *selectedTag = [selectedItem representedObject];
        
        NSString *watchlistName = nameField.stringValue;
        if (watchlistName.length == 0) {
            watchlistName = [NSString stringWithFormat:@"#%@", selectedTag];
        }
        
        WatchlistData *newWatchlist = [self.watchlistManager createDynamicWatchlistWithName:watchlistName forTag:selectedTag];
        [self loadWatchlist:newWatchlist.name];
        self.watchlistComboBoxInternal.stringValue = newWatchlist.name;
        [self.watchlistComboBoxInternal reloadData];
    }
}

- (void)duplicateWatchlist:(id)sender {
    if (!self.currentWatchlist) return;
    
    NSString *newName = [NSString stringWithFormat:@"%@ Copy", self.currentWatchlist.name];
    WatchlistData *newWatchlist = [self.watchlistManager createWatchlistWithName:newName];
    [newWatchlist.symbols addObjectsFromArray:self.currentWatchlist.symbols];
    [self.watchlistManager saveWatchlist:newWatchlist];
    
    [self loadWatchlist:newWatchlist.name];
    self.watchlistComboBoxInternal.stringValue = newWatchlist.name;
    [self.watchlistComboBoxInternal reloadData];
}

- (void)deleteCurrentWatchlist:(id)sender {
    if (!self.currentWatchlist) return;
    
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"Delete Watchlist";
    alert.informativeText = [NSString stringWithFormat:@"Are you sure you want to delete '%@'?", self.currentWatchlist.name];
    [alert addButtonWithTitle:@"Delete"];
    [alert addButtonWithTitle:@"Cancel"];
    alert.alertStyle = NSAlertStyleWarning;
    
    NSModalResponse response = [alert runModal];
    
    if (response == NSAlertFirstButtonReturn) {
        [self.watchlistManager deleteWatchlistWithName:self.currentWatchlist.name];
        
        // Load first available watchlist or create default
        NSArray *availableWatchlists = [self.watchlistManager availableWatchlistNames];
        if (availableWatchlists.count > 0) {
            [self loadWatchlist:availableWatchlists[0]];
            self.watchlistComboBoxInternal.stringValue = availableWatchlists[0];
        } else {
            [self loadWatchlist:@"Default"];
            self.watchlistComboBoxInternal.stringValue = @"Default";
        }
        
        [self.watchlistComboBoxInternal reloadData];
    }
}

#pragma mark - NSComboBoxDataSource & Delegate

- (NSInteger)numberOfItemsInComboBox:(NSComboBox *)comboBox {
    if (comboBox == self.watchlistComboBoxInternal) {
        return [self.watchlistManager availableWatchlistNames].count;
    }
    return 0;
}

- (id)comboBox:(NSComboBox *)comboBox objectValueForItemAtIndex:(NSInteger)index {
    if (comboBox == self.watchlistComboBoxInternal) {
        NSArray *names = [self.watchlistManager availableWatchlistNames];
        if (index < names.count) {
            return names[index];
        }
    }
    return nil;
}

- (void)comboBoxSelectionDidChange:(NSNotification *)notification {
    NSComboBox *comboBox = notification.object;
    if (comboBox == self.watchlistComboBoxInternal) {
        NSString *selectedName = [comboBox objectValueOfSelectedItem];
        if (selectedName && ![selectedName isEqualToString:self.watchlistName]) {
            [self loadWatchlist:selectedName];
        }
    }
}

- (NSString *)comboBox:(NSComboBox *)comboBox completedString:(NSString *)uncompletedString {
    if (comboBox == self.watchlistComboBoxInternal) {
        NSArray *availableNames = [self.watchlistManager availableWatchlistNames];
        for (NSString *name in availableNames) {
            if ([name.lowercaseString hasPrefix:uncompletedString.lowercaseString]) {
                return name;
            }
        }
    }
    return nil;
}

- (void)controlTextDidEndEditing:(NSNotification *)notification {
    NSControl *control = notification.object;
    if (control == self.watchlistComboBoxInternal) {
        NSString *newName = self.watchlistComboBoxInternal.stringValue;
        if (newName.length > 0 && ![newName isEqualToString:self.watchlistName]) {
            // Check if watchlist exists
            WatchlistData *existingWatchlist = [self.watchlistManager watchlistWithName:newName];
            if (existingWatchlist) {
                // Load existing watchlist
                [self loadWatchlist:newName];
            } else {
                // Ask user if they want to create new watchlist
                NSAlert *alert = [[NSAlert alloc] init];
                alert.messageText = @"Create New Watchlist";
                alert.informativeText = [NSString stringWithFormat:@"Watchlist '%@' doesn't exist. Do you want to create it?", newName];
                [alert addButtonWithTitle:@"Create"];
                [alert addButtonWithTitle:@"Cancel"];
                
                NSModalResponse response = [alert runModal];
                
                if (response == NSAlertFirstButtonReturn) {
                    // Create new watchlist
                    WatchlistData *newWatchlist = [self.watchlistManager createWatchlistWithName:newName];
                    [self loadWatchlist:newWatchlist.name];
                    [self.watchlistComboBoxInternal reloadData];
                } else {
                    // Revert to current watchlist name
                    self.watchlistComboBoxInternal.stringValue = self.watchlistName;
                }
            }
        }
    }
}

#pragma mark - Symbol Operations

- (NSArray<NSString *> *)parseSymbolsFromInput:(NSString *)input {
    if (!input || input.length == 0) {
        return @[];
    }
    
    // Trim whitespace
    input = [input stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    
    // Create character set with comma, space, semicolon, and tab
    NSCharacterSet *separators = [NSCharacterSet characterSetWithCharactersInString:@", ;\t"];
    
    // Split by separators
    NSArray *components = [input componentsSeparatedByCharactersInSet:separators];
    
    // Clean up each symbol
    NSMutableArray *cleanSymbols = [NSMutableArray array];
    for (NSString *component in components) {
        NSString *cleanSymbol = [[component stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] uppercaseString];
        
        // Only add non-empty symbols that contain letters or numbers
        if (cleanSymbol.length > 0 && [self isValidSymbol:cleanSymbol]) {
            [cleanSymbols addObject:cleanSymbol];
        }
    }
    
    return [cleanSymbols copy];
}

- (BOOL)isValidSymbol:(NSString *)symbol {
    // Basic validation: symbol should contain only letters, numbers, dots, and dashes
    NSCharacterSet *validChars = [NSCharacterSet characterSetWithCharactersInString:@"ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.-"];
    NSCharacterSet *symbolChars = [NSCharacterSet characterSetWithCharactersInString:symbol];
    return [validChars isSupersetOfSet:symbolChars] && symbol.length <= 10; // Reasonable length limit
}

- (void)addSymbol:(NSString *)symbol {
    if (!symbol || symbol.length == 0) return;
    
    NSString *upperSymbol = symbol.uppercaseString;
    if (![self.symbols containsObject:upperSymbol]) {
        [self.symbols addObject:upperSymbol];
        [self.watchlistManager addSymbol:upperSymbol toWatchlist:self.watchlistName];
        
        // Subscribe to quotes and request immediate data
        [self.dataManager subscribeToQuotes:@[upperSymbol]];
        [self.dataManager requestQuoteForSymbol:upperSymbol completion:^(MarketData *quote, NSError *error) {
            if (quote && !error) {
                self.marketDataCache[upperSymbol] = quote;
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.tableViewInternal reloadData];
                });
            }
        }];
        
        [self.tableViewInternal reloadData];
        
        // Broadcast symbol change to chained widgets
        if (self.chainedWidgets.count > 0) {
            [self broadcastUpdate:@{@"symbol": upperSymbol}];
        }
    }
}

- (void)addMultipleSymbols:(NSArray<NSString *> *)symbols {
    NSMutableArray *newSymbols = [NSMutableArray array];
    
    for (NSString *symbol in symbols) {
        NSString *upperSymbol = symbol.uppercaseString;
        if (![self.symbols containsObject:upperSymbol]) {
            [self.symbols addObject:upperSymbol];
            [newSymbols addObject:upperSymbol];
        }
    }
    
    if (newSymbols.count > 0) {
        [self.watchlistManager addSymbols:newSymbols toWatchlist:self.watchlistName];
        
        // Subscribe to quotes and request immediate data for new symbols
        [self.dataManager subscribeToQuotes:newSymbols];
        
        for (NSString *symbol in newSymbols) {
            [self.dataManager requestQuoteForSymbol:symbol completion:^(MarketData *quote, NSError *error) {
                if (quote && !error) {
                    self.marketDataCache[symbol] = quote;
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self.tableViewInternal reloadData];
                    });
                }
            }];
        }
        
        [self.tableViewInternal reloadData];
        
        // Broadcast the first new symbol to chained widgets
        if (self.chainedWidgets.count > 0 && newSymbols.count > 0) {
            [self broadcastUpdate:@{@"symbol": newSymbols[0]}];
        }
    }
}

- (void)removeSymbol:(NSString *)symbol {
    [self.symbols removeObject:symbol];
    [self.watchlistManager removeSymbol:symbol fromWatchlist:self.watchlistName];
    [self.dataManager unsubscribeFromQuotes:@[symbol]];
    [self.marketDataCache removeObjectForKey:symbol];
    [self.symbolColors removeObjectForKey:symbol];
    [self.symbolTags removeObjectForKey:symbol];
    [self.tableViewInternal reloadData];
}

- (void)removeSymbolAtIndex:(NSInteger)index {
    if (index >= 0 && index < self.symbols.count) {
        NSString *symbol = self.symbols[index];
        [self removeSymbol:symbol];
    }
}

- (void)clearWatchlist {
    [self.dataManager unsubscribeFromQuotes:self.symbols];
    [self.symbols removeAllObjects];
    [self.marketDataCache removeAllObjects];
    [self.symbolColors removeAllObjects];
    [self.symbolTags removeAllObjects];
    [self.tableViewInternal reloadData];
}

#pragma mark - Actions

- (void)addSymbolsFromInput:(id)sender {
    NSString *input = self.symbolInputFieldInternal.stringValue;
    NSArray<NSString *> *symbols = [self parseSymbolsFromInput:input];
    
    if (symbols.count > 0) {
        [self addMultipleSymbols:symbols];
        self.symbolInputFieldInternal.stringValue = @"";
    }
}

- (void)removeSelectedSymbols:(id)sender {
    NSIndexSet *selectedRows = self.tableViewInternal.selectedRowIndexes;
    if (selectedRows.count == 0) return;
    
    // Remove in reverse order to maintain correct indices
    [selectedRows enumerateIndexesWithOptions:NSEnumerationReverse
                                   usingBlock:^(NSUInteger idx, BOOL *stop) {
        [self removeSymbolAtIndex:idx];
    }];
}

#pragma mark - Table Sorting

- (void)tableView:(NSTableView *)tableView sortDescriptorsDidChange:(NSArray<NSSortDescriptor *> *)oldDescriptors {
    NSArray *newDescriptors = [tableView sortDescriptors];
    
    if (newDescriptors.count > 0) {
        NSSortDescriptor *sortDescriptor = newDescriptors[0];
        NSString *key = sortDescriptor.key;
        BOOL ascending = sortDescriptor.ascending;
        
        // Create array of dictionaries with symbol data for sorting
        NSMutableArray *sortableData = [NSMutableArray array];
        
        for (NSString *symbol in self.symbols) {
            MarketData *data = self.marketDataCache[symbol];
            NSMutableDictionary *itemData = [NSMutableDictionary dictionary];
            itemData[@"symbol"] = symbol;
            
            if (data) {
                itemData[@"price"] = data.last ?: @(0);
                itemData[@"changePercent"] = data.changePercent ?: @(0);
            } else {
                itemData[@"price"] = @(0);
                itemData[@"changePercent"] = @(0);
            }
            
            [sortableData addObject:itemData];
        }
        
        // Sort the data
        NSArray *sortedData = [sortableData sortedArrayUsingDescriptors:newDescriptors];
        
        // Extract sorted symbols
        NSMutableArray *sortedSymbols = [NSMutableArray array];
        for (NSDictionary *item in sortedData) {
            [sortedSymbols addObject:item[@"symbol"]];
        }
        
        // Update symbols array
        [self.symbols removeAllObjects];
        [self.symbols addObjectsFromArray:sortedSymbols];
        
        [tableView reloadData];
    }
}

#pragma mark - CSV Import/Export

- (void)importCSV:(id)sender {
    NSOpenPanel *openPanel = [NSOpenPanel openPanel];
    openPanel.allowedFileTypes = @[@"csv"];
    openPanel.allowsMultipleSelection = NO;
    openPanel.canChooseDirectories = NO;
    openPanel.canChooseFiles = YES;
    
    NSModalResponse response = [openPanel runModal];
    
    if (response == NSModalResponseOK) {
        NSURL *fileURL = openPanel.URLs.firstObject;
        [self importCSVFromURL:fileURL];
    }
}

- (void)importCSVFromURL:(NSURL *)fileURL {
    NSError *error;
    NSString *csvContent = [NSString stringWithContentsOfURL:fileURL encoding:NSUTF8StringEncoding error:&error];
    
    if (error) {
        NSAlert *alert = [[NSAlert alloc] init];
        alert.messageText = @"Import Error";
        alert.informativeText = [NSString stringWithFormat:@"Could not read CSV file: %@", error.localizedDescription];
        [alert addButtonWithTitle:@"OK"];
        [alert runModal];
        return;
    }
    
    // Parse CSV content
    NSArray *lines = [csvContent componentsSeparatedByString:@"\n"];
    NSMutableArray *symbolsToAdd = [NSMutableArray array];
    
    for (NSString *line in lines) {
        NSString *trimmedLine = [line stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (trimmedLine.length == 0) continue;
        
        // Split by comma and take first column as symbol
        NSArray *columns = [trimmedLine componentsSeparatedByString:@","];
        if (columns.count > 0) {
            NSString *symbol = [columns[0] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            
            // Remove quotes if present
            if ([symbol hasPrefix:@"\""] && [symbol hasSuffix:@"\""]) {
                symbol = [symbol substringWithRange:NSMakeRange(1, symbol.length - 2)];
            }
            
            // Validate and add symbol
            if (symbol.length > 0 && [self isValidSymbol:symbol] && ![symbol isEqualToString:@"Symbol"]) {
                [symbolsToAdd addObject:symbol.uppercaseString];
            }
        }
    }
    
    if (symbolsToAdd.count > 0) {
        // Ask user if they want to replace or add to current watchlist
        NSAlert *alert = [[NSAlert alloc] init];
        alert.messageText = @"Import CSV";
        alert.informativeText = [NSString stringWithFormat:@"Found %lu symbols. Do you want to add them to the current watchlist or replace it?", (unsigned long)symbolsToAdd.count];
        [alert addButtonWithTitle:@"Add to Current"];
        [alert addButtonWithTitle:@"Replace Current"];
        [alert addButtonWithTitle:@"Cancel"];
        
        NSModalResponse response = [alert runModal];
        
        if (response == NSAlertFirstButtonReturn) {
            // Add to current
            [self addMultipleSymbols:symbolsToAdd];
        } else if (response == NSAlertSecondButtonReturn) {
            // Replace current
            [self clearWatchlist];
            [self addMultipleSymbols:symbolsToAdd];
        }
    } else {
        NSAlert *alert = [[NSAlert alloc] init];
        alert.messageText = @"Import Error";
        alert.informativeText = @"No valid symbols found in CSV file.";
        [alert addButtonWithTitle:@"OK"];
        [alert runModal];
    }
}

- (void)exportCSV:(id)sender {
    NSSavePanel *savePanel = [NSSavePanel savePanel];
    savePanel.allowedFileTypes = @[@"csv"];
    savePanel.nameFieldStringValue = [NSString stringWithFormat:@"%@.csv", self.watchlistName];
    
    NSModalResponse response = [savePanel runModal];
    
    if (response == NSModalResponseOK) {
        NSURL *fileURL = savePanel.URL;
        [self exportCSVToURL:fileURL];
    }
}

- (void)exportCSVToURL:(NSURL *)fileURL {
    NSMutableString *csvContent = [NSMutableString string];
    
    // Add header
    [csvContent appendString:@"Symbol,Price,Change%,Tags\n"];
    
    // Add symbol data
    for (NSString *symbol in self.symbols) {
        MarketData *data = self.marketDataCache[symbol];
        
        NSString *price = @"--";
        NSString *changePercent = @"--";
        
        if (data) {
            if (data.last) {
                price = [NSString stringWithFormat:@"%.2f", data.last.doubleValue];
            }
            if (data.changePercent) {
                changePercent = [NSString stringWithFormat:@"%.2f", data.changePercent.doubleValue];
            }
        }
        
        // Get tags for this symbol
        NSSet *tags = self.symbolTags[symbol];
        NSString *tagsString = tags.count > 0 ? [tags.allObjects componentsJoinedByString:@"|"] : @"";
        
        [csvContent appendFormat:@"%@,%@,%@,%@\n", symbol, price, changePercent, tagsString];
    }
    
    NSError *error;
    BOOL success = [csvContent writeToURL:fileURL atomically:YES encoding:NSUTF8StringEncoding error:&error];
    
    if (!success) {
        NSAlert *alert = [[NSAlert alloc] init];
        alert.messageText = @"Export Error";
        alert.informativeText = [NSString stringWithFormat:@"Could not save CSV file: %@", error.localizedDescription];
        [alert addButtonWithTitle:@"OK"];
        [alert runModal];
    }
}

- (void)exportSelectedSymbolsToURL:(NSURL *)fileURL withIndexes:(NSIndexSet *)selectedIndexes {
    NSMutableString *csvContent = [NSMutableString string];
    
    // Add header
    [csvContent appendString:@"Symbol,Price,Change%,Tags\n"];
    
    // Add symbol data for selected symbols only
    [selectedIndexes enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop) {
        if (idx < self.symbols.count) {
            NSString *symbol = self.symbols[idx];
            MarketData *data = self.marketDataCache[symbol];
            
            NSString *price = @"--";
            NSString *changePercent = @"--";
            
            if (data) {
                if (data.last) {
                    price = [NSString stringWithFormat:@"%.2f", data.last.doubleValue];
                }
                if (data.changePercent) {
                    changePercent = [NSString stringWithFormat:@"%.2f", data.changePercent.doubleValue];
                }
            }
            
            // Get tags for this symbol
            NSSet *tags = self.symbolTags[symbol];
            NSString *tagsString = tags.count > 0 ? [tags.allObjects componentsJoinedByString:@"|"] : @"";
            
            [csvContent appendFormat:@"%@,%@,%@,%@\n", symbol, price, changePercent, tagsString];
        }
    }];
    
    NSError *error;
    BOOL success = [csvContent writeToURL:fileURL atomically:YES encoding:NSUTF8StringEncoding error:&error];
    
    if (!success) {
        NSAlert *alert = [[NSAlert alloc] init];
        alert.messageText = @"Export Error";
        alert.informativeText = [NSString stringWithFormat:@"Could not save CSV file: %@", error.localizedDescription];
        [alert addButtonWithTitle:@"OK"];
        [alert runModal];
    }
}

/*
// Legacy methods for backward compatibility
- (void)setSymbolColor:(id)sender {
    NSInteger selectedRow = self.tableViewInternal.selectedRow;
    if (selectedRow < 0 || selectedRow >= self.symbols.count) return;
    
    NSString *symbol = self.symbols[selectedRow];
    
    NSColorPanel *colorPanel = [NSColorPanel sharedColorPanel];
    colorPanel.target = self;
    colorPanel.action = @selector(colorChanged:);
    
    // Store selected symbol for color callback
    objc_setAssociatedObject(colorPanel, "selectedSymbol", symbol, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    
    // Set current color
    SymbolProperties *properties = [self.watchlistManager propertiesForSymbol:symbol];
    if (properties.color) {
        colorPanel.color = properties.color;
    } else {
        colorPanel.color = [NSColor labelColor];
    }
    
    [colorPanel makeKeyAndOrderFront:nil];
}
 */

- (void)colorChanged:(NSColorPanel *)sender {
    NSString *symbol = objc_getAssociatedObject(sender, "selectedSymbol");
    if (symbol) {
        [self.watchlistManager setColor:sender.color forSymbol:symbol];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.tableViewInternal reloadData];
            [self.tableViewInternal setNeedsDisplay:YES];
        });
    }
}

- (void)addSymbolTag:(id)sender {
    NSInteger selectedRow = self.tableViewInternal.selectedRow;
    if (selectedRow < 0 || selectedRow >= self.symbols.count) return;
    
    NSString *symbol = self.symbols[selectedRow];
    
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"Add Tag";
    alert.informativeText = [NSString stringWithFormat:@"Enter a tag for %@:", symbol];
    
    NSTextField *input = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 200, 24)];
    input.placeholderString = @"Tag name (e.g., AI, Tech, Growth)";
    alert.accessoryView = input;
    
    [alert addButtonWithTitle:@"Add"];
    [alert addButtonWithTitle:@"Cancel"];
    
    NSModalResponse response = [alert runModal];
    
    if (response == NSAlertFirstButtonReturn && input.stringValue.length > 0) {
        NSString *tag = input.stringValue;
        [self.watchlistManager addTag:tag toSymbol:symbol];
        
        // Show success message with option to create dynamic watchlist
        NSAlert *successAlert = [[NSAlert alloc] init];
        successAlert.messageText = @"Tag Added";
        successAlert.informativeText = [NSString stringWithFormat:@"Added tag '%@' to %@. Would you like to create a dynamic watchlist for this tag?", tag, symbol];
        [successAlert addButtonWithTitle:@"Create Dynamic Watchlist"];
        [successAlert addButtonWithTitle:@"No Thanks"];
        
        NSModalResponse successResponse = [successAlert runModal];
        
        if (successResponse == NSAlertFirstButtonReturn) {
            // Create dynamic watchlist for this tag
            NSString *dynamicName = [NSString stringWithFormat:@"#%@", tag];
            WatchlistData *dynamicWatchlist = [self.watchlistManager createDynamicWatchlistWithName:dynamicName forTag:tag];
            [self.watchlistComboBoxInternal reloadData];
        }
    }
}

- (void)copySymbol:(id)sender {
    NSInteger selectedRow = self.tableViewInternal.selectedRow;
    if (selectedRow < 0 || selectedRow >= self.symbols.count) return;
    
    NSString *symbol = self.symbols[selectedRow];
    NSPasteboard *pasteboard = [NSPasteboard generalPasteboard];
    [pasteboard clearContents];
    [pasteboard setString:symbol forType:NSPasteboardTypeString];
}

#pragma mark - NSTableViewDataSource

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    return self.symbols.count;
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    if (row >= self.symbols.count) return @"";
    
    NSString *symbol = self.symbols[row];
    MarketData *data = self.marketDataCache[symbol];
    
    if ([tableColumn.identifier isEqualToString:@"symbol"]) {
        return symbol;
    } else if ([tableColumn.identifier isEqualToString:@"price"]) {
        if (data && data.last) {
            return [NSString stringWithFormat:@"$%.2f", data.last.doubleValue];
        } else {
            return @"Loading...";
        }
    } else if ([tableColumn.identifier isEqualToString:@"change"]) {
        if (data && data.changePercent) {
            return [NSString stringWithFormat:@"%.2f%%", data.changePercent.doubleValue];
        } else {
            return @"Loading...";
        }
    } else if ([tableColumn.identifier isEqualToString:@"tags"]) {
        NSSet *tags = self.symbolTags[symbol];
        if (tags && tags.count > 0) {
            return [tags.allObjects componentsJoinedByString:@", "];
        }
        return @"";
    }
    
    return @"";
}

#pragma mark - NSTableViewDelegate

- (void)tableView:(NSTableView *)tableView willDisplayCell:(id)cell forTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    if (row >= self.symbols.count) return;
    
    NSString *symbol = self.symbols[row];
    MarketData *data = self.marketDataCache[symbol];
    SymbolProperties *properties = [self.watchlistManager propertiesForSymbol:symbol];
    
    // Reset cell colors first
    if ([cell isKindOfClass:[NSTextFieldCell class]]) {
        [(NSTextFieldCell *)cell setBackgroundColor:[NSColor controlBackgroundColor]];
        [(NSTextFieldCell *)cell setTextColor:[NSColor labelColor]];
    }
    
    // Apply custom color from our local storage first
    NSColor *customColor = self.symbolColors[symbol];
    if (customColor && [tableColumn.identifier isEqualToString:@"symbol"] && [cell isKindOfClass:[NSTextFieldCell class]]) {
        [(NSTextFieldCell *)cell setTextColor:customColor];
    }
    
    // Apply custom color to symbol column text from WatchlistManager
    if ([tableColumn.identifier isEqualToString:@"symbol"] && properties.color && [cell isKindOfClass:[NSTextFieldCell class]] && !customColor) {
        [(NSTextFieldCell *)cell setTextColor:properties.color];
    }
    
    // Apply rule-based highlighting to background (if no custom color for symbol)
    if (![tableColumn.identifier isEqualToString:@"symbol"] || (!properties.color && !customColor)) {
        for (WatchlistRule *rule in self.rules) {
            if ([rule evaluateWithData:[data toDictionary]]) {
                if ([cell isKindOfClass:[NSTextFieldCell class]]) {
                    NSColor *ruleColor = [rule.highlightColor colorWithAlphaComponent:0.3];
                    [(NSTextFieldCell *)cell setBackgroundColor:ruleColor];
                }
                break;
            }
        }
    }
    
    // Color coding for change column (text color)
    if ([tableColumn.identifier isEqualToString:@"change"] && data && data.changePercent) {
        NSColor *textColor;
        if (data.changePercent.doubleValue > 0) {
            textColor = [NSColor systemGreenColor];
        } else if (data.changePercent.doubleValue < 0) {
            textColor = [NSColor systemRedColor];
        } else {
            textColor = [NSColor labelColor];
        }
        
        if ([cell isKindOfClass:[NSTextFieldCell class]]) {
            [(NSTextFieldCell *)cell setTextColor:textColor];
        }
    }
}

- (void)tableViewSelectionDidChange:(NSNotification *)notification {
    NSInteger selectedRow = self.tableViewInternal.selectedRow;
    if (selectedRow >= 0 && selectedRow < self.symbols.count) {
        NSString *selectedSymbol = self.symbols[selectedRow];
        
        // Broadcast selected symbol to chained widgets
        if (self.chainedWidgets.count > 0) {
            [self broadcastUpdate:@{@"symbol": selectedSymbol}];
        }
    }
}

#pragma mark - DataManagerDelegate

- (void)dataManager:(id)manager didUpdateQuote:(MarketData *)quote forSymbol:(NSString *)symbol {
    if ([self.symbols containsObject:symbol]) {
        self.marketDataCache[symbol] = quote;
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.tableViewInternal reloadData];
        });
    }
}

- (void)dataManager:(id)manager didFailWithError:(NSError *)error forRequest:(NSString *)requestID {
    NSLog(@"DataManager error: %@", error.localizedDescription);
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.tableViewInternal reloadData];
    });
}

#pragma mark - Rule Management

- (void)addRule:(WatchlistRule *)rule {
    [self.rules addObject:rule];
    [self applyRules];
}

- (void)removeRule:(WatchlistRule *)rule {
    [self.rules removeObject:rule];
    [self applyRules];
}

- (void)applyRules {
    [self.tableViewInternal reloadData];
}

#pragma mark - Data Refresh

- (void)refreshData {
    for (NSString *symbol in self.symbols) {
        [self refreshSymbol:symbol];
    }
}

- (void)refreshSymbol:(NSString *)symbol {
    [self.dataManager requestQuoteForSymbol:symbol completion:^(MarketData *quote, NSError *error) {
        if (quote && !error) {
            self.marketDataCache[symbol] = quote;
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.tableViewInternal reloadData];
            });
        }
    }];
}

#pragma mark - State Management

- (NSDictionary *)serializeState {
    NSMutableDictionary *state = [[super serializeState] mutableCopy];
    state[@"watchlistName"] = self.watchlistName;
    state[@"symbolColors"] = [self.symbolColors copy];
    state[@"symbolTags"] = [self.symbolTags copy];
    return state;
}

- (void)restoreState:(NSDictionary *)state {
    [super restoreState:state];
    
    if (state[@"watchlistName"]) {
        NSString *watchlistName = state[@"watchlistName"];
        [self loadWatchlist:watchlistName];
        self.watchlistComboBoxInternal.stringValue = watchlistName;
    }
    
    if (state[@"symbolColors"]) {
        self.symbolColors = [state[@"symbolColors"] mutableCopy];
    }
    
    if (state[@"symbolTags"]) {
        self.symbolTags = [state[@"symbolTags"] mutableCopy];
    }
}

#pragma mark - Properties

- (NSTableView *)tableView { return self.tableViewInternal; }
- (NSScrollView *)scrollView { return self.scrollViewInternal; }
- (NSTextField *)symbolInputField { return self.symbolInputFieldInternal; }
- (NSButton *)removeButton { return self.removeButtonInternal; }
- (NSComboBox *)watchlistComboBox { return self.watchlistComboBoxInternal; }

#pragma mark - Cleanup

- (void)dealloc {
    [self.refreshTimer invalidate];
    self.refreshTimer = nil;
    
    [[DataManager sharedManager] removeDelegate:self];
    [[DataManager sharedManager] unsubscribeFromQuotes:self.symbols];
}

#pragma mark - Chain


- (NSArray<BaseWidget *> *)findAvailableWidgetsForConnection {
    NSMutableArray<BaseWidget *> *availableWidgets = [NSMutableArray array];
    
    // Trova tutti i widget nell'app tramite la gerarchia di view
    NSWindow *window = self.view.window;
    if (!window) return @[];
    
    [self findWidgetsInView:window.contentView availableWidgets:availableWidgets excludingSelf:YES];
    
    // Rimuovi widget già connessi
    NSMutableArray<BaseWidget *> *filteredWidgets = [availableWidgets mutableCopy];
    [filteredWidgets removeObjectsInArray:self.chainedWidgets.allObjects];
    
    return [filteredWidgets copy];
}

- (void)findWidgetsInView:(NSView *)view availableWidgets:(NSMutableArray<BaseWidget *> *)widgets excludingSelf:(BOOL)excludeSelf {
    // Controlla se questa view appartiene a un BaseWidget
    NSViewController *controller = nil;
    NSResponder *responder = view;
    while (responder && ![responder isKindOfClass:[BaseWidget class]]) {
        responder = [responder nextResponder];
    }
    
    if ([responder isKindOfClass:[BaseWidget class]]) {
        BaseWidget *widget = (BaseWidget *)responder;
        if (!excludeSelf || widget != self) {
            [widgets addObject:widget];
        }
    }
    
    // Ricerca ricorsiva nelle subview
    for (NSView *subview in view.subviews) {
        [self findWidgetsInView:subview availableWidgets:widgets excludingSelf:NO];
    }
}

- (NSString *)panelNameForWidget:(BaseWidget *)widget {
    switch (widget.panelType) {
        case PanelTypeLeft: return @"Left Panel";
        case PanelTypeCenter: return @"Center Panel";
        case PanelTypeRight: return @"Right Panel";
        default: return @"Unknown Panel";
    }
}

- (void)connectToWidget:(NSMenuItem *)sender {
    BaseWidget *targetWidget = sender.representedObject;
    if (!targetWidget) return;
    
    // Connessione bidirezionale
    [self addChainedWidget:targetWidget];
    [(BaseWidget *)targetWidget addChainedWidget:self];

    // Feedback visivo
    [self showConnectionFeedback:[NSString stringWithFormat:@"🔗 Connected to %@", targetWidget.widgetType] success:YES];
    
    NSLog(@"✅ Chain connection established: %@ ↔ %@", self.widgetType, targetWidget.widgetType);
}

- (void)disconnectFromWidget:(NSMenuItem *)sender {
    BaseWidget *targetWidget = sender.representedObject;
    if (!targetWidget) return;
    
    // Disconnessione bidirezionale
    [self removeChainedWidget:targetWidget];
    [targetWidget removeChainedWidget:self];
    
    // Feedback visivo
    [self showConnectionFeedback:[NSString stringWithFormat:@"✖ Disconnected from %@", targetWidget.widgetType] success:NO];
    
    NSLog(@"❌ Chain connection removed: %@ ↮ %@", self.widgetType, targetWidget.widgetType);
}

- (void)disconnectAllChains:(id)sender {
    NSArray<BaseWidget *> *connectedWidgets = [self.chainedWidgets.allObjects copy];
    
    for (BaseWidget *widget in connectedWidgets) {
        [self removeChainedWidget:widget];
        [widget removeChainedWidget:self];
    }
    
    [self showConnectionFeedback:@"✖ Disconnected from all widgets" success:NO];
    
    NSLog(@"❌ All chain connections removed for %@", self.widgetType);
}

- (void)showConnectionFeedback:(NSString *)message success:(BOOL)success {
    // Crea feedback temporaneo
    NSTextField *feedbackLabel = [[NSTextField alloc] init];
    feedbackLabel.stringValue = message;
    feedbackLabel.backgroundColor = success ? [NSColor systemGreenColor] : [NSColor systemOrangeColor];
    feedbackLabel.textColor = [NSColor controlAlternatingRowBackgroundColors].firstObject;
    feedbackLabel.font = [NSFont systemFontOfSize:11 weight:NSFontWeightMedium];
    feedbackLabel.alignment = NSTextAlignmentCenter;
    feedbackLabel.bordered = NO;
    feedbackLabel.editable = NO;
    feedbackLabel.selectable = NO;
    feedbackLabel.wantsLayer = YES;
    feedbackLabel.layer.cornerRadius = 4;
    
    feedbackLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:feedbackLabel];
    
    [NSLayoutConstraint activateConstraints:@[
        [feedbackLabel.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [feedbackLabel.topAnchor constraintEqualToAnchor:self.headerView.bottomAnchor constant:4],
        [feedbackLabel.widthAnchor constraintLessThanOrEqualToAnchor:self.view.widthAnchor constant:-16],
        [feedbackLabel.heightAnchor constraintEqualToConstant:24]
    ]];
    
    // Anima apparizione e scomparsa
    feedbackLabel.layer.opacity = 0;
    [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
        context.duration = 0.3;
        feedbackLabel.animator.layer.opacity = 0.95;
    } completionHandler:^{
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
                context.duration = 0.3;
                feedbackLabel.animator.layer.opacity = 0;
            } completionHandler:^{
                [feedbackLabel removeFromSuperview];
            }];
        });
    }];
}


- (void)addChainedWidget:(BaseWidget *)widget {
    if (!self.chainedWidgets) {
        self.chainedWidgets = [NSMutableSet set];
    }
    [self.chainedWidgets addObject:widget];
    [self updateChainButtonColor];
}

- (void)removeChainedWidget:(BaseWidget *)widget {
    [self.chainedWidgets removeObject:widget];
    [self updateChainButtonColor];
}

- (void)updateChainButtonColor {
    if (self.chainedWidgets.count > 0) {
        // Usa colori distintivi per indicare lo stato connesso
        self.chainButton.contentTintColor = [NSColor systemBlueColor];
        self.chainButton.layer.backgroundColor = [[NSColor systemBlueColor] colorWithAlphaComponent:0.1].CGColor;
        self.chainButton.layer.cornerRadius = 4;
        self.chainButton.layer.borderWidth = 1;
        self.chainButton.layer.borderColor = [NSColor systemBlueColor].CGColor;
    } else {
        self.chainButton.contentTintColor = [NSColor secondaryLabelColor];
        self.chainButton.layer.backgroundColor = [NSColor clearColor].CGColor;
        self.chainButton.layer.borderWidth = 0;
    }
}


@end
