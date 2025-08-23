//
//  OrderEntryViewController.m
//  TradingApp
//
//  Implementation of advanced order entry system
//

#import "OrderEntryViewController.h"
#import "DataHub+Portfolio.h"
#import "DataHub+MarketData.h"
#import "OrderQuantityCalculator.h"
#import "AdvancedOrderBuilder.h"

@interface OrderEntryViewController ()

/// Timer for market data refresh
@property (nonatomic, strong) NSTimer *marketDataRefreshTimer;

/// Last quote refresh timestamp
@property (nonatomic, strong) NSDate *lastQuoteRefresh;

/// Form validation timer (debounced)
@property (nonatomic, strong) NSTimer *validationTimer;

/// Current symbol being tracked
@property (nonatomic, strong) NSString *currentSymbol;

@end

@implementation OrderEntryViewController

#pragma mark - View Lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Initialize form state
    self.currentQuantityMode = QuantityModeShares;
    self.currentProfitTargetMode = ProfitTargetModePercent;
    self.currentStopLossMode = StopLossModePercent;
    self.bracketOrdersEnabled = NO;
    
    [self setupUI];
    [self setupNotificationObservers];
    [self setupDefaultValues];
    [self startMarketDataRefresh];
    
    NSLog(@"📝 OrderEntryViewController loaded");
}

- (void)viewWillDisappear {
    [super viewWillDisappear];
    [self stopMarketDataRefresh];
}

- (void)dealloc {
    [self stopMarketDataRefresh];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    NSLog(@"📝 OrderEntryViewController deallocated");
}

#pragma mark - UI Setup

- (void)setupUI {
    [self setupSymbolSection];
    [self setupMarketDataPanel];
    [self setupOrderTypeSection];
    [self setupQuantitySection];
    [self setupPriceSection];
    [self setupBracketOrdersSection];
    [self setupRiskManagementPanel];
    [self setupPresetsPanel];
    [self setupOrderPreviewSection];
    [self setupLayoutConstraints];
    
    // Initial UI state
    [self updateUIForOrderType:@"MARKET"];
    [self updateBracketOrdersVisibility];
}

- (void)setupSymbolSection {
    // Symbol field setup
    self.symbolField.placeholderString = @"Enter symbol (e.g. AAPL)";
    [self.symbolField setTarget:self];
    [self.symbolField setAction:@selector(symbolFieldChanged:)];
    
    // Lookup button
    [self.symbolLookupButton setTarget:self];
    [self.symbolLookupButton setAction:@selector(lookupSymbol:)];
    [self.symbolLookupButton setTitle:@"📊"];
}

- (void)setupMarketDataPanel {
    // Initialize market data labels
    [self clearMarketData];
    
    // Style market data panel
    self.marketDataPanel.wantsLayer = YES;
    self.marketDataPanel.layer.backgroundColor = [NSColor controlBackgroundColor].CGColor;
    self.marketDataPanel.layer.cornerRadius = 6.0;
    self.marketDataPanel.layer.borderWidth = 1.0;
    self.marketDataPanel.layer.borderColor = [NSColor separatorColor].CGColor;
}

- (void)setupOrderTypeSection {
    // Order type popup
    [self.orderTypePopup removeAllItems];
    [self.orderTypePopup addItemsWithTitles:@[@"MARKET", @"LIMIT", @"STOP", @"STOP_LIMIT"]];
    [self.orderTypePopup selectItemWithTitle:@"MARKET"];
    [self.orderTypePopup setTarget:self];
    [self.orderTypePopup setAction:@selector(orderTypeChanged:)];
    
    // Side popup
    [self.sidePopup removeAllItems];
    [self.sidePopup addItemsWithTitles:@[@"BUY", @"SELL", @"SELL_SHORT"]];
    [self.sidePopup selectItemWithTitle:@"BUY"];
    [self.sidePopup setTarget:self];
    [self.sidePopup setAction:@selector(sideChanged:)];
    
    // Time in force popup
    [self.timeInForcePopup removeAllItems];
    [self.timeInForcePopup addItemsWithTitles:@[@"DAY", @"GTC", @"IOC", @"FOK"]];
    [self.timeInForcePopup selectItemWithTitle:@"DAY"];
    [self.timeInForcePopup setTarget:self];
    [self.timeInForcePopup setAction:@selector(timeInForceChanged:)];
}

- (void)setupQuantitySection {
    // Quantity mode control
    [self.quantityModeControl setSegmentCount:5];
    [self.quantityModeControl setLabel:@"Shares" forSegment:QuantityModeShares];
    [self.quantityModeControl setLabel:@"% Portfolio" forSegment:QuantityModePortfolioPercent];
    [self.quantityModeControl setLabel:@"% Cash" forSegment:QuantityModeCashPercent];
    [self.quantityModeControl setLabel:@"$ Amount" forSegment:QuantityModeDollarAmount];
    [self.quantityModeControl setLabel:@"Risk $" forSegment:QuantityModeRiskAmount];
    [self.quantityModeControl setSelectedSegment:QuantityModeShares];
    [self.quantityModeControl setTarget:self];
    [self.quantityModeControl setAction:@selector(quantityModeChanged:)];
    
    // Quantity field
    self.quantityField.placeholderString = @"100";
    [self.quantityField setTarget:self];
    [self.quantityField setAction:@selector(quantityFieldChanged:)];
    
    // Initialize calculated labels
    self.calculatedSharesLabel.stringValue = @"";
    self.positionValueLabel.stringValue = @"";
    self.portfolioPercentLabel.stringValue = @"";
}

- (void)setupPriceSection {
    // Price fields
    self.limitPriceField.placeholderString = @"0.00";
    [self.limitPriceField setTarget:self];
    [self.limitPriceField setAction:@selector(limitPriceChanged:)];
    
    self.stopPriceField.placeholderString = @"0.00";
    [self.stopPriceField setTarget:self];
    [self.stopPriceField setAction:@selector(stopPriceChanged:)];
    
    // Quick price buttons
    [self.setBidPriceButton setTarget:self];
    [self.setBidPriceButton setAction:@selector(setBidPrice:)];
    [self.setBidPriceButton setTitle:@"Bid"];
    
    [self.setAskPriceButton setTarget:self];
    [self.setAskPriceButton setAction:@selector(setAskPrice:)];
    [self.setAskPriceButton setTitle:@"Ask"];
    
    [self.setLastPriceButton setTarget:self];
    [self.setLastPriceButton setAction:@selector(setLastPrice:)];
    [self.setLastPriceButton setTitle:@"Last"];
}

- (void)setupBracketOrdersSection {
    // Enable bracket orders checkbox
    [self.enableBracketOrdersCheckbox setTarget:self];
    [self.enableBracketOrdersCheckbox setAction:@selector(bracketOrdersToggled:)];
    [self.enableBracketOrdersCheckbox setState:NSControlStateValueOff];
    
    // Profit target mode control
    [self.profitTargetModeControl setSegmentCount:4];
    [self.profitTargetModeControl setLabel:@"Price" forSegment:ProfitTargetModePrice];
    [self.profitTargetModeControl setLabel:@"%" forSegment:ProfitTargetModePercent];
    [self.profitTargetModeControl setLabel:@"$" forSegment:ProfitTargetModeDollarAmount];
    [self.profitTargetModeControl setLabel:@"R:R" forSegment:ProfitTargetModeRRRatio];
    [self.profitTargetModeControl setSelectedSegment:ProfitTargetModePercent];
    [self.profitTargetModeControl setTarget:self];
    [self.profitTargetModeControl setAction:@selector(profitTargetModeChanged:)];
    
    // Stop loss mode control
    [self.stopLossModeControl setSegmentCount:6];
    [self.stopLossModeControl setLabel:@"Price" forSegment:StopLossModePrice];
    [self.stopLossModeControl setLabel:@"%" forSegment:StopLossModePercent];
    [self.stopLossModeControl setLabel:@"$" forSegment:StopLossModeDollarAmount];
    [self.stopLossModeControl setLabel:@"ATR" forSegment:StopLossModeATR];
    [self.stopLossModeControl setLabel:@"Day Low" forSegment:StopLossModeDayLow];
    [self.stopLossModeControl setLabel:@"Day High" forSegment:StopLossModeDayHigh];
    [self.stopLossModeControl setSelectedSegment:StopLossModePercent];
    [self.stopLossModeControl setTarget:self];
    [self.stopLossModeControl setAction:@selector(stopLossModeChanged:)];
    
    // Bracket order fields
    self.profitTargetField.placeholderString = @"10.0";
    [self.profitTargetField setTarget:self];
    [self.profitTargetField setAction:@selector(profitTargetFieldChanged:)];
    
    self.stopLossField.placeholderString = @"3.0";
    [self.stopLossField setTarget:self];
    [self.stopLossField setAction:@selector(stopLossFieldChanged:)];
}

- (void)setupRiskManagementPanel {
    // Initialize risk labels
    self.riskAmountLabel.stringValue = @"Risk: --";
    self.rewardAmountLabel.stringValue = @"Reward: --";
    self.riskRewardRatioLabel.stringValue = @"R:R: --";
    self.portfolioRiskLabel.stringValue = @"Portfolio Risk: --%";
    self.maxLossLabel.stringValue = @"Max Loss: --";
    
    // Style risk panel
    self.riskManagementPanel.wantsLayer = YES;
    self.riskManagementPanel.layer.backgroundColor = [NSColor controlBackgroundColor].CGColor;
    self.riskManagementPanel.layer.cornerRadius = 6.0;
    self.riskManagementPanel.layer.borderWidth = 1.0;
    self.riskManagementPanel.layer.borderColor = [NSColor systemOrangeColor].CGColor;
}

- (void)setupPresetsPanel {
    // Preset buttons
    [self.scalpPresetButton setTarget:self];
    [self.scalpPresetButton setAction:@selector(applyScalpPreset:)];
    [self.scalpPresetButton setTitle:@"Scalp (0.5% SL, 1% TP)"];
    
    [self.swingPresetButton setTarget:self];
    [self.swingPresetButton setAction:@selector(applySwingPreset:)];
    [self.swingPresetButton setTitle:@"Swing (3% SL, 10% TP)"];
    
    [self.breakoutPresetButton setTarget:self];
    [self.breakoutPresetButton setAction:@selector(applyBreakoutPreset:)];
    [self.breakoutPresetButton setTitle:@"Breakout (Day Range)"];
    
    [self.customPreset1Button setTarget:self];
    [self.customPreset1Button setAction:@selector(applyCustomPreset1:)];
    [self.customPreset1Button setTitle:@"Custom 1"];
    
    [self.customPreset2Button setTarget:self];
    [self.customPreset2Button setAction:@selector(applyCustomPreset2:)];
    [self.customPreset2Button setTitle:@"Custom 2"];
}

- (void)setupOrderPreviewSection {
    // Order preview text view
    self.orderPreviewTextView.editable = NO;
    self.orderPreviewTextView.font = [NSFont monospacedSystemFontOfSize:12 weight:NSFontWeightRegular];
    self.orderPreviewTextView.backgroundColor = [NSColor controlBackgroundColor];
    self.orderPreviewTextView.string = @"Enter order details to see preview...";
    
    // Action buttons
    [self.validateOrderButton setTarget:self];
    [self.validateOrderButton setAction:@selector(validateOrder:)];
    [self.validateOrderButton setTitle:@"Validate Order"];
    
    [self.submitOrderButton setTarget:self];
    [self.submitOrderButton setAction:@selector(submitOrder:)];
    [self.submitOrderButton setTitle:@"Submit Order"];
    [self.submitOrderButton setKeyEquivalent:@"\r"];
    
    [self.resetFormButton setTarget:self];
    [self.resetFormButton setAction:@selector(resetForm:)];
    [self.resetFormButton setTitle:@"Reset Form"];
}

- (void)setupLayoutConstraints {
    // This would contain all the Auto Layout constraints
    // Simplified for brevity - in real implementation, this would be extensive
    NSLog(@"📐 OrderEntry: Layout constraints setup complete");
}

- (void)setupDefaultValues {
    // Set reasonable defaults
    self.quantityField.stringValue = @"100";
    self.profitTargetField.stringValue = @"10.0";
    self.stopLossField.stringValue = @"3.0";
    
    [self recalculateAllValues];
}

#pragma mark - Notification Observers

- (void)setupNotificationObservers {
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    
    // Quote updates
    [nc addObserver:self
           selector:@selector(handleQuoteUpdate:)
               name:DataHubQuoteUpdatedNotification
             object:nil];
    
    // Portfolio updates
    [nc addObserver:self
           selector:@selector(handlePortfolioUpdate:)
               name:PortfolioSummaryUpdatedNotification
             object:nil];
}

- (void)handleQuoteUpdate:(NSNotification *)notification {
    NSString *symbol = notification.userInfo[@"symbol"];
    MarketQuoteModel *quote = notification.userInfo[@"quote"];
    
    if ([symbol isEqualToString:self.currentSymbol]) {
        [self updateMarketDataForSymbol:symbol quote:(TradingQuoteModel *)quote];
    }
}

- (void)handlePortfolioUpdate:(NSNotification *)notification {
    PortfolioSummaryModel *portfolio = notification.userInfo[@"summary"];
    self.currentPortfolio = portfolio;
    [self recalculateAllValues];
}

#pragma mark - Market Data Management

- (void)updateMarketDataForSymbol:(NSString *)symbol quote:(TradingQuoteModel *)quote {
    if (!symbol || !quote) return;
    
    self.currentQuote = quote;
    self.lastQuoteRefresh = [NSDate date];
    
    // Update market data display
    self.lastPriceLabel.stringValue = [NSString stringWithFormat:@"Last: %.2f", quote.lastPrice];
    self.bidLabel.stringValue = [NSString stringWithFormat:@"Bid: %.2f", quote.bid];
    self.askLabel.stringValue = [NSString stringWithFormat:@"Ask: %.2f", quote.ask];
    
    double spread = quote.ask - quote.bid;
    self.spreadLabel.stringValue = [NSString stringWithFormat:@"Spread: %.2f", spread];
    
    self.volumeLabel.stringValue = [NSString stringWithFormat:@"Vol: %@", [self formatVolume:quote.volume]];
    self.dayRangeLabel.stringValue = [NSString stringWithFormat:@"Range: %.2f - %.2f", quote.low, quote.high];
    
    // Color code change
    NSColor *changeColor = quote.change >= 0 ? [NSColor systemGreenColor] : [NSColor systemRedColor];
    NSString *changeText = [NSString stringWithFormat:@"%.2f (%.2f%%)", quote.change, quote.changePercent];
    self.changeLabel.stringValue = changeText;
    self.changeLabel.textColor = changeColor;
    
    // Recalculate all values with new price data
    [self recalculateAllValues];
    
    NSLog(@"📊 OrderEntry: Updated market data for %@ - Last: %.2f, Bid: %.2f, Ask: %.2f",
          symbol, quote.lastPrice, quote.bid, quote.ask);
}

- (void)refreshMarketData {
    if (self.currentSymbol.length == 0) return;
    
    [[DataHub sharedDataHub] getQuoteForSymbol:self.currentSymbol completion:^(MarketQuoteModel *quote, BOOL isLive) {
        if (quote) {
            [self updateMarketDataForSymbol:self.currentSymbol quote:(TradingQuoteModel *)quote];
        }
    }];
}

- (void)clearMarketData {
    self.currentQuote = nil;
    self.lastPriceLabel.stringValue = @"Last: --";
    self.bidLabel.stringValue = @"Bid: --";
    self.askLabel.stringValue = @"Ask: --";
    self.spreadLabel.stringValue = @"Spread: --";
    self.volumeLabel.stringValue = @"Vol: --";
    self.dayRangeLabel.stringValue = @"Range: --";
    self.changeLabel.stringValue = @"Change: --";
    self.changeLabel.textColor = [NSColor labelColor];
}

- (void)startMarketDataRefresh {
    if (self.marketDataRefreshTimer) {
        [self.marketDataRefreshTimer invalidate];
    }
    
    // Refresh market data every 5 seconds
    self.marketDataRefreshTimer = [NSTimer scheduledTimerWithTimeInterval:5.0
                                                                   target:self
                                                                 selector:@selector(refreshMarketData)
                                                                 userInfo:nil
                                                                  repeats:YES];
}

- (void)stopMarketDataRefresh {
    if (self.marketDataRefreshTimer) {
        [self.marketDataRefreshTimer invalidate];
        self.marketDataRefreshTimer = nil;
    }
}

#pragma mark - Form Actions

- (IBAction)symbolFieldChanged:(NSTextField *)sender {
    NSString *symbol = sender.stringValue.uppercaseString;
    
    if (symbol.length == 0) {
        [self clearMarketData];
        self.currentSymbol = nil;
        return;
    }
    
    // Update symbol field to uppercase
    sender.stringValue = symbol;
    
    // Only refresh if symbol actually changed
    if (![symbol isEqualToString:self.currentSymbol]) {
        self.currentSymbol = symbol;
        
        // Clear old data
        [self clearMarketData];
        
        // Debounce symbol lookup
        [self.validationTimer invalidate];
        self.validationTimer = [NSTimer scheduledTimerWithTimeInterval:0.5
                                                                 target:self
                                                               selector:@selector(lookupCurrentSymbol)
                                                               userInfo:nil
                                                                repeats:NO];
    }
}

- (void)lookupCurrentSymbol {
    if (self.currentSymbol.length == 0) return;
    
    NSLog(@"🔍 OrderEntry: Looking up symbol %@", self.currentSymbol);
    
    [[DataHub sharedDataHub] getQuoteForSymbol:self.currentSymbol completion:^(MarketQuoteModel *quote, BOOL isLive) {
        if (quote) {
            [self updateMarketDataForSymbol:self.currentSymbol quote:(TradingQuoteModel *)quote];
            
            // Subscribe to real-time updates
            [[DataHub sharedDataHub] subscribeToQuoteUpdatesForSymbol:self.currentSymbol];
        } else {
            NSLog(@"❌ OrderEntry: Failed to get quote for %@", self.currentSymbol);
        }
    }];
}

- (IBAction)lookupSymbol:(NSButton *)sender {
    [self lookupCurrentSymbol];
}

- (IBAction)orderTypeChanged:(NSPopUpButton *)sender {
    NSString *orderType = sender.selectedItem.title;
    [self updateUIForOrderType:orderType];
    [self recalculateAllValues];
}

- (IBAction)sideChanged:(NSPopUpButton *)sender {
    NSString *side = sender.selectedItem.title;
    [self updateUIForSide:side];
    [self recalculateAllValues];
}

- (IBAction)timeInForceChanged:(NSPopUpButton *)sender {
    [self recalculateAllValues];
}

#pragma mark - Quantity Calculation Actions

- (IBAction)quantityModeChanged:(NSSegmentedControl *)sender {
    self.currentQuantityMode = sender.selectedSegment;
    [self updateQuantityFieldPlaceholder];
    [self recalculateShares];
}

- (void)updateQuantityFieldPlaceholder {
    switch (self.currentQuantityMode) {
        case QuantityModeShares:
            self.quantityField.placeholderString = @"100";
            break;
        case QuantityModePortfolioPercent:
            self.quantityField.placeholderString = @"5.0";
            break;
        case QuantityModeCashPercent:
            self.quantityField.placeholderString = @"10.0";
            break;
        case QuantityModeDollarAmount:
            self.quantityField.placeholderString = @"5000";
            break;
        case QuantityModeRiskAmount:
            self.quantityField.placeholderString = @"500";
            break;
    }
}

- (IBAction)quantityFieldChanged:(NSTextField *)sender {
    [self recalculateShares];
}

#pragma mark - Price Actions

- (IBAction)limitPriceChanged:(NSTextField *)sender {
    [self recalculateAllValues];
}

- (IBAction)stopPriceChanged:(NSTextField *)sender {
    [self recalculateAllValues];
}

- (IBAction)setBidPrice:(NSButton *)sender {
    if (self.currentQuote && self.currentQuote.bid > 0) {
        self.limitPriceField.stringValue = [NSString stringWithFormat:@"%.2f", self.currentQuote.bid];
        [self recalculateAllValues];
    }
}

- (IBAction)setAskPrice:(NSButton *)sender {
    if (self.currentQuote && self.currentQuote.ask > 0) {
        self.limitPriceField.stringValue = [NSString stringWithFormat:@"%.2f", self.currentQuote.ask];
        [self recalculateAllValues];
    }
}

- (IBAction)setLastPrice:(NSButton *)sender {
    if (self.currentQuote && self.currentQuote.lastPrice > 0) {
        self.limitPriceField.stringValue = [NSString stringWithFormat:@"%.2f", self.currentQuote.lastPrice];
        [self recalculateAllValues];
    }
}

#pragma mark - Bracket Orders Actions

- (IBAction)bracketOrdersToggled:(NSButton *)sender {
    self.bracketOrdersEnabled = (sender.state == NSControlStateValueOn);
    [self updateBracketOrdersVisibility];
    [self recalculateAllValues];
}

- (IBAction)profitTargetModeChanged:(NSSegmentedControl *)sender {
    self.currentProfitTargetMode = sender.selectedSegment;
    [self updateProfitTargetFieldPlaceholder];
    [self recalculateBracketPrices];
}

- (IBAction)profitTargetFieldChanged:(NSTextField *)sender {
    [self recalculateBracketPrices];
}

- (IBAction)stopLossModeChanged:(NSSegmentedControl *)sender {
    self.currentStopLossMode = sender.selectedSegment;
    [self updateStopLossFieldPlaceholder];
    [self recalculateBracketPrices];
}

- (IBAction)stopLossFieldChanged:(NSTextField *)sender {
    [self recalculateBracketPrices];
}

- (void)updateProfitTargetFieldPlaceholder {
    switch (self.currentProfitTargetMode) {
        case ProfitTargetModePrice:
            self.profitTargetField.placeholderString = @"155.00";
            break;
        case ProfitTargetModePercent:
            self.profitTargetField.placeholderString = @"10.0";
            break;
        case ProfitTargetModeDollarAmount:
            self.profitTargetField.placeholderString = @"1000";
            break;
        case ProfitTargetModeRRRatio:
            self.profitTargetField.placeholderString = @"3.0";
            break;
    }
}

- (void)updateStopLossFieldPlaceholder {
    switch (self.currentStopLossMode) {
        case StopLossModePrice:
            self.stopLossField.placeholderString = @"145.00";
            break;
        case StopLossModePercent:
            self.stopLossField.placeholderString = @"3.0";
            break;
        case StopLossModeDollarAmount:
            self.stopLossField.placeholderString = @"500";
            break;
        case StopLossModeATR:
            self.stopLossField.placeholderString = @"2.0";
            break;
        case StopLossModeDayLow:
        case StopLossModeDayHigh:
            self.stopLossField.placeholderString = @"0.10";
            break;
    }
}

#pragma mark - Preset Actions

- (IBAction)applyScalpPreset:(NSButton *)sender {
    if (!self.currentQuote) {
        NSLog(@"⚠️ OrderEntry: Need market data to apply scalp preset");
        return;
    }
    
    // Apply scalping preset
    self.bracketOrdersEnabled = YES;
    [self.enableBracketOrdersCheckbox setState:NSControlStateValueOn];
    
    [self.orderTypePopup selectItemWithTitle:@"LIMIT"];
    [self.timeInForcePopup selectItemWithTitle:@"DAY"];
    
    // Set prices
    double entryPrice = self.currentQuote.ask; // Enter at ask for quick fill
    self.limitPriceField.stringValue = [NSString stringWithFormat:@"%.2f", entryPrice];
    
    // Scalping: tight stops and targets
    [self.stopLossModeControl setSelectedSegment:StopLossModePercent];
    [self.profitTargetModeControl setSelectedSegment:ProfitTargetModePercent];
    self.stopLossField.stringValue = @"0.5";     // 0.5% stop
    self.profitTargetField.stringValue = @"1.0"; // 1% target
    
    [self updateBracketOrdersVisibility];
    [self recalculateAllValues];
    
    NSLog(@"📈 OrderEntry: Applied scalp preset");
}

- (IBAction)applySwingPreset:(NSButton *)sender {
    if (!self.currentQuote) {
        NSLog(@"⚠️ OrderEntry: Need market data to apply swing preset");
        return;
    }
    
    // Apply swing trading preset
    self.bracketOrdersEnabled = YES;
    [self.enableBracketOrdersCheckbox setState:NSControlStateValueOn];
    
    [self.orderTypePopup selectItemWithTitle:@"LIMIT"];
    [self.timeInForcePopup selectItemWithTitle:@"GTC"];
    
    // Set entry price
    double entryPrice = self.currentQuote.lastPrice;
    self.limitPriceField.stringValue = [NSString stringWithFormat:@"%.2f", entryPrice];
    
    // Swing trading: wider stops and targets
    [self.stopLossModeControl setSelectedSegment:StopLossModePercent];
    [self.profitTargetModeControl setSelectedSegment:ProfitTargetModePercent];
    self.stopLossField.stringValue = @"3.0";      // 3% stop
    self.profitTargetField.stringValue = @"10.0"; // 10% target
    
    [self updateBracketOrdersVisibility];
    [self recalculateAllValues];
    
    NSLog(@"📊 OrderEntry: Applied swing preset");
}

- (IBAction)applyBreakoutPreset:(NSButton *)sender {
    if (!self.currentQuote) {
        NSLog(@"⚠️ OrderEntry: Need market data to apply breakout preset");
        return;
    }
    
    // Apply breakout preset based on day's range
    self.bracketOrdersEnabled = YES;
    [self.enableBracketOrdersCheckbox setState:NSControlStateValueOn];
    
    NSString *side = self.sidePopup.selectedItem.title;
    double dayHigh = self.currentQuote.high;
    double dayLow = self.currentQuote.low;
    
    if ([side hasPrefix:@"BUY"]) {
        // Bullish breakout above day high
        [self.orderTypePopup selectItemWithTitle:@"STOP"];
        double entryPrice = dayHigh + 0.05; // $0.05 above day high
        self.stopPriceField.stringValue = [NSString stringWithFormat:@"%.2f", entryPrice];
        
        // Stop at day low
        [self.stopLossModeControl setSelectedSegment:StopLossModeDayLow];
        self.stopLossField.stringValue = @"0.10"; // $0.10 below day low
    } else {
        // Bearish breakdown below day low
        [self.orderTypePopup selectItemWithTitle:@"STOP"];
        double entryPrice = dayLow - 0.05; // $0.05 below day low
        double entryPrice = dayLow - 0.05; // $0.05 below day low
        self.stopPriceField.stringValue = [NSString stringWithFormat:@"%.2f", entryPrice];
        
        // Stop at day high
        [self.stopLossModeControl setSelectedSegment:StopLossModeDayHigh];
        self.stopLossField.stringValue = @"0.10"; // $0.10 above day high
    }
    
    // Target based on day's range
    [self.profitTargetModeControl setSelectedSegment:ProfitTargetModeRRRatio];
    self.profitTargetField.stringValue = @"2.0"; // 1:2 risk/reward
    
    [self.timeInForcePopup selectItemWithTitle:@"DAY"];
    
    [self updateBracketOrdersVisibility];
    [self recalculateAllValues];
    
    NSLog(@"🚀 OrderEntry: Applied breakout preset");
}

- (IBAction)applyCustomPreset1:(NSButton *)sender {
    // TODO: Implement user customizable preset 1
    NSLog(@"🎯 OrderEntry: Custom preset 1 - not implemented yet");
}

- (IBAction)applyCustomPreset2:(NSButton *)sender {
    // TODO: Implement user customizable preset 2
    NSLog(@"🎯 OrderEntry: Custom preset 2 - not implemented yet");
}

#pragma mark - Order Management Actions

- (IBAction)validateOrder:(NSButton *)sender {
    NSError *error = nil;
    BOOL isValid = [self validateCurrentOrder:&error];
    
    if (isValid) {
        NSAlert *alert = [[NSAlert alloc] init];
        alert.messageText = @"Order Validation Successful";
        alert.informativeText = @"The order passes all validation checks and is ready for submission.";
        alert.alertStyle = NSAlertStyleInformational;
        [alert addButtonWithTitle:@"OK"];
        
        [alert beginSheetModalForWindow:self.view.window completionHandler:nil];
        
        NSLog(@"✅ OrderEntry: Order validation passed");
    } else {
        NSAlert *alert = [[NSAlert alloc] init];
        alert.messageText = @"Order Validation Failed";
        alert.informativeText = error.localizedDescription;
        alert.alertStyle = NSAlertStyleWarning;
        [alert addButtonWithTitle:@"OK"];
        
        [alert beginSheetModalForWindow:self.view.window completionHandler:nil];
        
        NSLog(@"❌ OrderEntry: Order validation failed: %@", error.localizedDescription);
    }
}

- (IBAction)submitOrder:(NSButton *)sender {
    // Validate order first
    NSError *error = nil;
    if (![self validateCurrentOrder:&error]) {
        NSAlert *alert = [[NSAlert alloc] init];
        alert.messageText = @"Cannot Submit Order";
        alert.informativeText = error.localizedDescription;
        alert.alertStyle = NSAlertStyleCritical;
        [alert addButtonWithTitle:@"OK"];
        
        [alert beginSheetModalForWindow:self.view.window completionHandler:nil];
        return;
    }
    
    // Build order(s)
    id orderData;
    if (self.bracketOrdersEnabled) {
        orderData = [self buildBracketOrder];
    } else {
        orderData = [self buildSimpleOrder];
    }
    
    if (!orderData) {
        NSLog(@"❌ OrderEntry: Failed to build order data");
        return;
    }
    
    // Show confirmation dialog
    NSString *preview = [AdvancedOrderBuilder generateOrderPreview:orderData
                                                    portfolioValue:self.currentPortfolio.totalValue];
    
    NSAlert *confirmAlert = [[NSAlert alloc] init];
    confirmAlert.messageText = @"Confirm Order Submission";
    confirmAlert.informativeText = [NSString stringWithFormat:@"Please review your order:\n\n%@\n\nAre you sure you want to submit this order?", preview];
    confirmAlert.alertStyle = NSAlertStyleWarning;
    [confirmAlert addButtonWithTitle:@"Submit Order"];
    [confirmAlert addButtonWithTitle:@"Cancel"];
    
    [confirmAlert beginSheetModalForWindow:self.view.window completionHandler:^(NSModalResponse response) {
        if (response == NSAlertFirstButtonReturn) {
            [self executeOrderSubmission:orderData];
        }
    }];
}

- (void)executeOrderSubmission:(id)orderData {
    if (!self.selectedAccount) {
        NSLog(@"❌ OrderEntry: No account selected");
        return;
    }
    
    // Disable submit button during submission
    self.submitOrderButton.enabled = NO;
    self.submitOrderButton.title = @"Submitting...";
    
    NSString *accountId = self.selectedAccount.accountId;
    
    if ([orderData isKindOfClass:[NSArray class]]) {
        // Multiple orders (bracket, etc.)
        NSArray *orders = (NSArray *)orderData;
        [self submitMultipleOrders:orders toAccount:accountId];
    } else {
        // Single order
        NSDictionary *order = (NSDictionary *)orderData;
        [self submitSingleOrder:order toAccount:accountId];
    }
}

- (void)submitSingleOrder:(NSDictionary *)order toAccount:(NSString *)accountId {
    [[DataHub sharedDataHub] placeOrder:order forAccount:accountId completion:^(NSString *orderId, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            // Re-enable submit button
            self.submitOrderButton.enabled = YES;
            self.submitOrderButton.title = @"Submit Order";
            
            if (orderId) {
                NSLog(@"✅ OrderEntry: Order submitted successfully - ID: %@", orderId);
                
                NSAlert *successAlert = [[NSAlert alloc] init];
                successAlert.messageText = @"Order Submitted Successfully";
                successAlert.informativeText = [NSString stringWithFormat:@"Your order has been submitted.\n\nOrder ID: %@", orderId];
                successAlert.alertStyle = NSAlertStyleInformational;
                [successAlert addButtonWithTitle:@"OK"];
                [successAlert addButtonWithTitle:@"Reset Form"];
                
                [successAlert beginSheetModalForWindow:self.view.window completionHandler:^(NSModalResponse response) {
                    if (response == NSAlertSecondButtonReturn) {
                        [self resetForm:nil];
                    }
                }];
                
            } else {
                NSLog(@"❌ OrderEntry: Order submission failed: %@", error.localizedDescription);
                
                NSAlert *errorAlert = [[NSAlert alloc] init];
                errorAlert.messageText = @"Order Submission Failed";
                errorAlert.informativeText = error.localizedDescription;
                errorAlert.alertStyle = NSAlertStyleCritical;
                [errorAlert addButtonWithTitle:@"OK"];
                
                [errorAlert beginSheetModalForWindow:self.view.window completionHandler:nil];
            }
        });
    }];
}

- (void)submitMultipleOrders:(NSArray *)orders toAccount:(NSString *)accountId {
    // For bracket orders, submit parent order first, then children will be triggered automatically
    // This is a simplified implementation - real bracket orders are more complex
    
    NSDictionary *parentOrder = orders[0];
    [self submitSingleOrder:parentOrder toAccount:accountId];
}

- (IBAction)resetForm:(NSButton *)sender {
    NSAlert *confirmAlert = [[NSAlert alloc] init];
    confirmAlert.messageText = @"Reset Order Form";
    confirmAlert.informativeText = @"This will clear all order details. Are you sure?";
    confirmAlert.alertStyle = NSAlertStyleWarning;
    [confirmAlert addButtonWithTitle:@"Reset"];
    [confirmAlert addButtonWithTitle:@"Cancel"];
    
    [confirmAlert beginSheetModalForWindow:self.view.window completionHandler:^(NSModalResponse response) {
        if (response == NSAlertFirstButtonReturn) {
            [self performFormReset];
        }
    }];
}

- (void)performFormReset {
    // Reset all form fields to defaults
    self.symbolField.stringValue = @"";
    self.quantityField.stringValue = @"100";
    self.limitPriceField.stringValue = @"";
    self.stopPriceField.stringValue = @"";
    self.profitTargetField.stringValue = @"10.0";
    self.stopLossField.stringValue = @"3.0";
    
    // Reset controls
    [self.orderTypePopup selectItemWithTitle:@"MARKET"];
    [self.sidePopup selectItemWithTitle:@"BUY"];
    [self.timeInForcePopup selectItemWithTitle:@"DAY"];
    [self.quantityModeControl setSelectedSegment:QuantityModeShares];
    [self.profitTargetModeControl setSelectedSegment:ProfitTargetModePercent];
    [self.stopLossModeControl setSelectedSegment:StopLossModePercent];
    
    // Reset bracket orders
    self.bracketOrdersEnabled = NO;
    [self.enableBracketOrdersCheckbox setState:NSControlStateValueOff];
    
    // Reset calculated values
    self.calculatedShares = 0;
    self.calculatedPositionValue = 0;
    self.calculatedRiskAmount = 0;
    self.calculatedRewardAmount = 0;
    self.calculatedRiskRewardRatio = 0;
    
    // Clear market data
    [self clearMarketData];
    self.currentSymbol = nil;
    
    // Update UI
    [self updateUIForOrderType:@"MARKET"];
    [self updateBracketOrdersVisibility];
    [self updateCalculatedValuesDisplay];
    [self updateRiskManagementDisplay];
    [self updateOrderPreview];
    
    NSLog(@"🔄 OrderEntry: Form reset complete");
}

#pragma mark - Calculations

- (void)recalculateAllValues {
    [self recalculateShares];
    [self recalculatePositionValue];
    [self recalculateBracketPrices];
    [self recalculateRiskReward];
    [self updateCalculatedValuesDisplay];
    [self updateRiskManagementDisplay];
    [self updateOrderPreview];
}

- (void)recalculateShares {
    if (!self.currentQuote) {
        self.calculatedShares = 0;
        return;
    }
    
    double quantityValue = self.quantityField.doubleValue;
    if (quantityValue <= 0) {
        self.calculatedShares = 0;
        return;
    }
    
    OrderQuantityCalculator *calculator = [OrderQuantityCalculator sharedCalculator];
    double sharePrice = [self getEffectiveSharePrice];
    
    switch (self.currentQuantityMode) {
        case QuantityModeShares:
            self.calculatedShares = quantityValue;
            break;
            
        case QuantityModePortfolioPercent:
            if (self.currentPortfolio) {
                self.calculatedShares = [calculator calculateSharesForPercentOfPortfolio:quantityValue
                                                                         portfolioValue:self.currentPortfolio.totalValue
                                                                             sharePrice:sharePrice];
            }
            break;
            
        case QuantityModeCashPercent:
            if (self.currentPortfolio) {
                self.calculatedShares = [calculator calculateSharesForPercentOfCash:quantityValue
                                                                               cash:self.currentPortfolio.cashBalance
                                                                         sharePrice:sharePrice];
            }
            break;
            
        case QuantityModeDollarAmount:
            self.calculatedShares = [calculator calculateSharesForDollarAmount:quantityValue
                                                                    sharePrice:sharePrice];
            break;
            
        case QuantityModeRiskAmount: {
            double stopPrice = [self getEffectiveStopPrice];
            if (stopPrice > 0) {
                self.calculatedShares = [calculator calculateSharesForRiskAmount:quantityValue
                                                                      entryPrice:sharePrice
                                                                       stopPrice:stopPrice];
            }
            break;
        }
    }
}

- (void)recalculatePositionValue {
    double sharePrice = [self getEffectiveSharePrice];
    self.calculatedPositionValue = self.calculatedShares * sharePrice;
}

- (void)recalculateBracketPrices {
    if (!self.bracketOrdersEnabled || !self.currentQuote) return;
    
    OrderQuantityCalculator *calculator = [OrderQuantityCalculator sharedCalculator];
    NSString *side = self.sidePopup.selectedItem.title;
    double entryPrice = [self getEffectiveSharePrice];
    
    // Calculate profit target price
    double profitTargetValue = self.profitTargetField.doubleValue;
    double calculatedProfitPrice = 0;
    
    switch (self.currentProfitTargetMode) {
        case ProfitTargetModePrice:
            calculatedProfitPrice = profitTargetValue;
            break;
            
        case ProfitTargetModePercent:
            calculatedProfitPrice = [calculator calculateTargetPriceFromPercent:profitTargetValue
                                                                     entryPrice:entryPrice
                                                                           side:side];
            break;
            
        case ProfitTargetModeDollarAmount:
            if (self.calculatedShares > 0) {
                double profitPerShare = profitTargetValue / self.calculatedShares;
                if ([side hasPrefix:@"BUY"]) {
                return self.currentQuote.ask; // Use ask for buy market orders
            } else {
                return self.currentQuote.bid; // Use bid for sell market orders
            }
        }
    } else if ([orderType isEqualToString:@"LIMIT"] || [orderType isEqualToString:@"STOP_LIMIT"]) {
        // For limit orders, use limit price
        double limitPrice = self.limitPriceField.doubleValue;
        if (limitPrice > 0) {
            return limitPrice;
        }
    } else if ([orderType isEqualToString:@"STOP"]) {
        // For stop orders, use stop price as entry
        double stopPrice = self.stopPriceField.doubleValue;
        if (stopPrice > 0) {
            return stopPrice;
        }
    }
    
    // Fallback to last price
    return self.currentQuote ? self.currentQuote.lastPrice : 0;
}

- (double)getEffectiveStopPrice {
    if (self.bracketOrdersEnabled) {
        return [self getCalculatedStopPrice];
    } else if ([self.orderTypePopup.selectedItem.title containsString:@"STOP"]) {
        return self.stopPriceField.doubleValue;
    }
    
    return 0;
}

- (BOOL)isSymbolValid:(NSString *)symbol {
    if (!symbol || symbol.length == 0) return NO;
    
    // Basic symbol validation (letters and numbers only)
    NSCharacterSet *validChars = [NSCharacterSet alphanumericCharacterSet];
    NSCharacterSet *symbolChars = [NSCharacterSet characterSetWithCharactersInString:symbol];
    
    return [validChars isSupersetOfSet:symbolChars];
}

- (BOOL)isQuantityValid:(double)quantity {
    return quantity > 0 && quantity <= 999999; // Reasonable limits
}

- (BOOL)arePricesValid:(NSError **)error {
    NSString *orderType = self.orderTypePopup.selectedItem.title;
    
    if ([orderType isEqualToString:@"LIMIT"] || [orderType isEqualToString:@"STOP_LIMIT"]) {
        if (self.limitPriceField.doubleValue <= 0) {
            if (error) {
                *error = [NSError errorWithDomain:@"OrderValidation"
                                             code:5001
                                         userInfo:@{NSLocalizedDescriptionKey: @"Limit price must be positive"}];
            }
            return NO;
        }
    }
    
    if ([orderType isEqualToString:@"STOP"] || [orderType isEqualToString:@"STOP_LIMIT"]) {
        if (self.stopPriceField.doubleValue <= 0) {
            if (error) {
                *error = [NSError errorWithDomain:@"OrderValidation"
                                             code:5002
                                         userInfo:@{NSLocalizedDescriptionKey: @"Stop price must be positive"}];
            }
            return NO;
        }
    }
    
    return YES;
}

- (NSString *)formatVolume:(NSInteger)volume {
    if (volume >= 1000000) {
        return [NSString stringWithFormat:@"%.1fM", volume / 1000000.0];
    } else if (volume >= 1000) {
        return [NSString stringWithFormat:@"%.1fK", volume / 1000.0];
    } else {
        return [NSString stringWithFormat:@"%ld", (long)volume];
    }
}

#pragma mark - Public Interface Methods

- (void)setSelectedAccount:(AccountModel *)selectedAccount {
    _selectedAccount = selectedAccount;
    
    // Load portfolio data for calculations
    if (selectedAccount) {
        [[DataHub sharedDataHub] getPortfolioSummaryForAccount:selectedAccount.accountId completion:^(PortfolioSummaryModel *summary, BOOL isFresh) {
            self.currentPortfolio = summary;
            [self recalculateAllValues];
        }];
    }
}

@end:@"BUY"]) {
                    calculatedProfitPrice = entryPrice + profitPerShare;
                } else {
                    calculatedProfitPrice = entryPrice - profitPerShare;
                }
            }
            break;
            
        case ProfitTargetModeRRRatio: {
            double stopPrice = [self getCalculatedStopPrice];
            if (stopPrice > 0) {
                calculatedProfitPrice = [calculator calculateTargetPriceFromRRR:profitTargetValue
                                                                     entryPrice:entryPrice
                                                                      stopPrice:stopPrice
                                                                           side:side];
            }
            break;
        }
    }
    
    self.calculatedProfitPriceLabel.stringValue = [NSString stringWithFormat:@"Target: %.2f", calculatedProfitPrice];
    
    // Calculate stop loss price
    double stopLossValue = self.stopLossField.doubleValue;
    double calculatedStopPrice = [self getCalculatedStopPrice];
    
    self.calculatedStopPriceLabel.stringValue = [NSString stringWithFormat:@"Stop: %.2f", calculatedStopPrice];
}

- (double)getCalculatedStopPrice {
    if (!self.currentQuote) return 0;
    
    OrderQuantityCalculator *calculator = [OrderQuantityCalculator sharedCalculator];
    NSString *side = self.sidePopup.selectedItem.title;
    double entryPrice = [self getEffectiveSharePrice];
    double stopLossValue = self.stopLossField.doubleValue;
    
    switch (self.currentStopLossMode) {
        case StopLossModePrice:
            return stopLossValue;
            
        case StopLossModePercent:
            return [calculator calculateStopPriceFromPercent:stopLossValue
                                                  entryPrice:entryPrice
                                                        side:side];
            
        case StopLossModeDollarAmount:
            if (self.calculatedShares > 0) {
                double lossPerShare = stopLossValue / self.calculatedShares;
                if ([side hasPrefix:@"BUY"]) {
                    return entryPrice - lossPerShare;
                } else {
                    return entryPrice + lossPerShare;
                }
            }
            break;
            
        case StopLossModeATR:
            if (self.currentQuote.atr14 > 0) {
                return [calculator calculateATRBasedStop:self.currentQuote.atr14
                                              multiplier:stopLossValue
                                              entryPrice:entryPrice
                                                    side:side];
            }
            break;
            
        case StopLossModeDayLow:
            return [calculator calculateRangeBasedStop:self.currentQuote.low
                                               dayHigh:self.currentQuote.high
                                                offset:stopLossValue
                                               useHigh:NO];
            
        case StopLossModeDayHigh:
            return [calculator calculateRangeBasedStop:self.currentQuote.low
                                               dayHigh:self.currentQuote.high
                                                offset:stopLossValue
                                               useHigh:YES];
    }
    
    return 0;
}

- (void)recalculateRiskReward {
    if (!self.bracketOrdersEnabled || self.calculatedShares <= 0) {
        self.calculatedRiskAmount = 0;
        self.calculatedRewardAmount = 0;
        self.calculatedRiskRewardRatio = 0;
        return;
    }
    
    OrderQuantityCalculator *calculator = [OrderQuantityCalculator sharedCalculator];
    double entryPrice = [self getEffectiveSharePrice];
    double stopPrice = [self getCalculatedStopPrice];
    double targetPrice = [self getCalculatedTargetPrice];
    
    if (stopPrice > 0) {
        self.calculatedRiskAmount = [calculator calculateRiskAmount:self.calculatedShares
                                                         entryPrice:entryPrice
                                                          stopPrice:stopPrice];
    }
    
    if (targetPrice > 0) {
        self.calculatedRewardAmount = [calculator calculateRewardAmount:self.calculatedShares
                                                             entryPrice:entryPrice
                                                            targetPrice:targetPrice];
    }
    
    if (self.calculatedRiskAmount > 0) {
        self.calculatedRiskRewardRatio = [calculator calculateRiskRewardRatio:self.calculatedRiskAmount
                                                                 rewardAmount:self.calculatedRewardAmount];
    }
}

- (double)getCalculatedTargetPrice {
    // This would implement the target price calculation similar to stop price
    // Simplified for brevity
    return 0;
}

- (void)updateCalculatedValuesDisplay {
    OrderQuantityCalculator *calculator = [OrderQuantityCalculator sharedCalculator];
    
    // Update shares display
    if (self.currentQuantityMode == QuantityModeShares) {
        self.calculatedSharesLabel.stringValue = @"";
    } else {
        self.calculatedSharesLabel.stringValue = [NSString stringWithFormat:@"= %@ shares",
                                                 [calculator formatShares:self.calculatedShares]];
    }
    
    // Update position value
    self.positionValueLabel.stringValue = [calculator formatCurrency:self.calculatedPositionValue];
    
    // Update portfolio percentage
    if (self.currentPortfolio && self.currentPortfolio.totalValue > 0) {
        double portfolioPercent = (self.calculatedPositionValue / self.currentPortfolio.totalValue) * 100.0;
        self.portfolioPercentLabel.stringValue = [NSString stringWithFormat:@"(%.1f%% of portfolio)", portfolioPercent];
    } else {
        self.portfolioPercentLabel.stringValue = @"";
    }
}

- (void)updateRiskManagementDisplay {
    OrderQuantityCalculator *calculator = [OrderQuantityCalculator sharedCalculator];
    
    if (self.calculatedRiskAmount > 0) {
        self.riskAmountLabel.stringValue = [NSString stringWithFormat:@"Risk: %@",
                                           [calculator formatCurrency:self.calculatedRiskAmount]];
        
        // Color code risk based on amount
        if (self.calculatedRiskAmount > 1000) {
            self.riskAmountLabel.textColor = [NSColor systemRedColor];
        } else if (self.calculatedRiskAmount > 500) {
            self.riskAmountLabel.textColor = [NSColor systemOrangeColor];
        } else {
            self.riskAmountLabel.textColor = [NSColor systemGreenColor];
        }
    } else {
        self.riskAmountLabel.stringValue = @"Risk: --";
        self.riskAmountLabel.textColor = [NSColor labelColor];
    }
    
    if (self.calculatedRewardAmount > 0) {
        self.rewardAmountLabel.stringValue = [NSString stringWithFormat:@"Reward: %@",
                                             [calculator formatCurrency:self.calculatedRewardAmount]];
    } else {
        self.rewardAmountLabel.stringValue = @"Reward: --";
    }
    
    if (self.calculatedRiskRewardRatio > 0) {
        self.riskRewardRatioLabel.stringValue = [NSString stringWithFormat:@"R:R: %@",
                                                [calculator formatRiskRewardRatio:self.calculatedRiskRewardRatio]];
        
        // Color code R:R ratio
        if (self.calculatedRiskRewardRatio >= 2.0) {
            self.riskRewardRatioLabel.textColor = [NSColor systemGreenColor];
        } else if (self.calculatedRiskRewardRatio >= 1.5) {
            self.riskRewardRatioLabel.textColor = [NSColor systemYellowColor];
        } else {
            self.riskRewardRatioLabel.textColor = [NSColor systemRedColor];
        }
    } else {
        self.riskRewardRatioLabel.stringValue = @"R:R: --";
        self.riskRewardRatioLabel.textColor = [NSColor labelColor];
    }
    
    // Portfolio risk percentage
    if (self.currentPortfolio && self.calculatedRiskAmount > 0) {
        double portfolioRiskPercent = (self.calculatedRiskAmount / self.currentPortfolio.totalValue) * 100.0;
        self.portfolioRiskLabel.stringValue = [NSString stringWithFormat:@"Portfolio Risk: %.2f%%", portfolioRiskPercent];
        
        // Color code portfolio risk
        if (portfolioRiskPercent > 3.0) {
            self.portfolioRiskLabel.textColor = [NSColor systemRedColor];
        } else if (portfolioRiskPercent > 2.0) {
            self.portfolioRiskLabel.textColor = [NSColor systemOrangeColor];
        } else {
            self.portfolioRiskLabel.textColor = [NSColor systemGreenColor];
        }
    } else {
        self.portfolioRiskLabel.stringValue = @"Portfolio Risk: --%";
        self.portfolioRiskLabel.textColor = [NSColor labelColor];
    }
    
    // Maximum loss (for market orders, this equals risk amount)
    self.maxLossLabel.stringValue = [NSString stringWithFormat:@"Max Loss: %@",
                                    [calculator formatCurrency:self.calculatedRiskAmount]];
}

- (void)updateOrderPreview {
    id orderData;
    if (self.bracketOrdersEnabled) {
        orderData = [self buildBracketOrder];
    } else {
        orderData = [self buildSimpleOrder];
    }
    
    if (orderData) {
        NSString *preview = [AdvancedOrderBuilder generateOrderPreview:orderData
                                                        portfolioValue:self.currentPortfolio.totalValue];
        self.orderPreviewTextView.string = preview;
    } else {
        self.orderPreviewTextView.string = @"Enter order details to see preview...";
    }
}

#pragma mark - UI State Management

- (void)updateUIForOrderType:(NSString *)orderType {
    BOOL showLimitPrice = [orderType isEqualToString:@"LIMIT"] || [orderType isEqualToString:@"STOP_LIMIT"];
    BOOL showStopPrice = [orderType isEqualToString:@"STOP"] || [orderType isEqualToString:@"STOP_LIMIT"];
    
    self.limitPriceField.hidden = !showLimitPrice;
    self.stopPriceField.hidden = !showStopPrice;
    
    // Enable/disable quick price buttons
    BOOL enableQuickPriceButtons = showLimitPrice && self.currentQuote;
    self.setBidPriceButton.enabled = enableQuickPriceButtons;
    self.setAskPriceButton.enabled = enableQuickPriceButtons;
    self.setLastPriceButton.enabled = enableQuickPriceButtons;
}

- (void)updateUIForSide:(NSString *)side {
    // Update UI elements based on order side
    // For example, change button colors, labels, etc.
    
    if ([side hasPrefix:@"BUY"]) {
        self.submitOrderButton.contentTintColor = [NSColor systemGreenColor];
    } else {
        self.submitOrderButton.contentTintColor = [NSColor systemRedColor];
    }
}

- (void)updateBracketOrdersVisibility {
    self.bracketOrdersPanel.hidden = !self.bracketOrdersEnabled;
    self.riskManagementPanel.hidden = !self.bracketOrdersEnabled;
}

#pragma mark - Order Building

- (NSDictionary *)buildSimpleOrder {
    if (!self.currentSymbol || self.calculatedShares <= 0) return nil;
    
    NSString *orderType = self.orderTypePopup.selectedItem.title;
    NSString *side = self.sidePopup.selectedItem.title;
    NSString *timeInForce = self.timeInForcePopup.selectedItem.title;
    
    double price = 0;
    double stopPrice = 0;
    
    if ([orderType isEqualToString:@"LIMIT"] || [orderType isEqualToString:@"STOP_LIMIT"]) {
        price = self.limitPriceField.doubleValue;
    }
    
    if ([orderType isEqualToString:@"STOP"] || [orderType isEqualToString:@"STOP_LIMIT"]) {
        stopPrice = self.stopPriceField.doubleValue;
    }
    
    return [AdvancedOrderBuilder buildSimpleOrder:self.currentSymbol
                                             side:side
                                         quantity:self.calculatedShares
                                        orderType:orderType
                                            price:price
                                        stopPrice:stopPrice
                                      timeInForce:timeInForce];
}

- (NSArray *)buildBracketOrder {
    if (!self.bracketOrdersEnabled || !self.currentSymbol || self.calculatedShares <= 0) return nil;
    
    NSString *entryType = self.orderTypePopup.selectedItem.title;
    NSString *side = self.sidePopup.selectedItem.title;
    NSString *timeInForce = self.timeInForcePopup.selectedItem.title;
    
    double entryPrice = [self getEffectiveSharePrice];
    double stopPrice = [self getCalculatedStopPrice];
    double targetPrice = [self getCalculatedTargetPrice];
    
    return [AdvancedOrderBuilder buildBracketOrder:self.currentSymbol
                                              side:side
                                          quantity:self.calculatedShares
                                         entryType:entryType
                                        entryPrice:entryPrice
                                     stopLossPrice:stopPrice
                                 profitTargetPrice:targetPrice
                                       timeInForce:timeInForce];
}

#pragma mark - Validation

- (BOOL)validateCurrentOrder:(NSError **)error {
    // Symbol validation
    if (!self.currentSymbol || self.currentSymbol.length == 0) {
        if (error) {
            *error = [NSError errorWithDomain:@"OrderValidation"
                                         code:4001
                                     userInfo:@{NSLocalizedDescriptionKey: @"Symbol is required"}];
        }
        return NO;
    }
    
    // Quantity validation
    if (self.calculatedShares <= 0) {
        if (error) {
            *error = [NSError errorWithDomain:@"OrderValidation"
                                         code:4002
                                     userInfo:@{NSLocalizedDescriptionKey: @"Quantity must be greater than zero"}];
        }
        return NO;
    }
    
    // Account validation
    if (!self.selectedAccount) {
        if (error) {
            *error = [NSError errorWithDomain:@"OrderValidation"
                                         code:4003
                                     userInfo:@{NSLocalizedDescriptionKey: @"No account selected"}];
        }
        return NO;
    }
    
    // Price validation for limit orders
    NSString *orderType = self.orderTypePopup.selectedItem.title;
    if ([orderType isEqualToString:@"LIMIT"] || [orderType isEqualToString:@"STOP_LIMIT"]) {
        if (self.limitPriceField.doubleValue <= 0) {
            if (error) {
                *error = [NSError errorWithDomain:@"OrderValidation"
                                             code:4004
                                         userInfo:@{NSLocalizedDescriptionKey: @"Limit price must be greater than zero"}];
            }
            return NO;
        }
    }
    
    // Stop price validation
    if ([orderType isEqualToString:@"STOP"] || [orderType isEqualToString:@"STOP_LIMIT"]) {
        if (self.stopPriceField.doubleValue <= 0) {
            if (error) {
                *error = [NSError errorWithDomain:@"OrderValidation"
                                             code:4005
                                         userInfo:@{NSLocalizedDescriptionKey: @"Stop price must be greater than zero"}];
            }
            return NO;
        }
    }
    
    // Bracket order validation
    if (self.bracketOrdersEnabled) {
        double entryPrice = [self getEffectiveSharePrice];
        double stopPrice = [self getCalculatedStopPrice];
        double targetPrice = [self getCalculatedTargetPrice];
        NSString *side = self.sidePopup.selectedItem.title;
        
        if (![AdvancedOrderBuilder validateBracketOrder:entryPrice
                                              stopPrice:stopPrice
                                            targetPrice:targetPrice
                                                   side:side
                                                  error:error]) {
            return NO;
        }
    }
    
    return YES;
}

#pragma mark - Helper Methods

- (double)getEffectiveSharePrice {
    NSString *orderType = self.orderTypePopup.selectedItem.title;
    
    if ([orderType isEqualToString:@"MARKET"]) {
        // For market orders, use current price or bid/ask
        if (self.currentQuote) {
            NSString *side = self.sidePopup.selectedItem.title;
            if ([side hasPrefix//
//  OrderEntryViewController.m
//  TradingApp
//
//  Implementation of advanced order entry system
//

#import "OrderEntryViewController.h"
#import "DataHub+Portfolio.h"
#import "DataHub+MarketData.h"
#import "OrderQuantityCalculator.h"
#import "AdvancedOrderBuilder.h"

@interface OrderEntryViewController ()

/// Timer for market data refresh
@property (nonatomic, strong) NSTimer *marketDataRefreshTimer;

/// Last quote refresh timestamp
@property (nonatomic, strong) NSDate *lastQuoteRefresh;

/// Form validation timer (debounced)
@property (nonatomic, strong) NSTimer *validationTimer;

/// Current symbol being tracked
@property (nonatomic, strong) NSString *currentSymbol;

@end

@implementation OrderEntryViewController

#pragma mark - View Lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Initialize form state
    self.currentQuantityMode = QuantityModeShares;
    self.currentProfitTargetMode = ProfitTargetModePercent;
    self.currentStopLossMode = StopLossModePercent;
    self.bracketOrdersEnabled = NO;
    
    [self setupUI];
    [self setupNotificationObservers];
    [self setupDefaultValues];
    [self startMarketDataRefresh];
    
    NSLog(@"📝 OrderEntryViewController loaded");
}

- (void)viewWillDisappear {
    [super viewWillDisappear];
    [self stopMarketDataRefresh];
}

- (void)dealloc {
    [self stopMarketDataRefresh];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    NSLog(@"📝 OrderEntryViewController deallocated");
}

#pragma mark - UI Setup

- (void)setupUI {
    [self setupSymbolSection];
    [self setupMarketDataPanel];
    [self setupOrderTypeSection];
    [self setupQuantitySection];
    [self setupPriceSection];
    [self setupBracketOrdersSection];
    [self setupRiskManagementPanel];
    [self setupPresetsPanel];
    [self setupOrderPreviewSection];
    [self setupLayoutConstraints];
    
    // Initial UI state
    [self updateUIForOrderType:@"MARKET"];
    [self updateBracketOrdersVisibility];
}

- (void)setupSymbolSection {
    // Symbol field setup
    self.symbolField.placeholderString = @"Enter symbol (e.g. AAPL)";
    [self.symbolField setTarget:self];
    [self.symbolField setAction:@selector(symbolFieldChanged:)];
    
    // Lookup button
    [self.symbolLookupButton setTarget:self];
    [self.symbolLookupButton setAction:@selector(lookupSymbol:)];
    [self.symbolLookupButton setTitle:@"📊"];
}

- (void)setupMarketDataPanel {
    // Initialize market data labels
    [self clearMarketData];
    
    // Style market data panel
    self.marketDataPanel.wantsLayer = YES;
    self.marketDataPanel.layer.backgroundColor = [NSColor controlBackgroundColor].CGColor;
    self.marketDataPanel.layer.cornerRadius = 6.0;
    self.marketDataPanel.layer.borderWidth = 1.0;
    self.marketDataPanel.layer.borderColor = [NSColor separatorColor].CGColor;
}

- (void)setupOrderTypeSection {
    // Order type popup
    [self.orderTypePopup removeAllItems];
    [self.orderTypePopup addItemsWithTitles:@[@"MARKET", @"LIMIT", @"STOP", @"STOP_LIMIT"]];
    [self.orderTypePopup selectItemWithTitle:@"MARKET"];
    [self.orderTypePopup setTarget:self];
    [self.orderTypePopup setAction:@selector(orderTypeChanged:)];
    
    // Side popup
    [self.sidePopup removeAllItems];
    [self.sidePopup addItemsWithTitles:@[@"BUY", @"SELL", @"SELL_SHORT"]];
    [self.sidePopup selectItemWithTitle:@"BUY"];
    [self.sidePopup setTarget:self];
    [self.sidePopup setAction:@selector(sideChanged:)];
    
    // Time in force popup
    [self.timeInForcePopup removeAllItems];
    [self.timeInForcePopup addItemsWithTitles:@[@"DAY", @"GTC", @"IOC", @"FOK"]];
    [self.timeInForcePopup selectItemWithTitle:@"DAY"];
    [self.timeInForcePopup setTarget:self];
    [self.timeInForcePopup setAction:@selector(timeInForceChanged:)];
}

- (void)setupQuantitySection {
    // Quantity mode control
    [self.quantityModeControl setSegmentCount:5];
    [self.quantityModeControl setLabel:@"Shares" forSegment:QuantityModeShares];
    [self.quantityModeControl setLabel:@"% Portfolio" forSegment:QuantityModePortfolioPercent];
    [self.quantityModeControl setLabel:@"% Cash" forSegment:QuantityModeCashPercent];
    [self.quantityModeControl setLabel:@"$ Amount" forSegment:QuantityModeDollarAmount];
    [self.quantityModeControl setLabel:@"Risk $" forSegment:QuantityModeRiskAmount];
    [self.quantityModeControl setSelectedSegment:QuantityModeShares];
    [self.quantityModeControl setTarget:self];
    [self.quantityModeControl setAction:@selector(quantityModeChanged:)];
    
    // Quantity field
    self.quantityField.placeholderString = @"100";
    [self.quantityField setTarget:self];
    [self.quantityField setAction:@selector(quantityFieldChanged:)];
    
    // Initialize calculated labels
    self.calculatedSharesLabel.stringValue = @"";
    self.positionValueLabel.stringValue = @"";
    self.portfolioPercentLabel.stringValue = @"";
}

- (void)setupPriceSection {
    // Price fields
    self.limitPriceField.placeholderString = @"0.00";
    [self.limitPriceField setTarget:self];
    [self.limitPriceField setAction:@selector(limitPriceChanged:)];
    
    self.stopPriceField.placeholderString = @"0.00";
    [self.stopPriceField setTarget:self];
    [self.stopPriceField setAction:@selector(stopPriceChanged:)];
    
    // Quick price buttons
    [self.setBidPriceButton setTarget:self];
    [self.setBidPriceButton setAction:@selector(setBidPrice:)];
    [self.setBidPriceButton setTitle:@"Bid"];
    
    [self.setAskPriceButton setTarget:self];
    [self.setAskPriceButton setAction:@selector(setAskPrice:)];
    [self.setAskPriceButton setTitle:@"Ask"];
    
    [self.setLastPriceButton setTarget:self];
    [self.setLastPriceButton setAction:@selector(setLastPrice:)];
    [self.setLastPriceButton setTitle:@"Last"];
}

- (void)setupBracketOrdersSection {
    // Enable bracket orders checkbox
    [self.enableBracketOrdersCheckbox setTarget:self];
    [self.enableBracketOrdersCheckbox setAction:@selector(bracketOrdersToggled:)];
    [self.enableBracketOrdersCheckbox setState:NSControlStateValueOff];
    
    // Profit target mode control
    [self.profitTargetModeControl setSegmentCount:4];
    [self.profitTargetModeControl setLabel:@"Price" forSegment:ProfitTargetModePrice];
    [self.profitTargetModeControl setLabel:@"%" forSegment:ProfitTargetModePercent];
    [self.profitTargetModeControl setLabel:@"$" forSegment:ProfitTargetModeDollarAmount];
    [self.profitTargetModeControl setLabel:@"R:R" forSegment:ProfitTargetModeRRRatio];
    [self.profitTargetModeControl setSelectedSegment:ProfitTargetModePercent];
    [self.profitTargetModeControl setTarget:self];
    [self.profitTargetModeControl setAction:@selector(profitTargetModeChanged:)];
    
    // Stop loss mode control
    [self.stopLossModeControl setSegmentCount:6];
    [self.stopLossModeControl setLabel:@"Price" forSegment:StopLossModePrice];
    [self.stopLossModeControl setLabel:@"%" forSegment:StopLossModePercent];
    [self.stopLossModeControl setLabel:@"$" forSegment:StopLossModeDollarAmount];
    [self.stopLossModeControl setLabel:@"ATR" forSegment:StopLossModeATR];
    [self.stopLossModeControl setLabel:@"Day Low" forSegment:StopLossModeDayLow];
    [self.stopLossModeControl setLabel:@"Day High" forSegment:StopLossModeDayHigh];
    [self.stopLossModeControl setSelectedSegment:StopLossModePercent];
    [self.stopLossModeControl setTarget:self];
    [self.stopLossModeControl setAction:@selector(stopLossModeChanged:)];
    
    // Bracket order fields
    self.profitTargetField.placeholderString = @"10.0";
    [self.profitTargetField setTarget:self];
    [self.profitTargetField setAction:@selector(profitTargetFieldChanged:)];
    
    self.stopLossField.placeholderString = @"3.0";
    [self.stopLossField setTarget:self];
    [self.stopLossField setAction:@selector(stopLossFieldChanged:)];
}

- (void)setupRiskManagementPanel {
    // Initialize risk labels
    self.riskAmountLabel.stringValue = @"Risk: --";
    self.rewardAmountLabel.stringValue = @"Reward: --";
    self.riskRewardRatioLabel.stringValue = @"R:R: --";
    self.portfolioRiskLabel.stringValue = @"Portfolio Risk: --%";
    self.maxLossLabel.stringValue = @"Max Loss: --";
    
    // Style risk panel
    self.riskManagementPanel.wantsLayer = YES;
    self.riskManagementPanel.layer.backgroundColor = [NSColor controlBackgroundColor].CGColor;
    self.riskManagementPanel.layer.cornerRadius = 6.0;
    self.riskManagementPanel.layer.borderWidth = 1.0;
    self.riskManagementPanel.layer.borderColor = [NSColor systemOrangeColor].CGColor;
}

- (void)setupPresetsPanel {
    // Preset buttons
    [self.scalpPresetButton setTarget:self];
    [self.scalpPresetButton setAction:@selector(applyScalpPreset:)];
    [self.scalpPresetButton setTitle:@"Scalp (0.5% SL, 1% TP)"];
    
    [self.swingPresetButton setTarget:self];
    [self.swingPresetButton setAction:@selector(applySwingPreset:)];
    [self.swingPresetButton setTitle:@"Swing (3% SL, 10% TP)"];
    
    [self.breakoutPresetButton setTarget:self];
    [self.breakoutPresetButton setAction:@selector(applyBreakoutPreset:)];
    [self.breakoutPresetButton setTitle:@"Breakout (Day Range)"];
    
    [self.customPreset1Button setTarget:self];
    [self.customPreset1Button setAction:@selector(applyCustomPreset1:)];
    [self.customPreset1Button setTitle:@"Custom 1"];
    
    [self.customPreset2Button setTarget:self];
    [self.customPreset2Button setAction:@selector(applyCustomPreset2:)];
    [self.customPreset2Button setTitle:@"Custom 2"];
}

- (void)setupOrderPreviewSection {
    // Order preview text view
    self.orderPreviewTextView.editable = NO;
    self.orderPreviewTextView.font = [NSFont monospacedSystemFontOfSize:12 weight:NSFontWeightRegular];
    self.orderPreviewTextView.backgroundColor = [NSColor controlBackgroundColor];
    self.orderPreviewTextView.string = @"Enter order details to see preview...";
    
    // Action buttons
    [self.validateOrderButton setTarget:self];
    [self.validateOrderButton setAction:@selector(validateOrder:)];
    [self.validateOrderButton setTitle:@"Validate Order"];
    
    [self.submitOrderButton setTarget:self];
    [self.submitOrderButton setAction:@selector(submitOrder:)];
    [self.submitOrderButton setTitle:@"Submit Order"];
    [self.submitOrderButton setKeyEquivalent:@"\r"];
    
    [self.resetFormButton setTarget:self];
    [self.resetFormButton setAction:@selector(resetForm:)];
    [self.resetFormButton setTitle:@"Reset Form"];
}

- (void)setupLayoutConstraints {
    // This would contain all the Auto Layout constraints
    // Simplified for brevity - in real implementation, this would be extensive
    NSLog(@"📐 OrderEntry: Layout constraints setup complete");
}

- (void)setupDefaultValues {
    // Set reasonable defaults
    self.quantityField.stringValue = @"100";
    self.profitTargetField.stringValue = @"10.0";
    self.stopLossField.stringValue = @"3.0";
    
    [self recalculateAllValues];
}

#pragma mark - Notification Observers

- (void)setupNotificationObservers {
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    
    // Quote updates
    [nc addObserver:self
           selector:@selector(handleQuoteUpdate:)
               name:DataHubQuoteUpdatedNotification
             object:nil];
    
    // Portfolio updates
    [nc addObserver:self
           selector:@selector(handlePortfolioUpdate:)
               name:PortfolioSummaryUpdatedNotification
             object:nil];
}

- (void)handleQuoteUpdate:(NSNotification *)notification {
    NSString *symbol = notification.userInfo[@"symbol"];
    MarketQuoteModel *quote = notification.userInfo[@"quote"];
    
    if ([symbol isEqualToString:self.currentSymbol]) {
        [self updateMarketDataForSymbol:symbol quote:(TradingQuoteModel *)quote];
    }
}

- (void)handlePortfolioUpdate:(NSNotification *)notification {
    PortfolioSummaryModel *portfolio = notification.userInfo[@"summary"];
    self.currentPortfolio = portfolio;
    [self recalculateAllValues];
}

#pragma mark - Market Data Management

- (void)updateMarketDataForSymbol:(NSString *)symbol quote:(TradingQuoteModel *)quote {
    if (!symbol || !quote) return;
    
    self.currentQuote = quote;
    self.lastQuoteRefresh = [NSDate date];
    
    // Update market data display
    self.lastPriceLabel.stringValue = [NSString stringWithFormat:@"Last: %.2f", quote.lastPrice];
    self.bidLabel.stringValue = [NSString stringWithFormat:@"Bid: %.2f", quote.bid];
    self.askLabel.stringValue = [NSString stringWithFormat:@"Ask: %.2f", quote.ask];
    
    double spread = quote.ask - quote.bid;
    self.spreadLabel.stringValue = [NSString stringWithFormat:@"Spread: %.2f", spread];
    
    self.volumeLabel.stringValue = [NSString stringWithFormat:@"Vol: %@", [self formatVolume:quote.volume]];
    self.dayRangeLabel.stringValue = [NSString stringWithFormat:@"Range: %.2f - %.2f", quote.low, quote.high];
    
    // Color code change
    NSColor *changeColor = quote.change >= 0 ? [NSColor systemGreenColor] : [NSColor systemRedColor];
    NSString *changeText = [NSString stringWithFormat:@"%.2f (%.2f%%)", quote.change, quote.changePercent];
    self.changeLabel.stringValue = changeText;
    self.changeLabel.textColor = changeColor;
    
    // Recalculate all values with new price data
    [self recalculateAllValues];
    
    NSLog(@"📊 OrderEntry: Updated market data for %@ - Last: %.2f, Bid: %.2f, Ask: %.2f",
          symbol, quote.lastPrice, quote.bid, quote.ask);
}

- (void)refreshMarketData {
    if (self.currentSymbol.length == 0) return;
    
    [[DataHub sharedDataHub] getQuoteForSymbol:self.currentSymbol completion:^(MarketQuoteModel *quote, BOOL isLive) {
        if (quote) {
            [self updateMarketDataForSymbol:self.currentSymbol quote:(TradingQuoteModel *)quote];
        }
    }];
}

- (void)clearMarketData {
    self.currentQuote = nil;
    self.lastPriceLabel.stringValue = @"Last: --";
    self.bidLabel.stringValue = @"Bid: --";
    self.askLabel.stringValue = @"Ask: --";
    self.spreadLabel.stringValue = @"Spread: --";
    self.volumeLabel.stringValue = @"Vol: --";
    self.dayRangeLabel.stringValue = @"Range: --";
    self.changeLabel.stringValue = @"Change: --";
    self.changeLabel.textColor = [NSColor labelColor];
}

- (void)startMarketDataRefresh {
    if (self.marketDataRefreshTimer) {
        [self.marketDataRefreshTimer invalidate];
    }
    
    // Refresh market data every 5 seconds
    self.marketDataRefreshTimer = [NSTimer scheduledTimerWithTimeInterval:5.0
                                                                   target:self
                                                                 selector:@selector(refreshMarketData)
                                                                 userInfo:nil
                                                                  repeats:YES];
}

- (void)stopMarketDataRefresh {
    if (self.marketDataRefreshTimer) {
        [self.marketDataRefreshTimer invalidate];
        self.marketDataRefreshTimer = nil;
    }
}

#pragma mark - Form Actions

- (IBAction)symbolFieldChanged:(NSTextField *)sender {
    NSString *symbol = sender.stringValue.uppercaseString;
    
    if (symbol.length == 0) {
        [self clearMarketData];
        self.currentSymbol = nil;
        return;
    }
    
    // Update symbol field to uppercase
    sender.stringValue = symbol;
    
    // Only refresh if symbol actually changed
    if (![symbol isEqualToString:self.currentSymbol]) {
        self.currentSymbol = symbol;
        
        // Clear old data
        [self clearMarketData];
        
        // Debounce symbol lookup
        [self.validationTimer invalidate];
        self.validationTimer = [NSTimer scheduledTimerWithTimeInterval:0.5
                                                                 target:self
                                                               selector:@selector(lookupCurrentSymbol)
                                                               userInfo:nil
                                                                repeats:NO];
    }
}

- (void)lookupCurrentSymbol {
    if (self.currentSymbol.length == 0) return;
    
    NSLog(@"🔍 OrderEntry: Looking up symbol %@", self.currentSymbol);
    
    [[DataHub sharedDataHub] getQuoteForSymbol:self.currentSymbol completion:^(MarketQuoteModel *quote, BOOL isLive) {
        if (quote) {
            [self updateMarketDataForSymbol:self.currentSymbol quote:(TradingQuoteModel *)quote];
            
            // Subscribe to real-time updates
            [[DataHub sharedDataHub] subscribeToQuoteUpdatesForSymbol:self.currentSymbol];
        } else {
            NSLog(@"❌ OrderEntry: Failed to get quote for %@", self.currentSymbol);
        }
    }];
}

- (IBAction)lookupSymbol:(NSButton *)sender {
    [self lookupCurrentSymbol];
}

- (IBAction)orderTypeChanged:(NSPopUpButton *)sender {
    NSString *orderType = sender.selectedItem.title;
    [self updateUIForOrderType:orderType];
    [self recalculateAllValues];
}

- (IBAction)sideChanged:(NSPopUpButton *)sender {
    NSString *side = sender.selectedItem.title;
    [self updateUIForSide:side];
    [self recalculateAllValues];
}

- (IBAction)timeInForceChanged:(NSPopUpButton *)sender {
    [self recalculateAllValues];
}

#pragma mark - Quantity Calculation Actions

- (IBAction)quantityModeChanged:(NSSegmentedControl *)sender {
    self.currentQuantityMode = sender.selectedSegment;
    [self updateQuantityFieldPlaceholder];
    [self recalculateShares];
}

- (void)updateQuantityFieldPlaceholder {
    switch (self.currentQuantityMode) {
        case QuantityModeShares:
            self.quantityField.placeholderString = @"100";
            break;
        case QuantityModePortfolioPercent:
            self.quantityField.placeholderString = @"5.0";
            break;
        case QuantityModeCashPercent:
            self.quantityField.placeholderString = @"10.0";
            break;
        case QuantityModeDollarAmount:
            self.quantityField.placeholderString = @"5000";
            break;
        case QuantityModeRiskAmount:
            self.quantityField.placeholderString = @"500";
            break;
    }
}

- (IBAction)quantityFieldChanged:(NSTextField *)sender {
    [self recalculateShares];
}

#pragma mark - Price Actions

- (IBAction)limitPriceChanged:(NSTextField *)sender {
    [self recalculateAllValues];
}

- (IBAction)stopPriceChanged:(NSTextField *)sender {
    [self recalculateAllValues];
}

- (IBAction)setBidPrice:(NSButton *)sender {
    if (self.currentQuote && self.currentQuote.bid > 0) {
        self.limitPriceField.stringValue = [NSString stringWithFormat:@"%.2f", self.currentQuote.bid];
        [self recalculateAllValues];
    }
}

- (IBAction)setAskPrice:(NSButton *)sender {
    if (self.currentQuote && self.currentQuote.ask > 0) {
        self.limitPriceField.stringValue = [NSString stringWithFormat:@"%.2f", self.currentQuote.ask];
        [self recalculateAllValues];
    }
}

- (IBAction)setLastPrice:(NSButton *)sender {
    if (self.currentQuote && self.currentQuote.lastPrice > 0) {
        self.limitPriceField.stringValue = [NSString stringWithFormat:@"%.2f", self.currentQuote.lastPrice];
        [self recalculateAllValues];
    }
}

#pragma mark - Bracket Orders Actions

- (IBAction)bracketOrdersToggled:(NSButton *)sender {
    self.bracketOrdersEnabled = (sender.state == NSControlStateValueOn);
    [self updateBracketOrdersVisibility];
    [self recalculateAllValues];
}

- (IBAction)profitTargetModeChanged:(NSSegmentedControl *)sender {
    self.currentProfitTargetMode = sender.selectedSegment;
    [self updateProfitTargetFieldPlaceholder];
    [self recalculateBracketPrices];
}

- (IBAction)profitTargetFieldChanged:(NSTextField *)sender {
    [self recalculateBracketPrices];
}

- (IBAction)stopLossModeChanged:(NSSegmentedControl *)sender {
    self.currentStopLossMode = sender.selectedSegment;
    [self updateStopLossFieldPlaceholder];
    [self recalculateBracketPrices];
}

- (IBAction)stopLossFieldChanged:(NSTextField *)sender {
    [self recalculateBracketPrices];
}

- (void)updateProfitTargetFieldPlaceholder {
    switch (self.currentProfitTargetMode) {
        case ProfitTargetModePrice:
            self.profitTargetField.placeholderString = @"155.00";
            break;
        case ProfitTargetModePercent:
            self.profitTargetField.placeholderString = @"10.0";
            break;
        case ProfitTargetModeDollarAmount:
            self.profitTargetField.placeholderString = @"1000";
            break;
        case ProfitTargetModeRRRatio:
            self.profitTargetField.placeholderString = @"3.0";
            break;
    }
}

- (void)updateStopLossFieldPlaceholder {
    switch (self.currentStopLossMode) {
        case StopLossModePrice:
            self.stopLossField.placeholderString = @"145.00";
            break;
        case StopLossModePercent:
            self.stopLossField.placeholderString = @"3.0";
            break;
        case StopLossModeDollarAmount:
            self.stopLossField.placeholderString = @"500";
            break;
        case StopLossModeATR:
            self.stopLossField.placeholderString = @"2.0";
            break;
        case StopLossModeDayLow:
        case StopLossModeDayHigh:
            self.stopLossField.placeholderString = @"0.10";
            break;
    }
}

#pragma mark - Preset Actions

- (IBAction)applyScalpPreset:(NSButton *)sender {
    if (!self.currentQuote) {
        NSLog(@"⚠️ OrderEntry: Need market data to apply scalp preset");
        return;
    }
    
    // Apply scalping preset
    self.bracketOrdersEnabled = YES;
    [self.enableBracketOrdersCheckbox setState:NSControlStateValueOn];
    
    [self.orderTypePopup selectItemWithTitle:@"LIMIT"];
    [self.timeInForcePopup selectItemWithTitle:@"DAY"];
    
    // Set prices
    double entryPrice = self.currentQuote.ask; // Enter at ask for quick fill
    self.limitPriceField.stringValue = [NSString stringWithFormat:@"%.2f", entryPrice];
    
    // Scalping: tight stops and targets
    [self.stopLossModeControl setSelectedSegment:StopLossModePercent];
    [self.profitTargetModeControl setSelectedSegment:ProfitTargetModePercent];
    self.stopLossField.stringValue = @"0.5";     // 0.5% stop
    self.profitTargetField.stringValue = @"1.0"; // 1% target
    
    [self updateBracketOrdersVisibility];
    [self recalculateAllValues];
    
    NSLog(@"📈 OrderEntry: Applied scalp preset");
}

- (IBAction)applySwingPreset:(NSButton *)sender {
    if (!self.currentQuote) {
        NSLog(@"⚠️ OrderEntry: Need market data to apply swing preset");
        return;
    }
    
    // Apply swing trading preset
    self.bracketOrdersEnabled = YES;
    [self.enableBracketOrdersCheckbox setState:NSControlStateValueOn];
    
    [self.orderTypePopup selectItemWithTitle:@"LIMIT"];
    [self.timeInForcePopup selectItemWithTitle:@"GTC"];
    
    // Set entry price
    double entryPrice = self.currentQuote.lastPrice;
    self.limitPriceField.stringValue = [NSString stringWithFormat:@"%.2f", entryPrice];
    
    // Swing trading: wider stops and targets
    [self.stopLossModeControl setSelectedSegment:StopLossModePercent];
    [self.profitTargetModeControl setSelectedSegment:ProfitTargetModePercent];
    self.stopLossField.stringValue = @"3.0";      // 3% stop
    self.profitTargetField.stringValue = @"10.0"; // 10% target
    
    [self updateBracketOrdersVisibility];
    [self recalculateAllValues];
    
    NSLog(@"📊 OrderEntry: Applied swing preset");
}

- (IBAction)applyBreakoutPreset:(NSButton *)sender {
    if (!self.currentQuote) {
        NSLog(@"⚠️ OrderEntry: Need market data to apply breakout preset");
        return;
    }
    
    // Apply breakout preset based on day's range
    self.bracketOrdersEnabled = YES;
    [self.enableBracketOrdersCheckbox setState:NSControlStateValueOn];
    
    NSString *side = self.sidePopup.selectedItem.title;
    double dayHigh = self.currentQuote.high;
    double dayLow = self.currentQuote.low;
    
    if ([side hasPrefix:@"BUY"]) {
        // Bullish breakout above day high
        [self.orderTypePopup selectItemWithTitle:@"STOP"];
        double entryPrice = dayHigh + 0.05; // $0.05 above day high
        self.stopPriceField.stringValue = [NSString stringWithFormat:@"%.2f", entryPrice];
        
        // Stop at day low
        [self.stopLossModeControl setSelectedSegment:StopLossModeDayLow];
        self.stopLossField.stringValue = @"0.10"; // $0.10 below day low
    } else {
        // Bearish breakdown below day low
        [self.orderTypePopup selectItemWithTitle:@"STOP"];
        double entryPrice = dayLow - 0.05; // $0.05 below day low
