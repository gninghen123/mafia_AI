//
//  APIPlaygroundWidget.m
//  TradingApp
//

#import "APIPlaygroundWidget.h"
#import "SchwabDataSource.h"
#import "DataHub.h"
#import "RuntimeModels.h"
#import "DataHub+MarketData.h" // Corretto l'import secondo il nuovo file

@interface APIPlaygroundWidget () <NSTableViewDataSource, NSTableViewDelegate>

@property (nonatomic, strong) SchwabDataSource *schwabDataSource;

// **FIX**: Aggiungiamo i container come property per accedervi durante il setup dei constraints
@property (nonatomic, strong) NSView *controlsContainer;

@end

@implementation APIPlaygroundWidget

- (void)setupContentView {
    [super setupContentView];
    
    // Inizializzazione
    self.historicalData = [NSMutableArray array];
    self.schwabDataSource = [[SchwabDataSource alloc] init];
    
    [self setupTabView];
    [self setupHistoricalTab];
}

#pragma mark - Tab View Setup

- (void)setupTabView {
    self.tabView = [[NSTabView alloc] init];
    self.tabView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.contentView addSubview:self.tabView];
    
    // Tab Historical Data
    NSTabViewItem *historicalTab = [[NSTabViewItem alloc] init];
    historicalTab.label = @"Historical Data";
    self.historicalTabView = [[NSView alloc] init];
    historicalTab.view = self.historicalTabView;
    [self.tabView addTabViewItem:historicalTab];
    
    // TODO: Altri tab future
    
    // Constraints
    [NSLayoutConstraint activateConstraints:@[
        [self.tabView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor],
        [self.tabView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor],
        [self.tabView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor],
        [self.tabView.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor]
    ]];
}

#pragma mark - Historical Tab Setup

- (void)setupHistoricalTab {
    // 1. Creiamo tutti i componenti UI
    [self setupControlsSection];
    [self setupResultsTable];
    [self setupRawResponseView];
    
    // 2. Applichiamo i constraints principali tutti insieme alla fine
    [self applyMainLayoutConstraints];
    
    [self updateParametersLabel];
}

- (void)setupControlsSection {
    // Container per i controlli
    self.controlsContainer = [[NSView alloc] init];
    self.controlsContainer.translatesAutoresizingMaskIntoConstraints = NO;
    [self.historicalTabView addSubview:self.controlsContainer];
    
    // --- IL RESTO DEL CODICE DEI CONTROLLI RESTA INVARIATO ---
    
    // Symbol field
    NSTextField *symbolLabel = [self createLabel:@"Symbol:"];
    self.symbolField = [self createTextField:@"AAPL"];
    
    // Date pickers
    NSTextField *startLabel = [self createLabel:@"Start Date:"];
    self.startDatePicker = [[NSDatePicker alloc] init];
    self.startDatePicker.datePickerStyle = NSDatePickerStyleTextFieldAndStepper;
    self.startDatePicker.datePickerElements = NSDatePickerElementFlagYearMonthDay | NSDatePickerElementFlagHourMinute;
    NSCalendar *calendar = [NSCalendar currentCalendar];
    NSDate *startDefault = [calendar dateByAddingUnit:NSCalendarUnitMonth value:-1 toDate:[NSDate date] options:0];
    NSDateComponents *startComponents = [calendar components:NSCalendarUnitYear|NSCalendarUnitMonth|NSCalendarUnitDay fromDate:startDefault];
    startComponents.hour = 9;
    startComponents.minute = 30;
    self.startDatePicker.dateValue = [calendar dateFromComponents:startComponents];
    
    NSTextField *endLabel = [self createLabel:@"End Date:"];
    self.endDatePicker = [[NSDatePicker alloc] init];
    self.endDatePicker.datePickerStyle = NSDatePickerStyleTextFieldAndStepper;
    self.endDatePicker.datePickerElements = NSDatePickerElementFlagYearMonthDay | NSDatePickerElementFlagHourMinute;
    NSDateComponents *endComponents = [calendar components:NSCalendarUnitYear|NSCalendarUnitMonth|NSCalendarUnitDay fromDate:[NSDate date]];
    endComponents.hour = 16;
    endComponents.minute = 0;
    self.endDatePicker.dateValue = [calendar dateFromComponents:endComponents];
    
    // Timeframe popup
    NSTextField *timeframeLabel = [self createLabel:@"Timeframe:"];
    self.timeframePopup = [[NSPopUpButton alloc] init];
    [self.timeframePopup addItemsWithTitles:@[@"1 minute", @"5 minutes", @"15 minutes", @"30 minutes", @"1 hour", @"4 hours", @"1 day", @"1 week", @"1 month"]];
    [self.timeframePopup selectItemAtIndex:6];
    
    // Extended hours checkbox
    self.extendedHoursCheckbox = [[NSButton alloc] init];
    [self.extendedHoursCheckbox setButtonType:NSButtonTypeSwitch];
    self.extendedHoursCheckbox.title = @"Include Extended Hours";
    
    // Period fields (per Schwab API)
    NSTextField *periodLabel = [self createLabel:@"Period:"];
    self.periodField = [self createTextField:@"1"];
    
    NSTextField *periodTypeLabel = [self createLabel:@"Period Type:"];
    self.periodTypePopup = [[NSPopUpButton alloc] init];
    [self.periodTypePopup addItemsWithTitles:@[@"day", @"month", @"year", @"ytd"]];
    
    // Frequency fields (per Schwab API)
    NSTextField *frequencyLabel = [self createLabel:@"Frequency:"];
    self.frequencyField = [self createTextField:@"1"];
    
    NSTextField *frequencyTypeLabel = [self createLabel:@"Frequency Type:"];
    self.frequencyTypePopup = [[NSPopUpButton alloc] init];
    [self.frequencyTypePopup addItemsWithTitles:@[@"minute", @"daily", @"weekly", @"monthly"]];
    [self.frequencyTypePopup selectItemAtIndex:1];
    
    // Bar Count control
    NSTextField *barCountLabel = [self createLabel:@"Bar Count:"];
    self.barCountField = [self createTextField:@"100"];
    self.barCountField.formatter = [[NSNumberFormatter alloc] init];
    ((NSNumberFormatter *)self.barCountField.formatter).numberStyle = NSNumberFormatterDecimalStyle;
    
    // Data source selection
    NSTextField *sourceLabel = [self createLabel:@"Data Source:"];
    self.dataSourceSegmented = [[NSSegmentedControl alloc] init];
    self.dataSourceSegmented.segmentCount = 2;
    [self.dataSourceSegmented setLabel:@"Schwab API" forSegment:0];
    [self.dataSourceSegmented setLabel:@"DataHub" forSegment:1];
    self.dataSourceSegmented.selectedSegment = 0;
    [self.dataSourceSegmented setTarget:self];
    [self.dataSourceSegmented setAction:@selector(dataSourceChanged:)];
    
    // Parameters label
    self.parametersLabel = [self createLabel:@""];
    self.parametersLabel.textColor = [NSColor secondaryLabelColor];
    self.parametersLabel.font = [NSFont systemFontOfSize:11];
    
    // Action buttons
    self.executeButton = [NSButton buttonWithTitle:@"Execute Call" target:self action:@selector(executeHistoricalCall)];
    self.executeButton.bezelStyle = NSBezelStyleRounded;
    self.executeButton.keyEquivalent = @"\r";
    
    self.clearButton = [NSButton buttonWithTitle:@"Clear Results" target:self action:@selector(clearResults)];
    self.clearButton.bezelStyle = NSBezelStyleRounded;
    
    // Layout con Stack Views
    NSStackView *row1 = [self createHorizontalStack:@[symbolLabel, self.symbolField, startLabel, self.startDatePicker, endLabel, self.endDatePicker]];
    NSStackView *row2 = [self createHorizontalStack:@[timeframeLabel, self.timeframePopup, self.extendedHoursCheckbox, barCountLabel, self.barCountField, periodLabel, self.periodField]];
    NSStackView *row3 = [self createHorizontalStack:@[periodTypeLabel, self.periodTypePopup, frequencyLabel, self.frequencyField, frequencyTypeLabel, self.frequencyTypePopup, sourceLabel, self.dataSourceSegmented]];
    NSStackView *row4 = [self createHorizontalStack:@[self.parametersLabel, [[NSView alloc] init], self.executeButton, self.clearButton]];
    
    NSStackView *mainStack = [[NSStackView alloc] init];
    mainStack.orientation = NSUserInterfaceLayoutOrientationVertical;
    mainStack.spacing = 8;
    
    [mainStack addArrangedSubview:row1];
    [mainStack addArrangedSubview:row2];
    [mainStack addArrangedSubview:row3];
    [mainStack addArrangedSubview:row4];
    
    mainStack.translatesAutoresizingMaskIntoConstraints = NO;
    [self.controlsContainer addSubview:mainStack];
    
    // Constraints per il mainStack *dentro* al container
    [NSLayoutConstraint activateConstraints:@[
        [mainStack.topAnchor constraintEqualToAnchor:self.controlsContainer.topAnchor],
        [mainStack.leadingAnchor constraintEqualToAnchor:self.controlsContainer.leadingAnchor],
        [mainStack.trailingAnchor constraintEqualToAnchor:self.controlsContainer.trailingAnchor],
        [mainStack.bottomAnchor constraintEqualToAnchor:self.controlsContainer.bottomAnchor]
    ]];
}

- (void)setupResultsTable {
    // Scroll view per la tabella
    self.tableScrollView = [[NSScrollView alloc] init];
    self.tableScrollView.translatesAutoresizingMaskIntoConstraints = NO;
    self.tableScrollView.hasVerticalScroller = YES;
    [self.historicalTabView addSubview:self.tableScrollView];
    
    // Table view
    self.resultsTableView = [[NSTableView alloc] init];
    self.resultsTableView.dataSource = self;
    self.resultsTableView.delegate = self;
    
    // Colonne
    NSArray *columnTitles = @[@"Timestamp", @"Open", @"High", @"Low", @"Close", @"Volume"];
    NSArray *columnIDs = @[@"timestamp", @"open", @"high", @"low", @"close", @"volume"];
    
    for (NSInteger i = 0; i < columnTitles.count; i++) {
        NSTableColumn *column = [[NSTableColumn alloc] initWithIdentifier:columnIDs[i]];
        column.title = columnTitles[i];
        column.width = (i == 0) ? 120 : 80;
        [self.resultsTableView addTableColumn:column];
    }
    
    self.tableScrollView.documentView = self.resultsTableView;
}

- (void)setupRawResponseView {
    // Scroll view per raw response
    self.textScrollView = [[NSScrollView alloc] init];
    self.textScrollView.translatesAutoresizingMaskIntoConstraints = NO;
    self.textScrollView.hasVerticalScroller = YES;
    [self.historicalTabView addSubview:self.textScrollView];
    
    // Text view
    self.rawResponseTextView = [[NSTextView alloc] init];
    self.rawResponseTextView.editable = NO;
    self.rawResponseTextView.font = [NSFont fontWithName:@"Monaco" size:11];
    self.rawResponseTextView.textColor = [NSColor textColor];
    self.rawResponseTextView.backgroundColor = [NSColor textBackgroundColor];
    
    // **FIX**: Questo aiuta la text view a ridimensionarsi correttamente
    self.rawResponseTextView.autoresizingMask = NSViewWidthSizable;
    
    self.textScrollView.documentView = self.rawResponseTextView;
}

- (void)applyMainLayoutConstraints {
    // **NUOVA FUNZIONE PER I CONSTRAINTS PRINCIPALI**
    // Questo è il fix cruciale. Creiamo una catena verticale di vincoli
    // che definisce chiaramente la posizione e la dimensione di ogni elemento.
    // Rimuoviamo tutte le altezze fisse per un layout flessibile.
    
    CGFloat padding = 10.0;
    
    [NSLayoutConstraint activateConstraints:@[
        // 1. Sezione Controlli (in alto)
        [self.controlsContainer.topAnchor constraintEqualToAnchor:self.historicalTabView.topAnchor constant:padding],
        [self.controlsContainer.leadingAnchor constraintEqualToAnchor:self.historicalTabView.leadingAnchor constant:padding],
        [self.controlsContainer.trailingAnchor constraintEqualToAnchor:self.historicalTabView.trailingAnchor constant:-padding],
        // L'altezza è ora determinata dal suo contenuto, non è più fissa a 120.

        // 2. Tabella Risultati (al centro)
        [self.tableScrollView.topAnchor constraintEqualToAnchor:self.controlsContainer.bottomAnchor constant:padding],
        [self.tableScrollView.leadingAnchor constraintEqualToAnchor:self.historicalTabView.leadingAnchor constant:padding],
        [self.tableScrollView.trailingAnchor constraintEqualToAnchor:self.historicalTabView.trailingAnchor constant:-padding],
        
        // 3. Raw Response (in basso)
        [self.textScrollView.topAnchor constraintEqualToAnchor:self.tableScrollView.bottomAnchor constant:padding],
        [self.textScrollView.leadingAnchor constraintEqualToAnchor:self.historicalTabView.leadingAnchor constant:padding],
        [self.textScrollView.trailingAnchor constraintEqualToAnchor:self.historicalTabView.trailingAnchor constant:-padding],
        [self.textScrollView.bottomAnchor constraintEqualToAnchor:self.historicalTabView.bottomAnchor constant:-padding],
        
        // 4. Divisione dello spazio verticale tra tabella e area di testo
        // Diamo alla tabella e all'area di testo la stessa altezza.
        // Questo risolve l'ambiguità e permette al layout di essere flessibile.
        [self.tableScrollView.heightAnchor constraintEqualToAnchor:self.textScrollView.heightAnchor multiplier:1.0],
    ]];
}


#pragma mark - Helper Methods

- (NSTextField *)createLabel:(NSString *)text {
    NSTextField *label = [[NSTextField alloc] init];
    label.stringValue = text;
    label.editable = NO;
    label.bordered = NO;
    label.backgroundColor = [NSColor clearColor];
    label.font = [NSFont systemFontOfSize:12];
    [label setContentHuggingPriority:NSLayoutPriorityRequired forOrientation:NSLayoutConstraintOrientationHorizontal];
    return label;
}

- (NSTextField *)createTextField:(NSString *)placeholder {
    NSTextField *textField = [[NSTextField alloc] init];
    textField.placeholderString = placeholder;
    textField.stringValue = placeholder;
    [textField setContentHuggingPriority:NSLayoutPriorityDefaultLow forOrientation:NSLayoutConstraintOrientationHorizontal];
    return textField;
}

- (NSStackView *)createHorizontalStack:(NSArray<NSView *> *)views {
    NSStackView *stack = [[NSStackView alloc] init];
    stack.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    stack.spacing = 8;
    stack.alignment = NSLayoutAttributeCenterY;
    
    for (NSView *view in views) {
        [stack addArrangedSubview:view];
    }
    
    return stack;
}

#pragma mark - Actions

- (void)dataSourceChanged:(NSSegmentedControl *)sender {
    [self updateParametersLabel];
}

- (void)updateParametersLabel {
    NSString *parametersText = @"";
    
    if (self.dataSourceSegmented.selectedSegment == 0) {
        // Schwab API
        parametersText = [NSString stringWithFormat:@"Parameters for Schwab API: symbol=%@, periodType=%@, period=%@, frequencyType=%@, frequency=%@",
                          self.symbolField.stringValue,
                          [self.periodTypePopup titleOfSelectedItem],
                          self.periodField.stringValue,
                          [self.frequencyTypePopup titleOfSelectedItem],
                          self.frequencyField.stringValue];
    } else {
        // DataHub
        NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
        formatter.dateFormat = @"yyyy-MM-dd HH:mm";
        
        parametersText = [NSString stringWithFormat:@"Parameters for DataHub: symbol=%@, startDate=%@, endDate=%@, timeframe=%@, barCount=%@, extendedHours=%@",
                          self.symbolField.stringValue,
                          [formatter stringFromDate:self.startDatePicker.dateValue],
                          [formatter stringFromDate:self.endDatePicker.dateValue],
                          [self.timeframePopup titleOfSelectedItem],
                          self.barCountField.stringValue ?: @"100",
                          self.extendedHoursCheckbox.state == NSControlStateValueOn ? @"YES" : @"NO"];
    }
    
    self.parametersLabel.stringValue = parametersText;
}

- (void)executeHistoricalCall {
    [self updateParametersLabel];
    [self clearResults];
    
    self.executeButton.enabled = NO;
    self.executeButton.title = @"Loading...";
    
    if (self.dataSourceSegmented.selectedSegment == 0) {
        [self executeSchwabAPICall];
    } else {
        [self executeDataHubCall];
    }
}

- (void)executeSchwabAPICall {
    // Chiamata diretta alla Schwab API bypassando DataHub
    NSString *symbol = self.symbolField.stringValue;
    NSString *periodType = [self.periodTypePopup titleOfSelectedItem];
    NSInteger period = [self.periodField.stringValue integerValue];
    NSString *frequencyType = [self.frequencyTypePopup titleOfSelectedItem];
    NSInteger frequency = [self.frequencyField.stringValue integerValue];
    
    [self.schwabDataSource fetchPriceHistory:symbol
                                  periodType:periodType
                                      period:period
                               frequencyType:frequencyType
                                   frequency:frequency
                                  completion:^(NSDictionary *priceHistory, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self handleSchwabResponse:priceHistory error:error];
        });
    }];
}

- (void)executeDataHubCall {
    // Chiamata al DataHub
    NSString *symbol = self.symbolField.stringValue;
    BarTimeframe timeframe = [self selectedTimeframe];
    BOOL extendedHours = self.extendedHoursCheckbox.state == NSControlStateValueOn;
    NSInteger barCount = [self.barCountField.stringValue integerValue];
    
    [[DataHub shared] getHistoricalBarsForSymbol:symbol
                                        timeframe:timeframe
                                         barCount:barCount
                                needExtendedHours:extendedHours
                                       completion:^(NSArray<HistoricalBarModel *> *bars, BOOL isFresh) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self handleDataHubResponse:bars];
        });
    }];
}

- (BarTimeframe)selectedTimeframe {
    NSInteger index = [self.timeframePopup indexOfSelectedItem];
    switch (index) {
        case 0: return BarTimeframe1Min;
        case 1: return BarTimeframe5Min;
        case 2: return BarTimeframe15Min;
        case 3: return BarTimeframe30Min;
        case 4: return BarTimeframe1Hour;
        case 5: return BarTimeframe4Hour;
        case 6: return BarTimeframe1Day;
        case 7: return BarTimeframe1Week;
        case 8: return BarTimeframe1Month;
        default: return BarTimeframe1Day;
    }
}

- (void)handleSchwabResponse:(NSDictionary *)response error:(NSError *)error {
    self.executeButton.enabled = YES;
    self.executeButton.title = @"Execute Call";
    
    if (response) {
        NSData *jsonData = [NSJSONSerialization dataWithJSONObject:response options:NSJSONWritingPrettyPrinted error:nil];
        self.lastRawResponse = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    } else if (error) {
        self.lastRawResponse = [NSString stringWithFormat:@"NETWORK ERROR: %@", error.localizedDescription];
    } else {
        self.lastRawResponse = @"UNKNOWN ERROR: No response and no error";
    }
    NSString *summary = [self generateSummaryText];
    self.rawResponseTextView.string = [summary stringByAppendingString:self.lastRawResponse];
    
    self.rawResponseTextView.string = self.lastRawResponse;
    
    NSArray *errors = response[@"errors"];
    if (errors && [errors isKindOfClass:[NSArray class]] && errors.count > 0) {
        NSLog(@"Schwab API returned errors: %@", errors);
        [self.historicalData removeAllObjects];
        [self.resultsTableView reloadData];
        [self highlightErrorsInTextView];
        return;
    }
    
    if (error && !response) {
        [self.historicalData removeAllObjects];
        [self.resultsTableView reloadData];
        return;
    }
    
    [self parseSchwabHistoricalData:response];
    [self.resultsTableView reloadData];
}

- (void)handleDataHubResponse:(NSArray<HistoricalBarModel *> *)bars {
    self.executeButton.enabled = YES;
    self.executeButton.title = @"Execute Call";
    
    [self.historicalData removeAllObjects];
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateFormat = @"HH:mm yyyy-MM-dd";
    
    // Creiamo una rappresentazione JSON per la visualizzazione
    NSMutableArray *displayArray = [NSMutableArray array];
    for (HistoricalBarModel *bar in bars) {
        NSMutableDictionary *barDict = [[bar toDictionary] mutableCopy];
        
        if (bar.date) {
            barDict[@"timestamp"] = [formatter stringFromDate:bar.date];
        } else {
            barDict[@"timestamp"] = @"N/A";
        }
        
        [self.historicalData addObject:barDict];
        [displayArray addObject:barDict]; // Usiamo lo stesso dizionario per la raw response
    }
    
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:displayArray options:NSJSONWritingPrettyPrinted error:nil];
    self.lastRawResponse = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    
    NSString *summary = [self generateSummaryText];
    self.rawResponseTextView.string = [summary stringByAppendingString:self.lastRawResponse];
    
    self.rawResponseTextView.string = self.lastRawResponse;
    
    [self.resultsTableView reloadData];
}

- (void)parseSchwabHistoricalData:(NSDictionary *)response {
    [self.historicalData removeAllObjects];
    
    NSArray *candles = response[@"candles"];
    if ([candles isKindOfClass:[NSArray class]]) {
        for (NSDictionary *candle in candles) {
            NSMutableDictionary *barData = [NSMutableDictionary dictionary];
            
            NSNumber *datetime = candle[@"datetime"];
            if (datetime) {
                NSDate *date = [NSDate dateWithTimeIntervalSince1970:[datetime doubleValue] / 1000.0];
                NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
                formatter.dateFormat = @"HH:mm yyyy-MM-dd";
                barData[@"timestamp"] = [formatter stringFromDate:date];
            }
            
            barData[@"open"] = candle[@"open"] ?: @0;
            barData[@"high"] = candle[@"high"] ?: @0;
            barData[@"low"] = candle[@"low"] ?: @0;
            barData[@"close"] = candle[@"close"] ?: @0;
            barData[@"volume"] = candle[@"volume"] ?: @0;
            
            [self.historicalData addObject:barData];
        }
    }
}

- (void)clearResults {
    [self.historicalData removeAllObjects];
    [self.resultsTableView reloadData];
    self.lastRawResponse = @"";
    
    // **FIX**: Modo più sicuro per pulire la text view e i suoi attributi.
    [self.rawResponseTextView.textStorage setAttributedString:[[NSAttributedString alloc] initWithString:@""]];
}

- (void)highlightErrorsInTextView {
    NSString *text = self.rawResponseTextView.string;
    NSRange errorsRange = [text rangeOfString:@"\"errors\""];
    
    if (errorsRange.location != NSNotFound) {
        NSMutableAttributedString *attributedText = [[NSMutableAttributedString alloc] initWithString:text];
        [attributedText addAttribute:NSForegroundColorAttributeName
                               value:[NSColor systemRedColor]
                               range:NSMakeRange(0, text.length)];
        
        NSRange errorSectionStart = [text rangeOfString:@"\"errors\""];
        if (errorSectionStart.location != NSNotFound) {
            NSRange searchRange = NSMakeRange(errorSectionStart.location, text.length - errorSectionStart.location);
            NSRange errorSectionEnd = [text rangeOfString:@"]" options:0 range:searchRange];
            
            if (errorSectionEnd.location != NSNotFound) {
                NSRange fullErrorRange = NSMakeRange(errorSectionStart.location,
                                                     errorSectionEnd.location - errorSectionStart.location + 1);
                [attributedText addAttribute:NSFontAttributeName
                                       value:[NSFont boldSystemFontOfSize:11]
                                       range:fullErrorRange];
            }
        }
        
        [self.rawResponseTextView.textStorage setAttributedString:attributedText];
    }
}

#pragma mark - NSTableViewDataSource

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    return self.historicalData.count;
}

#pragma mark - NSTableViewDelegate

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    NSTableCellView *cellView = [tableView makeViewWithIdentifier:tableColumn.identifier owner:self];
    
    if (!cellView) {
        cellView = [[NSTableCellView alloc] init];
        cellView.identifier = tableColumn.identifier;
        
        NSTextField *textField = [[NSTextField alloc] init];
        textField.translatesAutoresizingMaskIntoConstraints = NO;
        textField.bordered = NO;
        textField.editable = NO;
        textField.backgroundColor = [NSColor clearColor];
        textField.font = [NSFont systemFontOfSize:11];
        
        [cellView addSubview:textField];
        cellView.textField = textField;
        
        [NSLayoutConstraint activateConstraints:@[
            [textField.leadingAnchor constraintEqualToAnchor:cellView.leadingAnchor constant:5],
            [textField.trailingAnchor constraintEqualToAnchor:cellView.trailingAnchor constant:-5],
            [textField.centerYAnchor constraintEqualToAnchor:cellView.centerYAnchor]
        ]];
    }
    
    NSDictionary *rowData = self.historicalData[row];
    NSString *columnID = tableColumn.identifier;
    
    id value = rowData[columnID];
    if ([value isKindOfClass:[NSNumber class]]) {
        if ([columnID isEqualToString:@"volume"]) {
            cellView.textField.stringValue = [NSString stringWithFormat:@"%@", value];
        } else {
            cellView.textField.stringValue = [NSString stringWithFormat:@"%.2f", [value doubleValue]];
        }
    } else {
        cellView.textField.stringValue = [value description] ?: @"";
    }
    
    return cellView;
}

#pragma mark - Widget State Management

- (NSDictionary *)serializeState {
    NSMutableDictionary *state = [[super serializeState] mutableCopy];
    
    // Salva i valori dei controlli
    state[@"symbol"] = self.symbolField.stringValue;
    state[@"selectedDataSource"] = @(self.dataSourceSegmented.selectedSegment);
    state[@"selectedTimeframe"] = @([self.timeframePopup indexOfSelectedItem]);
    state[@"extendedHours"] = @(self.extendedHoursCheckbox.state == NSControlStateValueOn);
    state[@"barCount"] = self.barCountField.stringValue ?: @"100";
    
    return state;
}

- (void)restoreState:(NSDictionary *)state {
    [super restoreState:state];
    
    // Ripristina i valori dei controlli
    if (state[@"symbol"]) {
        self.symbolField.stringValue = state[@"symbol"];
    }
    if (state[@"selectedDataSource"]) {
        self.dataSourceSegmented.selectedSegment = [state[@"selectedDataSource"] integerValue];
    }
    if (state[@"selectedTimeframe"]) {
        [self.timeframePopup selectItemAtIndex:[state[@"selectedTimeframe"] integerValue]];
    }
    if (state[@"extendedHours"]) {
        self.extendedHoursCheckbox.state = [state[@"extendedHours"] boolValue] ? NSControlStateValueOn : NSControlStateValueOff;
    }
    if (state[@"barCount"]) {
        self.barCountField.stringValue = [state[@"barCount"] stringValue];
    }
    
    [self updateParametersLabel];
}
- (NSString *)formattedDateStringFromDate:(NSDate *)date {
    if (!date) {
        return @"N/A";
    }
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateFormat = @"HH:mm dd/MM/yyyy";
    return [formatter stringFromDate:date];
}

- (NSString *)generateSummaryText {
    if (self.historicalData.count == 0) {
        return @"No data loaded.\n\n";
    }

    NSDictionary *firstBar = self.historicalData.firstObject;
    NSDictionary *lastBar = self.historicalData.lastObject;

    NSString *firstDate = firstBar[@"timestamp"] ?: @"N/A";
    NSString *lastDate = lastBar[@"timestamp"] ?: @"N/A";

    return [NSString stringWithFormat:
        @"Summary:\nBars: %ld\nFirst: %@\nLast: %@\n\n",
        (long)self.historicalData.count, firstDate, lastDate];
}

@end
