//
//  APIPlaygroundWidget.m
//  TradingApp
//

#import "APIPlaygroundWidget.h"
#import "SchwabDataSource.h"
#import "DataHub.h"
#import "RuntimeModels.h"
#import "DataHub+MarketData.h"

// NUOVO: Enum per la selezione del metodo API
typedef NS_ENUM(NSInteger, APICallMethod) {
    APICallMethodSchwabOriginal = 0,     // fetchPriceHistory (period/frequency)
    APICallMethodSchwabDateRange = 1,    // fetchPriceHistoryWithDateRange
    APICallMethodSchwabWithCount = 2,    // fetchHistoricalDataForSymbolWithCount
    APICallMethodDataHub = 3             // DataHub call
};

@interface APIPlaygroundWidget () <NSTableViewDataSource, NSTableViewDelegate>

@property (nonatomic, strong) SchwabDataSource *schwabDataSource;

// MODIFICATO: Da NSView a NSStackView per supportare la nuova struttura
@property (nonatomic, strong) NSStackView *controlsContainer;

// NUOVO: Proprietà per il selettore metodi
@property (nonatomic, assign) APICallMethod selectedMethod;

@end

@implementation APIPlaygroundWidget

- (void)setupContentView {
    [super setupContentView];
    
    // Inizializzazione
    self.historicalData = [NSMutableArray array];
    self.schwabDataSource = [[SchwabDataSource alloc] init];
    self.selectedMethod = APICallMethodSchwabWithCount; // Default al nuovo metodo
    
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
    
    // NUOVO: Aggiorna visibilità iniziale dei controlli
    [self updateControlsVisibility];
}

- (void)setupControlsSection {
    // MANTENIAMO la struttura originale: tutti i controlli vanno direttamente in historicalTabView
    // Symbol field
    NSTextField *symbolLabel = [self createLabel:@"Symbol:"];
    self.symbolField = [self createTextField:@"AAPL"];
    
    // Date pickers - CONFIGURATI PER TIMEZONE US EASTERN
    NSTextField *startLabel = [self createLabel:@"Start Date:"];
    self.startDatePicker = [[NSDatePicker alloc] init];
    self.startDatePicker.datePickerStyle = NSDatePickerStyleTextFieldAndStepper;
    self.startDatePicker.datePickerElements = NSDatePickerElementFlagYearMonthDay | NSDatePickerElementFlagHourMinute;
    
    // NUOVO: Imposta timezone US Eastern per i DatePickers
    NSTimeZone *easternTimeZone = [NSTimeZone timeZoneWithName:@"America/New_York"];
    self.startDatePicker.timeZone = easternTimeZone;
    
    NSCalendar *calendar = [NSCalendar currentCalendar];
    calendar.timeZone = easternTimeZone; // IMPORTANTE: Anche il calendar deve usare Eastern Time
    
    NSDate *startDefault = [calendar dateByAddingUnit:NSCalendarUnitMonth value:-1 toDate:[NSDate date] options:0];
    NSDateComponents *startComponents = [calendar components:NSCalendarUnitYear|NSCalendarUnitMonth|NSCalendarUnitDay fromDate:startDefault];
    startComponents.hour = 9;    // 9:30 AM Eastern Time (apertura mercato US)
    startComponents.minute = 30;
    startComponents.timeZone = easternTimeZone;
    self.startDatePicker.dateValue = [calendar dateFromComponents:startComponents];
    
    NSTextField *endLabel = [self createLabel:@"End Date:"];
    self.endDatePicker = [[NSDatePicker alloc] init];
    self.endDatePicker.datePickerStyle = NSDatePickerStyleTextFieldAndStepper;
    self.endDatePicker.datePickerElements = NSDatePickerElementFlagYearMonthDay | NSDatePickerElementFlagHourMinute;
    self.endDatePicker.timeZone = easternTimeZone; // NUOVO: Eastern Time anche per end date
    
    NSDateComponents *endComponents = [calendar components:NSCalendarUnitYear|NSCalendarUnitMonth|NSCalendarUnitDay fromDate:[NSDate date]];
    endComponents.hour = 16;     // 4:00 PM Eastern Time (chiusura mercato US)
    endComponents.minute = 0;
    endComponents.timeZone = easternTimeZone;
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
    
    // Period fields (per Schwab API originale)
    NSTextField *periodLabel = [self createLabel:@"Period:"];
    self.periodField = [self createTextField:@"1"];
    
    NSTextField *periodTypeLabel = [self createLabel:@"Period Type:"];
    self.periodTypePopup = [[NSPopUpButton alloc] init];
    [self.periodTypePopup addItemsWithTitles:@[@"day", @"month", @"year", @"ytd"]];
    
    // Frequency fields (per Schwab API originale)
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
    
    // NUOVO: Method selection invece di data source selection
    NSTextField *methodLabel = [self createLabel:@"API Method:"];
    self.methodSelectorPopup = [[NSPopUpButton alloc] init];
    [self.methodSelectorPopup addItemWithTitle:@"Schwab API - Original (period/frequency)"];
    [self.methodSelectorPopup addItemWithTitle:@"Schwab API - Date Range"];
    [self.methodSelectorPopup addItemWithTitle:@"Schwab API - With Count"];
    [self.methodSelectorPopup addItemWithTitle:@"DataHub"];
    
    [self.methodSelectorPopup selectItemAtIndex:APICallMethodSchwabWithCount]; // Default al nuovo metodo
    [self.methodSelectorPopup setTarget:self];
    [self.methodSelectorPopup setAction:@selector(methodSelectionChanged:)];
    
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
    
    // Layout con Stack Views - MODIFICATO per includere il nuovo controllo
    NSStackView *row1 = [self createHorizontalStack:@[symbolLabel, self.symbolField, barCountLabel, self.barCountField, startLabel, self.startDatePicker, endLabel, self.endDatePicker]];
    NSStackView *row2 = [self createHorizontalStack:@[timeframeLabel, self.timeframePopup, self.extendedHoursCheckbox, periodLabel, self.periodField]];
    NSStackView *row3 = [self createHorizontalStack:@[periodTypeLabel, self.periodTypePopup, frequencyLabel, self.frequencyField, frequencyTypeLabel, self.frequencyTypePopup, methodLabel, self.methodSelectorPopup]];
    NSStackView *row4 = [self createHorizontalStack:@[self.parametersLabel, [[NSView alloc] init], self.executeButton, self.clearButton]];
    
    // MODIFICATO: Creiamo il container per i controlli E lo aggiungiamo al historicalTabView
    self.controlsContainer = [[NSStackView alloc] init];
    self.controlsContainer.orientation = NSUserInterfaceLayoutOrientationVertical;
    self.controlsContainer.spacing = 8;
    self.controlsContainer.translatesAutoresizingMaskIntoConstraints = NO;
    
    [self.controlsContainer addArrangedSubview:row1];
    [self.controlsContainer addArrangedSubview:row2];
    [self.controlsContainer addArrangedSubview:row3];
    [self.controlsContainer addArrangedSubview:row4];
    
    // IMPORTANTE: Aggiungiamo il controlsContainer direttamente al historicalTabView
    [self.historicalTabView addSubview:self.controlsContainer];
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
    
    self.rawResponseTextView.autoresizingMask = NSViewWidthSizable;
    
    self.textScrollView.documentView = self.rawResponseTextView;
}

- (void)applyMainLayoutConstraints {
    CGFloat padding = 10.0;
    
    [NSLayoutConstraint activateConstraints:@[
        // 1. Sezione Controlli (in alto)
        [self.controlsContainer.topAnchor constraintEqualToAnchor:self.historicalTabView.topAnchor constant:padding],
        [self.controlsContainer.leadingAnchor constraintEqualToAnchor:self.historicalTabView.leadingAnchor constant:padding],
        [self.controlsContainer.trailingAnchor constraintEqualToAnchor:self.historicalTabView.trailingAnchor constant:-padding],
        
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
    return label;
}

- (NSTextField *)createTextField:(NSString *)placeholder {
    NSTextField *textField = [[NSTextField alloc] init];
    textField.placeholderString = placeholder;
    textField.stringValue = placeholder;
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

#pragma mark - NUOVO: Gestione Selezione Metodo

- (void)methodSelectionChanged:(NSPopUpButton *)sender {
    self.selectedMethod = (APICallMethod)sender.indexOfSelectedItem;
    [self updateControlsVisibility];
    [self updateParametersLabel];
}

- (void)updateControlsVisibility {
    BOOL isOriginalMethod = (self.selectedMethod == APICallMethodSchwabOriginal);
    BOOL isDateRangeMethod = (self.selectedMethod == APICallMethodSchwabDateRange);
    BOOL isCountMethod = (self.selectedMethod == APICallMethodSchwabWithCount);
    BOOL isDataHub = (self.selectedMethod == APICallMethodDataHub);
    
    // Mostra/nascondi controlli specifici per metodo
    
    // Period/Frequency controls (solo per metodo originale)
    self.periodField.hidden = !isOriginalMethod;
    self.periodTypePopup.hidden = !isOriginalMethod;
    self.frequencyField.hidden = !isOriginalMethod;
    self.frequencyTypePopup.hidden = !isOriginalMethod;
    
    // Date range controls (per metodi date range e DataHub)
    self.startDatePicker.hidden = !(isDateRangeMethod || isDataHub);
    self.endDatePicker.hidden = !(isDateRangeMethod || isDataHub);
    
    // Bar count (per metodo count e DataHub)
    self.barCountField.hidden = !(isCountMethod || isDataHub);
    
    // Timeframe (per tutti tranne originale)
    self.timeframePopup.hidden = isOriginalMethod;
    
    // Extended hours (per tutti i metodi Schwab nuovi e DataHub)
    self.extendedHoursCheckbox.hidden = isOriginalMethod;
    
    // Aggiorna anche le label associate - ora cerchiamo nelle arranged subviews del controlsContainer (che è una NSStackView)
    if ([self.controlsContainer isKindOfClass:[NSStackView class]]) {
        NSStackView *mainStack = (NSStackView *)self.controlsContainer;
        for (NSView *rowView in mainStack.arrangedSubviews) {
            if ([rowView isKindOfClass:[NSStackView class]]) {
                NSStackView *rowStack = (NSStackView *)rowView;
                for (NSView *control in rowStack.arrangedSubviews) {
                    if ([control isKindOfClass:[NSTextField class]]) {
                        NSTextField *label = (NSTextField *)control;
                        
                        // Nascondi label associate ai controlli nascosti
                        if ([label.stringValue isEqualToString:@"Period:"] ||
                            [label.stringValue isEqualToString:@"Period Type:"] ||
                            [label.stringValue isEqualToString:@"Frequency:"] ||
                            [label.stringValue isEqualToString:@"Frequency Type:"]) {
                            label.hidden = !isOriginalMethod;
                        }
                        
                        if ([label.stringValue isEqualToString:@"Start Date:"] ||
                            [label.stringValue isEqualToString:@"End Date:"]) {
                            label.hidden = !(isDateRangeMethod || isDataHub);
                        }
                        
                        if ([label.stringValue isEqualToString:@"Bar Count:"]) {
                            label.hidden = !(isCountMethod || isDataHub);
                        }
                        
                        if ([label.stringValue isEqualToString:@"Timeframe:"]) {
                            label.hidden = isOriginalMethod;
                        }
                    }
                }
            }
        }
    }
}

#pragma mark - Actions

- (void)dataSourceChanged:(NSSegmentedControl *)sender {
    // DEPRECATO: Mantenuto per compatibilità ma non più utilizzato
    [self updateParametersLabel];
}

- (void)updateParametersLabel {
    NSString *parametersText = @"";
    
    switch (self.selectedMethod) {
        case APICallMethodSchwabOriginal: {
            // ✅ AGGIORNATO: Mostra che ora usa fetchPriceHistoryWithDateRange
            NSString *periodType = [self.periodTypePopup titleOfSelectedItem];
            NSInteger period = [self.periodField.stringValue integerValue];
            NSString *frequencyType = [self.frequencyTypePopup titleOfSelectedItem];
            NSInteger frequency = [self.frequencyField.stringValue integerValue];
            
            NSDate *endDate = [NSDate date];
            NSDate *startDate = [self calculateStartDateForPeriodType:periodType period:period fromDate:endDate];
            
            NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
            formatter.dateStyle = NSDateFormatterShortStyle;
            formatter.timeStyle = NSDateFormatterShortStyle;
            formatter.timeZone = [NSTimeZone timeZoneWithName:@"America/New_York"];
            
            parametersText = [NSString stringWithFormat:@"fetchPriceHistoryWithDateRange (converted from original): %@ | %@ to %@ (ET) | %@/%ld | extendedHours: NO",
                            self.symbolField.stringValue,
                            [formatter stringFromDate:startDate],
                            [formatter stringFromDate:endDate],
                            frequencyType, (long)frequency];
            break;
        }
        case APICallMethodSchwabDateRange: {
            NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
            formatter.dateStyle = NSDateFormatterShortStyle;
            formatter.timeStyle = NSDateFormatterShortStyle;
            formatter.timeZone = [NSTimeZone timeZoneWithName:@"America/New_York"];
            
            parametersText = [NSString stringWithFormat:@"fetchPriceHistoryWithDateRange: %@ | %@ to %@ (ET) | timeframe: %@ | extendedHours: %@",
                            self.symbolField.stringValue,
                            [formatter stringFromDate:self.startDatePicker.dateValue],
                            [formatter stringFromDate:self.endDatePicker.dateValue],
                            [self.timeframePopup titleOfSelectedItem],
                            self.extendedHoursCheckbox.state == NSControlStateValueOn ? @"YES" : @"NO"];
            break;
        }
        case APICallMethodSchwabWithCount: {
            parametersText = [NSString stringWithFormat:@"fetchHistoricalDataForSymbolWithCount: %@ | timeframe: %@ | count: %@ | extendedHours: %@",
                            self.symbolField.stringValue,
                            [self.timeframePopup titleOfSelectedItem],
                            self.barCountField.stringValue,
                            self.extendedHoursCheckbox.state == NSControlStateValueOn ? @"YES" : @"NO"];
            break;
        }
        case APICallMethodDataHub: {
            NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
            formatter.dateStyle = NSDateFormatterShortStyle;
            formatter.timeStyle = NSDateFormatterShortStyle;
            formatter.timeZone = [NSTimeZone timeZoneWithName:@"America/New_York"];
            
            parametersText = [NSString stringWithFormat:@"DataHub call: %@ | %@ to %@ (ET) | timeframe: %@ | count: %@ | extendedHours: %@",
                            self.symbolField.stringValue,
                            [formatter stringFromDate:self.startDatePicker.dateValue],
                            [formatter stringFromDate:self.endDatePicker.dateValue],
                            [self.timeframePopup titleOfSelectedItem],
                            self.barCountField.stringValue,
                            self.extendedHoursCheckbox.state == NSControlStateValueOn ? @"YES" : @"NO"];
            break;
        }
    }
    
    self.parametersLabel.stringValue = parametersText;
}


- (void)executeHistoricalCall {
    [self updateParametersLabel];
    [self clearResults];
    
    self.executeButton.enabled = NO;
    self.executeButton.title = @"Loading...";
    
    switch (self.selectedMethod) {
        case APICallMethodSchwabOriginal:
            [self executeSchwabOriginalAPICall];
            break;
        case APICallMethodSchwabDateRange:
            [self executeSchwabDateRangeAPICall];
            break;
        case APICallMethodSchwabWithCount:
            [self executeSchwabWithCountAPICall];
            break;
        case APICallMethodDataHub:
            [self executeDataHubCall];
            break;
    }
}

#pragma mark - NUOVO: Metodi di Esecuzione API Separati

- (void)executeSchwabOriginalAPICall {
    NSString *symbol = self.symbolField.stringValue;
    NSString *periodType = [self.periodTypePopup titleOfSelectedItem];
    NSInteger period = [self.periodField.stringValue integerValue];
    NSString *frequencyType = [self.frequencyTypePopup titleOfSelectedItem];
    NSInteger frequency = [self.frequencyField.stringValue integerValue];
    
    // ✅ NUOVO: Converti period/periodType in date range
    NSDate *endDate = [NSDate date];
    NSDate *startDate = [self calculateStartDateForPeriodType:periodType period:period fromDate:endDate];
    
    // ✅ NUOVO: Converti frequencyType/frequency in BarTimeframe
    BarTimeframe timeframe = [self barTimeframeFromFrequencyType:frequencyType frequency:frequency];
    
    NSLog(@"📊 APIPlaygroundWidget: Converting original method call - periodType: %@, period: %ld, frequencyType: %@, frequency: %ld",
          periodType, (long)period, frequencyType, (long)frequency);
    NSLog(@"📊 APIPlaygroundWidget: Converted to date range: %@ to %@, timeframe: %ld",
          startDate, endDate, (long)timeframe);
    
    // ✅ USA IL NUOVO METODO: fetchPriceHistoryWithDateRange con needExtendedHours: NO
    [self.schwabDataSource fetchPriceHistoryWithDateRange:symbol
                                                startDate:startDate
                                                  endDate:endDate
                                                timeframe:timeframe
                                    needExtendedHoursData:NO  // ✅ NO extended hours per "original" method
                                        needPreviousClose:YES
                                               completion:^(NSDictionary *priceHistory, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self handleSchwabResponse:priceHistory error:error];
        });
    }];
}
- (NSDate *)calculateStartDateForPeriodType:(NSString *)periodType period:(NSInteger)period fromDate:(NSDate *)endDate {
    NSCalendar *calendar = [NSCalendar currentCalendar];
    NSDateComponents *components = [[NSDateComponents alloc] init];
    
    if ([periodType isEqualToString:@"day"]) {
        components.day = -period;
    } else if ([periodType isEqualToString:@"month"]) {
        components.month = -period;
    } else if ([periodType isEqualToString:@"year"]) {
        components.year = -period;
    } else if ([periodType isEqualToString:@"ytd"]) {
        // Year to date - torna al 1 gennaio dell'anno corrente
        NSDateComponents *yearComponents = [calendar components:NSCalendarUnitYear fromDate:endDate];
        return [calendar dateFromComponents:yearComponents];
    } else {
        // Default: 1 anno
        components.year = -1;
    }
    
    return [calendar dateByAddingComponents:components toDate:endDate options:0];
}

// ✅ NUOVO: Converti frequencyType/frequency in BarTimeframe
- (BarTimeframe)barTimeframeFromFrequencyType:(NSString *)frequencyType frequency:(NSInteger)frequency {
    if ([frequencyType isEqualToString:@"minute"]) {
        switch (frequency) {
            case 1:
                return BarTimeframe1Min;
            case 5:
                return BarTimeframe5Min;
            case 15:
                return BarTimeframe15Min;
            case 30:
                return BarTimeframe30Min;
            case 60:
                return BarTimeframe1Hour;
            case 240:
                return BarTimeframe4Hour;
            default:
                return BarTimeframe1Min;
        }
    } else if ([frequencyType isEqualToString:@"daily"]) {
        return BarTimeframe1Day;
    } else if ([frequencyType isEqualToString:@"weekly"]) {
        return BarTimeframe1Week;
    } else if ([frequencyType isEqualToString:@"monthly"]) {
        return BarTimeframe1Month;
    }
    
    // Default
    return BarTimeframe1Day;
}


- (void)executeSchwabDateRangeAPICall {
    NSString *symbol = self.symbolField.stringValue;
    NSDate *startDate = self.startDatePicker.dateValue;
    NSDate *endDate = self.endDatePicker.dateValue;
    BarTimeframe timeframe = [self selectedTimeframe];
    BOOL needExtendedHours = self.extendedHoursCheckbox.state == NSControlStateValueOn;
    
    [self.schwabDataSource fetchPriceHistoryWithDateRange:symbol
                                                startDate:startDate
                                                  endDate:endDate
                                                timeframe:timeframe
                                    needExtendedHoursData:needExtendedHours
                                        needPreviousClose:YES
                                               completion:^(NSDictionary *priceHistory, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self handleSchwabResponse:priceHistory error:error];
        });
    }];
}

- (void)executeSchwabWithCountAPICall {
    NSString *symbol = self.symbolField.stringValue;
    BarTimeframe timeframe = [self selectedTimeframe];
    NSInteger count = [self.barCountField.stringValue integerValue];
    BOOL needExtendedHours = self.extendedHoursCheckbox.state == NSControlStateValueOn;
    
    [self.schwabDataSource fetchHistoricalDataForSymbolWithCount:symbol
                                                       timeframe:timeframe
                                                           count:count
                                           needExtendedHoursData:needExtendedHours
                                                needPreviousClose:YES
                                                      completion:^(NSArray *bars, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            // Questo metodo restituisce NSArray invece di NSDictionary
            if (error) {
                [self handleSchwabResponse:nil error:error];
            } else {
                // Convertiamo l'array in formato compatibile per la visualizzazione
                NSDictionary *mockResponse = @{@"candles": bars ?: @[]};
                [self handleSchwabResponse:mockResponse error:nil];
            }
        });
    }];
}

- (void)executeDataHubCall {
    // Chiamata al DataHub (codice esistente invariato)
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
    
    NSArray *errors = response[@"errors"];
    if (errors && [errors isKindOfClass:[NSArray class]] && errors.count > 0) {
        NSLog(@"Schwab API returned errors: %@", errors);
        [self.historicalData removeAllObjects];
        [self.resultsTableView reloadData];
        
        // AGGIUNTO: Genera summary anche per gli errori
        NSString *summary = [self generateSummaryText];
        self.rawResponseTextView.string = [summary stringByAppendingString:self.lastRawResponse];
        [self highlightErrorsInTextView];
        return;
    }
    
    if (error && !response) {
        [self.historicalData removeAllObjects];
        [self.resultsTableView reloadData];
        
        // AGGIUNTO: Genera summary anche per gli errori di rete
        NSString *summary = [self generateSummaryText];
        self.rawResponseTextView.string = [summary stringByAppendingString:self.lastRawResponse];
        return;
    }
    
    [self parseSchwabHistoricalData:response];  // ← PRIMA: Parsing dei dati
    [self.resultsTableView reloadData];
    
    // AGGIUNTO: Genera summary DOPO il parsing dei dati
    NSString *summary = [self generateSummaryText];
    self.rawResponseTextView.string = [summary stringByAppendingString:self.lastRawResponse];
}

- (void)handleDataHubResponse:(NSArray<HistoricalBarModel *> *)bars {
    self.executeButton.enabled = YES;
    self.executeButton.title = @"Execute Call";
    
    [self.historicalData removeAllObjects];
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateFormat = @"HH:mm yyyy-MM-dd";
    
    // NUOVO: Imposta timezone US Eastern anche per DataHub per consistenza
    formatter.timeZone = [NSTimeZone timeZoneWithName:@"America/New_York"];
    
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
                
                // NUOVO: Imposta timezone US Eastern per mostrare l'orario corretto di Wall Street
                formatter.timeZone = [NSTimeZone timeZoneWithName:@"America/New_York"];
                
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
    
    // Modo più sicuro per pulire la text view e i suoi attributi
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
    state[@"selectedMethod"] = @(self.selectedMethod); // NUOVO: Salva il metodo selezionato
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
    if (state[@"selectedMethod"]) {
        self.selectedMethod = [state[@"selectedMethod"] integerValue];
        [self.methodSelectorPopup selectItemAtIndex:self.selectedMethod]; // NUOVO: Ripristina il metodo
        [self updateControlsVisibility]; // NUOVO: Aggiorna la visibilità dei controlli
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
    
    // NUOVO: Usa Eastern Time per consistenza con il resto dell'app
    formatter.timeZone = [NSTimeZone timeZoneWithName:@"America/New_York"];
    
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
