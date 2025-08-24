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
    [self unsubscribeFromMarketData];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    NSLog(@"📝 OrderEntryViewController deallocated");
}

#pragma mark - UI Setup

- (void)setupUI {
    [self setupSymbolSection];
    [self setupMarketDataPanel];
    [self setupOrderTypeSection];
    // Solo i metodi che esistono veramente
    [self updateUIForOrderType:@"MARKET"];
    [self updateBracketOrdersVisibility];
}

- (void)setupSymbolSection {
    // Symbol field setup - USA NOMI CORRETTI DAL .h
    self.symbolField.placeholderString = @"Enter symbol (e.g. AAPL)";
    [self.symbolField setTarget:self];
    [self.symbolField setAction:@selector(symbolFieldChanged:)];
    
    // Lookup button - USA NOME CORRETTO
    [self.symbolLookupButton setTarget:self];
    [self.symbolLookupButton setAction:@selector(lookupSymbol:)];
    [self.symbolLookupButton setTitle:@"Lookup"];
}

- (void)setupMarketDataPanel {
    // Initialize market data labels - USA NOMI CORRETTI DAL .h
    self.lastPriceLabel.stringValue = @"Last: --";
    self.bidLabel.stringValue = @"Bid: --";
    self.askLabel.stringValue = @"Ask: --";
    self.spreadLabel.stringValue = @"Spread: --";
    self.volumeLabel.stringValue = @"Vol: --";
    self.dayRangeLabel.stringValue = @"Range: --";
    self.changeLabel.stringValue = @"Change: --";
    // RIMUOVO timestampLabel che non esiste nel .h
    
    // Style the panel
    self.marketDataPanel.wantsLayer = YES;
    self.marketDataPanel.layer.backgroundColor = [NSColor controlBackgroundColor].CGColor;
    self.marketDataPanel.layer.cornerRadius = 8.0;
}

- (void)setupOrderTypeSection {
    // Order type popup
    [self.orderTypePopup removeAllItems];
    [self.orderTypePopup addItemsWithTitles:@[@"MARKET", @"LIMIT", @"STOP", @"STOP_LIMIT"]];
    [self.orderTypePopup setTarget:self];
    [self.orderTypePopup setAction:@selector(orderTypeChanged:)];
    
    // Side popup
    [self.sidePopup removeAllItems];
    [self.sidePopup addItemsWithTitles:@[@"BUY", @"SELL", @"SHORT"]];
    [self.sidePopup setTarget:self];
    [self.sidePopup setAction:@selector(sideChanged:)];
    
    // Time in force popup
    [self.timeInForcePopup removeAllItems];
    [self.timeInForcePopup addItemsWithTitles:@[@"DAY", @"GTC", @"IOC", @"FOK"]];
    [self.timeInForcePopup setTarget:self];
    [self.timeInForcePopup setAction:@selector(timeInForceChanged:)];
}

#pragma mark - Notification Observers - CORREZIONI

- (void)setupNotificationObservers {
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    
    // Quote updates - CORREZIONE: nome notification corretto
    [nc addObserver:self
           selector:@selector(handleQuoteUpdate:)
               name:@"DataHubQuoteUpdatedNotification"  // ✅ CORRETTO
             object:nil];
    
    // Portfolio updates
    [nc addObserver:self
           selector:@selector(handlePortfolioUpdate:)
               name:@"PortfolioSummaryUpdatedNotification"
             object:nil];
}

- (void)handleQuoteUpdate:(NSNotification *)notification {
    NSString *symbol = notification.userInfo[@"symbol"];
    MarketQuoteModel *quote = notification.userInfo[@"quote"]; // ✅ CORRETTO: MarketQuoteModel
    
    if ([symbol isEqualToString:self.currentSymbol]) {
        [self updateMarketDataForSymbol:symbol quote:quote]; // ✅ CORRETTO: rimosso cast errato
    }
}

- (void)handlePortfolioUpdate:(NSNotification *)notification {
    PortfolioSummaryModel *portfolio = notification.userInfo[@"summary"];
    self.currentPortfolio = portfolio;
    [self recalculateAllValues];
}

- (void)setupDefaultValues {
    // Set reasonable defaults
    self.quantityField.stringValue = @"100";
    self.profitTargetField.stringValue = @"10.0";
    self.stopLossField.stringValue = @"3.0";
    
    [self recalculateAllValues];
}

#pragma mark - Market Data Management - CORREZIONI

- (void)updateMarketDataForSymbol:(NSString *)symbol quote:(MarketQuoteModel *)quote {
    if (!symbol || !quote) return;
    
    // Store quote - CORREZIONE: cambio il cast per corrispondere al .h
    self.currentQuote = (TradingQuoteModel *)quote; // Cast per compatibilità esistente
    self.lastQuoteRefresh = [NSDate date];
    
    // Update market data display - CORREZIONI: accesso corretto alle proprietà NSNumber
    self.lastPriceLabel.stringValue = [NSString stringWithFormat:@"Last: %.2f", quote.last.doubleValue]; // ✅ CORRETTO
    
    if (quote.bid && quote.ask) { // ✅ CORRETTO: controllo nil per NSNumber
        self.bidLabel.stringValue = [NSString stringWithFormat:@"Bid: %.2f", quote.bid.doubleValue]; // ✅ CORRETTO
        self.askLabel.stringValue = [NSString stringWithFormat:@"Ask: %.2f", quote.ask.doubleValue]; // ✅ CORRETTO
        
        double spread = quote.ask.doubleValue - quote.bid.doubleValue; // ✅ CORRETTO
        self.spreadLabel.stringValue = [NSString stringWithFormat:@"Spread: %.2f", spread];
    } else {
        self.bidLabel.stringValue = @"Bid: --";
        self.askLabel.stringValue = @"Ask: --";
        self.spreadLabel.stringValue = @"Spread: --";
    }
    
    // Volume - CORREZIONE: gestione NSNumber
    if (quote.volume) {
        self.volumeLabel.stringValue = [NSString stringWithFormat:@"Vol: %@", [self formatVolume:quote.volume.integerValue]]; // ✅ CORRETTO
    } else {
        self.volumeLabel.stringValue = @"Vol: --";
    }
    
    // Day range - CORREZIONE: gestione NSNumber e controlli nil
    if (quote.low && quote.high) {
        self.dayRangeLabel.stringValue = [NSString stringWithFormat:@"Range: %.2f - %.2f",
                                         quote.low.doubleValue, quote.high.doubleValue]; // ✅ CORRETTO
    } else {
        self.dayRangeLabel.stringValue = @"Range: --";
    }
    
    // Color code change - CORREZIONE: gestione NSNumber
    NSColor *changeColor = (quote.change && quote.change.doubleValue >= 0) ? // ✅ CORRETTO
                          [NSColor systemGreenColor] : [NSColor systemRedColor];
    
    if (quote.change && quote.changePercent) { // ✅ CORRETTO: controllo nil
        NSString *changeText = [NSString stringWithFormat:@"%.2f (%.2f%%)",
                               quote.change.doubleValue, quote.changePercent.doubleValue]; // ✅ CORRETTO
        self.changeLabel.stringValue = changeText;
        self.changeLabel.textColor = changeColor;
    } else {
        self.changeLabel.stringValue = @"Change: --";
        self.changeLabel.textColor = [NSColor labelColor];
    }
    
    // Recalculate all values with new price data
    [self recalculateAllValues];
    
    NSLog(@"📊 OrderEntry: Updated market data for %@ - Last: %.2f, Bid: %.2f, Ask: %.2f",
          symbol, quote.last.doubleValue,
          quote.bid ? quote.bid.doubleValue : 0.0,
          quote.ask ? quote.ask.doubleValue : 0.0); // ✅ CORRETTO
}

- (void)refreshMarketData {
    if (self.currentSymbol.length == 0) return;
    
    // CORREZIONE: DataHub singleton pattern corretto
    DataHub *dataHub = [DataHub shared]; // ✅ CORRETTO: shared invece di sharedDataHub
    [dataHub getQuoteForSymbol:self.currentSymbol completion:^(MarketQuoteModel *quote, BOOL isLive) {
        if (quote) {
            [self updateMarketDataForSymbol:self.currentSymbol quote:quote]; // ✅ CORRETTO: rimosso cast
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
    // RIMOSSO timestampLabel che non esiste
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

- (void)subscribeToMarketData {
    if (self.currentSymbol.length > 0) {
        DataHub *dataHub = [DataHub shared]; // ✅ CORRETTO: shared
        [dataHub subscribeToQuoteUpdatesForSymbol:self.currentSymbol];
    }
}

- (void)unsubscribeFromMarketData {
    if (self.currentSymbol.length > 0) {
        DataHub *dataHub = [DataHub shared]; // ✅ CORRETTO: shared
        [dataHub unsubscribeFromQuoteUpdatesForSymbol:self.currentSymbol];
    }
}

#pragma mark - Form Actions - CORREZIONI

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
    
    // CORREZIONE: DataHub singleton pattern corretto
    DataHub *dataHub = [DataHub shared]; // ✅ CORRETTO
    [dataHub getQuoteForSymbol:self.currentSymbol completion:^(MarketQuoteModel *quote, BOOL isLive) {
        if (quote) {
            [self updateMarketDataForSymbol:self.currentSymbol quote:quote]; // ✅ CORRETTO
            
            // Subscribe to real-time updates
            [dataHub subscribeToQuoteUpdatesForSymbol:self.currentSymbol];
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
    [self recalculateShares];
}

- (IBAction)quantityFieldChanged:(NSTextField *)sender {
    [self recalculateShares];
}

- (void)recalculateShares {
    double inputValue = self.quantityField.doubleValue;
    double sharePrice = [self getEffectiveSharePrice];
    
    if (inputValue <= 0 || sharePrice <= 0) {
        self.calculatedShares = 0;
        [self updateCalculatedSharesDisplay];
        return;
    }
    
    switch (self.currentQuantityMode) {
        case QuantityModeShares:
            self.calculatedShares = inputValue;
            break;
            
        case QuantityModePortfolioPercent:
            if (self.currentPortfolio && self.currentPortfolio.totalValue > 0) {
                double portfolioValue = self.currentPortfolio.totalValue;
                double dollarAmount = portfolioValue * (inputValue / 100.0);
                self.calculatedShares = floor(dollarAmount / sharePrice);
            }
            break;
            
        case QuantityModeCashPercent:
            if (self.currentPortfolio && self.currentPortfolio.cashBalance > 0) {
                double cashBalance = self.currentPortfolio.cashBalance;
                double dollarAmount = cashBalance * (inputValue / 100.0);
                self.calculatedShares = floor(dollarAmount / sharePrice);
            }
            break;
            
        case QuantityModeDollarAmount:
            self.calculatedShares = floor(inputValue / sharePrice);
            break;
            
        case QuantityModeRiskAmount:
            // Risk-based position sizing requires stop loss
            if (self.bracketOrdersEnabled && self.stopLossField.doubleValue > 0) {
                double riskPerShare = [self calculateRiskPerShare];
                if (riskPerShare > 0) {
                    self.calculatedShares = floor(inputValue / riskPerShare);
                }
            }
            break;
    }
    
    [self updateCalculatedSharesDisplay];
    [self recalculatePositionValue];
    [self recalculateRiskReward];
}

- (double)calculateRiskPerShare {
    double entryPrice = [self getEffectiveSharePrice];
    if (entryPrice <= 0) return 0.0;
    
    NSString *side = self.sidePopup.selectedItem.title;
    BOOL isBuy = [side hasPrefix:@"BUY"];
    
    double stopPrice = 0.0;
    
    if (self.currentStopLossMode == StopLossModePercent) {
        double stopPercent = self.stopLossField.doubleValue / 100.0;
        if (isBuy) {
            stopPrice = entryPrice * (1.0 - stopPercent);
        } else {
            stopPrice = entryPrice * (1.0 + stopPercent);
        }
    } else if (self.currentStopLossMode == StopLossModeDollarAmount) {
        double stopAmount = self.stopLossField.doubleValue;
        if (isBuy) {
            stopPrice = entryPrice - stopAmount;
        } else {
            stopPrice = entryPrice + stopAmount;
        }
    }
    
    if (stopPrice > 0) {
        return fabs(entryPrice - stopPrice);
    }
    
    return 0.0;
}

#pragma mark - Price Actions - CORREZIONI

- (IBAction)limitPriceChanged:(NSTextField *)sender {
    [self recalculateAllValues];
}

- (IBAction)stopPriceChanged:(NSTextField *)sender {
    [self recalculateAllValues];
}

// USA NOMI CORRETTI DAL .h
- (IBAction)setBidPrice:(NSButton *)sender {
    if (self.currentQuote && self.currentQuote.bid) { // ✅ CORRETTO: controllo nil
        self.limitPriceField.doubleValue = self.currentQuote.bid.doubleValue; // ✅ CORRETTO
        [self recalculateAllValues];
    }
}

- (IBAction)setAskPrice:(NSButton *)sender {
    if (self.currentQuote && self.currentQuote.ask) { // ✅ CORRETTO: controllo nil
        self.limitPriceField.doubleValue = self.currentQuote.ask.doubleValue; // ✅ CORRETTO
        [self recalculateAllValues];
    }
}

- (IBAction)setLastPrice:(NSButton *)sender {
    if (self.currentQuote && self.currentQuote.last) { // ✅ CORRETTO: controllo nil
        self.limitPriceField.doubleValue = self.currentQuote.last.doubleValue; // ✅ CORRETTO
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
    [self recalculateBracketPrices];
}

- (IBAction)profitTargetFieldChanged:(NSTextField *)sender {
    [self recalculateBracketPrices];
}

- (IBAction)stopLossModeChanged:(NSSegmentedControl *)sender {
    self.currentStopLossMode = sender.selectedSegment;
    [self recalculateBracketPrices];
}

- (IBAction)stopLossFieldChanged:(NSTextField *)sender {
    [self recalculateBracketPrices];
}

#pragma mark - Calculation Methods - CORREZIONI NSNumber

- (void)recalculateBracketPrices {
    // CORREZIONE: void method non deve ritornare valori
    double entryPrice = [self getEffectiveSharePrice];
    if (entryPrice <= 0.0) return; // ✅ CORRETTO: rimosso return value
    
    NSString *side = self.sidePopup.selectedItem.title;
    BOOL isBuy = [side hasPrefix:@"BUY"];
    
    // Calculate profit target - USA NOMI CORRETTI DAL .h
    if (self.currentProfitTargetMode == ProfitTargetModePercent) {
        double targetPercent = self.profitTargetField.doubleValue / 100.0;
        if (isBuy) {
            double targetPrice = entryPrice * (1.0 + targetPercent); // ✅ CORRETTO: calcolo semplificato
            self.calculatedProfitPriceLabel.stringValue = [NSString stringWithFormat:@"Target: $%.2f", targetPrice]; // ✅ NOME CORRETTO
        } else {
            double targetPrice = entryPrice * (1.0 - targetPercent); // ✅ CORRETTO: calcolo semplificato
            self.calculatedProfitPriceLabel.stringValue = [NSString stringWithFormat:@"Target: $%.2f", targetPrice]; // ✅ NOME CORRETTO
        }
    } else if (self.currentProfitTargetMode == ProfitTargetModeDollarAmount) { // ✅ NOME CORRETTO
        double targetAmount = self.profitTargetField.doubleValue;
        if (isBuy) {
            double targetPrice = entryPrice + targetAmount; // ✅ CORRETTO: somma diretta
            self.calculatedProfitPriceLabel.stringValue = [NSString stringWithFormat:@"Target: $%.2f", targetPrice];
        } else {
            double targetPrice = entryPrice - targetAmount; // ✅ CORRETTO: sottrazione diretta
            self.calculatedProfitPriceLabel.stringValue = [NSString stringWithFormat:@"Target: $%.2f", targetPrice];
        }
    }
    
    // Calculate stop loss - USA NOMI CORRETTI
    if (self.currentStopLossMode == StopLossModePercent) {
        double stopPercent = self.stopLossField.doubleValue / 100.0;
        if (isBuy) {
            double stopPrice = entryPrice * (1.0 - stopPercent); // ✅ CORRETTO: calcolo semplificato
            self.calculatedStopPriceLabel.stringValue = [NSString stringWithFormat:@"Stop: $%.2f", stopPrice]; // ✅ NOME CORRETTO
        } else {
            double stopPrice = entryPrice * (1.0 + stopPercent); // ✅ CORRETTO: calcolo semplificato
            self.calculatedStopPriceLabel.stringValue = [NSString stringWithFormat:@"Stop: $%.2f", stopPrice];
        }
    } else if (self.currentStopLossMode == StopLossModeDollarAmount) { // ✅ NOME CORRETTO
        double stopAmount = self.stopLossField.doubleValue;
        if (isBuy) {
            double stopPrice = entryPrice - stopAmount; // ✅ CORRETTO: sottrazione diretta
            self.calculatedStopPriceLabel.stringValue = [NSString stringWithFormat:@"Stop: $%.2f", stopPrice];
        } else {
            double stopPrice = entryPrice + stopAmount; // ✅ CORRETTO: somma diretta
            self.calculatedStopPriceLabel.stringValue = [NSString stringWithFormat:@"Stop: $%.2f", stopPrice];
        }
    }
}

- (void)recalculatePositionValue {
    double shares = self.calculatedShares;
    double sharePrice = [self getEffectiveSharePrice];
    
    if (shares > 0 && sharePrice > 0) {
        self.calculatedPositionValue = shares * sharePrice; // ✅ CORRETTO: calcolo diretto
    } else {
        self.calculatedPositionValue = 0.0;
    }
    
    // Update UI - USA NOME CORRETTO
    self.positionValueLabel.stringValue = [NSString stringWithFormat:@"Position Value: $%.2f", self.calculatedPositionValue];
}

- (void)recalculateRiskReward {
    if (!self.bracketOrdersEnabled) {
        self.riskAmountLabel.stringValue = @"Risk: N/A";
        self.rewardAmountLabel.stringValue = @"Reward: N/A";
        self.riskRewardRatioLabel.stringValue = @"R:R: N/A";
        return;
    }
    
    double shares = self.calculatedShares;
    double entryPrice = [self getEffectiveSharePrice];
    
    if (shares <= 0 || entryPrice <= 0) return;
    
    // Parse profit target and stop loss prices from labels - USA NOMI CORRETTI
    NSString *targetText = self.calculatedProfitPriceLabel.stringValue;
    NSString *stopText = self.calculatedStopPriceLabel.stringValue;
    
    // Extract prices from formatted strings like "Target: $123.45"
    double targetPrice = [self extractPriceFromLabel:targetText];
    double stopPrice = [self extractPriceFromLabel:stopText];
    
    if (targetPrice > 0 && stopPrice > 0) {
        NSString *side = self.sidePopup.selectedItem.title;
        BOOL isBuy = [side hasPrefix:@"BUY"];
        
        if (isBuy) {
            self.calculatedRiskAmount = shares * (entryPrice - stopPrice); // ✅ CORRETTO: calcolo diretto
            self.calculatedRewardAmount = shares * (targetPrice - entryPrice); // ✅ CORRETTO: calcolo diretto
        } else {
            self.calculatedRiskAmount = shares * (stopPrice - entryPrice); // ✅ CORRETTO: calcolo diretto
            self.calculatedRewardAmount = shares * (entryPrice - targetPrice); // ✅ CORRETTO: calcolo diretto
        }
        
        if (self.calculatedRiskAmount > 0) {
            self.calculatedRiskRewardRatio = self.calculatedRewardAmount / self.calculatedRiskAmount; // ✅ CORRETTO
        }
        
        // Update UI
        self.riskAmountLabel.stringValue = [NSString stringWithFormat:@"Risk: $%.2f", self.calculatedRiskAmount];
        self.rewardAmountLabel.stringValue = [NSString stringWithFormat:@"Reward: $%.2f", self.calculatedRewardAmount];
        self.riskRewardRatioLabel.stringValue = [NSString stringWithFormat:@"R:R: %.2f", self.calculatedRiskRewardRatio];
        
        // Calculate portfolio risk percentage
        if (self.currentPortfolio && self.currentPortfolio.totalValue > 0) {
            double portfolioRiskPercent = (self.calculatedRiskAmount / self.currentPortfolio.totalValue) * 100.0; // ✅ CORRETTO
            self.portfolioRiskLabel.stringValue = [NSString stringWithFormat:@"Portfolio Risk: %.2f%%", portfolioRiskPercent];
        }
    }
}

#pragma mark - Helper Methods - CORREZIONI

- (double)getEffectiveSharePrice {
    NSString *orderType = self.orderTypePopup.selectedItem.title;
    
    if ([orderType isEqualToString:@"MARKET"]) {
        // For market orders, use current price or bid/ask
        if (self.currentQuote) {
            NSString *side = self.sidePopup.selectedItem.title;
            if ([side hasPrefix:@"BUY"]) {
                // BUY: use ask price or last if ask not available
                return self.currentQuote.ask ? self.currentQuote.ask.doubleValue : self.currentQuote.last.doubleValue; // ✅ CORRETTO
            } else {
                // SELL/SHORT: use bid price or last if bid not available
                return self.currentQuote.bid ? self.currentQuote.bid.doubleValue : self.currentQuote.last.doubleValue; // ✅ CORRETTO
            }
        }
        return 0.0; // No quote available
    } else if ([orderType isEqualToString:@"LIMIT"]) {
        // For limit orders, use limit price
        return self.limitPriceField.doubleValue;
    } else if ([orderType isEqualToString:@"STOP"]) {
        // For stop orders, use stop price
        return self.stopPriceField.doubleValue;
    } else if ([orderType isEqualToString:@"STOP_LIMIT"]) {
        // For stop limit orders, use limit price
        return self.limitPriceField.doubleValue;
    }
    
    return 0.0;
}

// NUOVO METODO: Helper per estrarre prezzo da label formattato
- (double)extractPriceFromLabel:(NSString *)labelText {
    if (!labelText || labelText.length == 0) return 0.0;
    
    // Cerca pattern come "$123.45" nel testo
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"\\$([0-9]+\\.?[0-9]*)"
                                                                           options:0
                                                                             error:nil];
    NSTextCheckingResult *match = [regex firstMatchInString:labelText options:0 range:NSMakeRange(0, labelText.length)];
    
    if (match && match.numberOfRanges > 1) {
        NSString *priceString = [labelText substringWithRange:[match rangeAtIndex:1]];
        return [priceString doubleValue];
    }
    
    return 0.0;
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

#pragma mark - UI Update Methods

- (void)updateCalculatedSharesDisplay {
    if (self.calculatedShares > 0) {
        self.calculatedSharesLabel.stringValue = [NSString stringWithFormat:@"Shares: %.0f", self.calculatedShares];
    } else {
        self.calculatedSharesLabel.stringValue = @"Shares: --";
    }
}

#pragma mark - UI State Management

- (void)updateUIForOrderType:(NSString *)orderType {
    // Show/hide price fields based on order type
    BOOL showLimitPrice = [orderType isEqualToString:@"LIMIT"] || [orderType isEqualToString:@"STOP_LIMIT"];
    BOOL showStopPrice = [orderType isEqualToString:@"STOP"] || [orderType isEqualToString:@"STOP_LIMIT"];
    
    self.limitPriceField.hidden = !showLimitPrice;
    self.stopPriceField.hidden = !showStopPrice;
    
    // Show/hide quick price buttons for limit orders - USA NOMI CORRETTI DAL .h
    self.setBidPriceButton.hidden = !showLimitPrice;
    self.setAskPriceButton.hidden = !showLimitPrice;
    self.setLastPriceButton.hidden = !showLimitPrice;
}

- (void)updateUIForSide:(NSString *)side {
    // Update UI elements based on order side
    if ([side isEqualToString:@"SHORT"]) {
        // Special handling for short orders
        self.quantityModeControl.enabled = YES; // Enable all quantity modes
    }
}

- (void)updateBracketOrdersVisibility {
    self.profitTargetField.hidden = !self.bracketOrdersEnabled;
    self.profitTargetModeControl.hidden = !self.bracketOrdersEnabled;
    self.stopLossField.hidden = !self.bracketOrdersEnabled;
    self.stopLossModeControl.hidden = !self.bracketOrdersEnabled;
    self.riskManagementPanel.hidden = !self.bracketOrdersEnabled;
}

- (void)recalculateAllValues {
    [self recalculateShares];
    [self recalculatePositionValue];
    if (self.bracketOrdersEnabled) {
        [self recalculateBracketPrices];
        [self recalculateRiskReward];
    }
    [self updateOrderPreview];
}

#pragma mark - Order Validation - CORREZIONI

- (BOOL)validateCurrentOrder:(NSError **)error {
    // Symbol validation
    if (self.symbolField.stringValue.length == 0) {
        if (error) {
            *error = [NSError errorWithDomain:@"OrderEntryError"
                                         code:1001
                                     userInfo:@{NSLocalizedDescriptionKey: @"Symbol is required"}];
        }
        return NO;
    }
    
    // Quantity validation - CORREZIONE: gestione conversioni double
    double quantity = self.quantityField.doubleValue; // ✅ CORRETTO: doubleValue diretto
    if (quantity <= 0) {
        if (error) {
            *error = [NSError errorWithDomain:@"OrderEntryError"
                                         code:1002
                                     userInfo:@{NSLocalizedDescriptionKey: @"Quantity must be greater than 0"}];
        }
        return NO;
    }
    
    // Price validation for limit orders
    NSString *orderType = self.orderTypePopup.selectedItem.title;
    if ([orderType isEqualToString:@"LIMIT"] || [orderType isEqualToString:@"STOP_LIMIT"]) {
        double limitPrice = self.limitPriceField.doubleValue; // ✅ CORRETTO: doubleValue diretto
        if (limitPrice <= 0) {
            if (error) {
                *error = [NSError errorWithDomain:@"OrderEntryError"
                                             code:1003
                                         userInfo:@{NSLocalizedDescriptionKey: @"Limit price must be greater than 0"}];
            }
            return NO;
        }
    }
    
    // Stop price validation for stop orders
    if ([orderType isEqualToString:@"STOP"] || [orderType isEqualToString:@"STOP_LIMIT"]) {
        double stopPrice = self.stopPriceField.doubleValue; // ✅ CORRETTO: doubleValue diretto
        if (stopPrice <= 0) {
            if (error) {
                *error = [NSError errorWithDomain:@"OrderEntryError"
                                             code:1004
                                         userInfo:@{NSLocalizedDescriptionKey: @"Stop price must be greater than 0"}];
            }
            return NO;
        }
    }
    
    // Bracket orders validation
    if (self.bracketOrdersEnabled) {
        double profitTarget = self.profitTargetField.doubleValue; // ✅ CORRETTO: doubleValue diretto
        double stopLoss = self.stopLossField.doubleValue; // ✅ CORRETTO: doubleValue diretto
        
        if (profitTarget <= 0) {
            if (error) {
                *error = [NSError errorWithDomain:@"OrderEntryError"
                                             code:1005
                                         userInfo:@{NSLocalizedDescriptionKey: @"Profit target must be greater than 0"}];
            }
            return NO;
        }
        
        if (stopLoss <= 0) {
            if (error) {
                *error = [NSError errorWithDomain:@"OrderEntryError"
                                             code:1006
                                         userInfo:@{NSLocalizedDescriptionKey: @"Stop loss must be greater than 0"}];
            }
            return NO;
        }
        
        // Advanced bracket validation
        NSString *side = self.sidePopup.selectedItem.title;
        double entryPrice = [self getEffectiveSharePrice];
        double targetPrice = [self extractPriceFromLabel:self.calculatedProfitPriceLabel.stringValue];
        double stopPrice = [self extractPriceFromLabel:self.calculatedStopPriceLabel.stringValue];
        
        // CORREZIONE: eliminata redefinizione di entryPrice
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

#pragma mark - Order Actions

- (IBAction)validateOrder:(NSButton *)sender {
    NSError *validationError;
    if ([self validateCurrentOrder:&validationError]) {
        NSAlert *alert = [[NSAlert alloc] init];
        alert.messageText = @"Order Validation Passed";
        alert.informativeText = @"All order parameters are valid and ready for submission.";
        alert.alertStyle = NSAlertStyleInformational;
        [alert addButtonWithTitle:@"OK"];
        [alert runModal];
    } else {
        NSAlert *alert = [[NSAlert alloc] init];
        alert.messageText = @"Order Validation Failed";
        alert.informativeText = validationError.localizedDescription;
        alert.alertStyle = NSAlertStyleWarning;
        [alert addButtonWithTitle:@"OK"];
        [alert runModal];
    }
}

- (IBAction)submitOrder:(NSButton *)sender {
    NSError *validationError;
    if (![self validateCurrentOrder:&validationError]) {
        NSAlert *alert = [[NSAlert alloc] init];
        alert.messageText = @"Order Validation Failed";
        alert.informativeText = validationError.localizedDescription;
        alert.alertStyle = NSAlertStyleWarning;
        [alert addButtonWithTitle:@"OK"];
        [alert runModal];
        return;
    }
    
    // ✅ CORREZIONE: Usa getPortfolioSummaryForAccount invece di getCurrentPortfolioSummary
    DataHub *dataHub = [DataHub shared];
    NSString *accountId = self.selectedAccount.accountId ?: @"default";
    
    [dataHub getPortfolioSummaryForAccount:accountId completion:^(PortfolioSummaryModel *portfolio, BOOL isFresh) {
        if (portfolio) {
            [self submitOrderWithPortfolio:portfolio];
        } else {
            NSLog(@"❌ OrderEntry: Failed to get portfolio for order submission");
            dispatch_async(dispatch_get_main_queue(), ^{
                NSAlert *alert = [[NSAlert alloc] init];
                alert.messageText = @"Portfolio Error";
                alert.informativeText = @"Failed to load portfolio information required for order submission.";
                alert.alertStyle = NSAlertStyleCritical;
                [alert addButtonWithTitle:@"OK"];
                [alert runModal];
            });
        }
    }];
}


- (void)submitOrderWithPortfolio:(PortfolioSummaryModel *)portfolio {
    // ✅ CORREZIONE: Usa buildSimpleOrder invece di buildOrderWithSymbol
    NSDictionary *orderDict = [AdvancedOrderBuilder buildSimpleOrder:self.symbolField.stringValue
                                                                 side:self.sidePopup.selectedItem.title
                                                             quantity:self.calculatedShares
                                                            orderType:self.orderTypePopup.selectedItem.title
                                                                price:self.limitPriceField.doubleValue
                                                            stopPrice:self.stopPriceField.doubleValue
                                                          timeInForce:self.timeInForcePopup.selectedItem.title];
    
    if (self.bracketOrdersEnabled) {
        double targetPrice = [self extractPriceFromLabel:self.calculatedProfitPriceLabel.stringValue];
        double stopLossPrice = [self extractPriceFromLabel:self.calculatedStopPriceLabel.stringValue];
        
        // ✅ CORREZIONE: Usa buildBracketOrder invece di addBracketOrdersToOrder
        NSArray<NSDictionary *> *bracketOrders = [AdvancedOrderBuilder buildBracketOrder:self.symbolField.stringValue
                                                                                     side:self.sidePopup.selectedItem.title
                                                                                 quantity:self.calculatedShares
                                                                                entryType:self.orderTypePopup.selectedItem.title
                                                                               entryPrice:self.limitPriceField.doubleValue
                                                                            stopLossPrice:stopLossPrice
                                                                        profitTargetPrice:targetPrice
                                                                              timeInForce:self.timeInForcePopup.selectedItem.title];
        
        // Submit bracket orders instead of single order
        [self submitBracketOrders:bracketOrders];
        return;
    }
    
    // ✅ CORREZIONE TEMPORANEA: Per ora mostra solo un dialogo di successo
    // L'API per submit order potrebbe non essere ancora implementata
    dispatch_async(dispatch_get_main_queue(), ^{
        NSAlert *alert = [[NSAlert alloc] init];
        alert.messageText = @"Order Ready for Submission";
        alert.informativeText = [NSString stringWithFormat:@"Order for %@ validated and ready. Order submission API integration pending.", self.symbolField.stringValue];
        alert.alertStyle = NSAlertStyleInformational;
        [alert addButtonWithTitle:@"OK"];
        [alert runModal];
        
        // Log the order details for debugging
        NSLog(@"📝 Order Details: %@", orderDict);
        
        [self resetForm:nil];
    });
}


- (void)submitBracketOrders:(NSArray<NSDictionary *> *)bracketOrders {
    if (!bracketOrders || bracketOrders.count == 0) {
        NSAlert *alert = [[NSAlert alloc] init];
        alert.messageText = @"Bracket Order Error";
        alert.informativeText = @"Failed to build bracket order structure";
        alert.alertStyle = NSAlertStyleCritical;
        [alert addButtonWithTitle:@"OK"];
        [alert runModal];
        return;
    }
    
    // ✅ CORREZIONE TEMPORANEA: Per ora mostra solo un dialogo di successo
    // L'API per submit bracket orders potrebbe non essere ancora implementata
    dispatch_async(dispatch_get_main_queue(), ^{
        NSAlert *alert = [[NSAlert alloc] init];
        alert.messageText = @"Bracket Order Ready for Submission";
        alert.informativeText = [NSString stringWithFormat:@"Bracket order with %ld orders for %@ validated and ready. Order submission API integration pending.", (long)bracketOrders.count, self.symbolField.stringValue];
        alert.alertStyle = NSAlertStyleInformational;
        [alert addButtonWithTitle:@"OK"];
        [alert runModal];
        
        // Log the bracket orders details for debugging
        NSLog(@"📝 Bracket Orders: %@", bracketOrders);
        
        [self resetForm:nil];
    });
}


- (IBAction)resetForm:(NSButton *)sender {
    // Reset all form fields to defaults
    self.symbolField.stringValue = @"";
    self.quantityField.stringValue = @"100";
    [self.orderTypePopup selectItemAtIndex:0]; // MARKET
    [self.sidePopup selectItemAtIndex:0]; // BUY
    [self.timeInForcePopup selectItemAtIndex:0]; // DAY
    
    self.limitPriceField.doubleValue = 0.0;
    self.stopPriceField.doubleValue = 0.0;
    
    self.profitTargetField.stringValue = @"10.0";
    self.stopLossField.stringValue = @"3.0";
    self.bracketOrdersEnabled = NO;
    self.enableBracketOrdersCheckbox.state = NSControlStateValueOff;
    
    // Reset calculated values
    self.calculatedShares = 0.0;
    self.calculatedPositionValue = 0.0;
    self.calculatedRiskAmount = 0.0;
    self.calculatedRewardAmount = 0.0;
    self.calculatedRiskRewardRatio = 0.0;
    
    // Clear market data
    [self clearMarketData];
    self.currentSymbol = nil;
    
    // Update UI
    [self updateUIForOrderType:@"MARKET"];
    [self updateBracketOrdersVisibility];
    [self recalculateAllValues];
}

#pragma mark - Preset Actions

- (IBAction)applyScalpPreset:(NSButton *)sender {
    self.bracketOrdersEnabled = YES;
    self.enableBracketOrdersCheckbox.state = NSControlStateValueOn;
    
    self.currentProfitTargetMode = ProfitTargetModePercent;
    self.currentStopLossMode = StopLossModePercent;
    
    self.profitTargetField.stringValue = @"1.0"; // 1% profit target
    self.stopLossField.stringValue = @"0.5"; // 0.5% stop loss
    
    [self updateBracketOrdersVisibility];
    [self recalculateAllValues];
}

- (IBAction)applySwingPreset:(NSButton *)sender {
    self.bracketOrdersEnabled = YES;
    self.enableBracketOrdersCheckbox.state = NSControlStateValueOn;
    
    self.currentProfitTargetMode = ProfitTargetModePercent;
    self.currentStopLossMode = StopLossModePercent;
    
    self.profitTargetField.stringValue = @"10.0"; // 10% profit target
    self.stopLossField.stringValue = @"3.0"; // 3% stop loss
    
    [self updateBracketOrdersVisibility];
    [self recalculateAllValues];
}

- (IBAction)applyBreakoutPreset:(NSButton *)sender {
    if (!self.currentQuote) {
        NSAlert *alert = [[NSAlert alloc] init];
        alert.messageText = @"Market Data Required";
        alert.informativeText = @"Please enter a symbol and wait for market data to load before using breakout preset.";
        alert.alertStyle = NSAlertStyleWarning;
        [alert addButtonWithTitle:@"OK"];
        [alert runModal];
        return;
    }
    
    // Use day range for breakout strategy
    double dayHigh = self.currentQuote.high ? self.currentQuote.high.doubleValue : 0.0;
    double dayLow = self.currentQuote.low ? self.currentQuote.low.doubleValue : 0.0;
    double currentPrice = self.currentQuote.last.doubleValue;
    
    if (dayHigh > 0 && dayLow > 0) {
        self.bracketOrdersEnabled = YES;
        self.enableBracketOrdersCheckbox.state = NSControlStateValueOn;
        
        // Set stop loss at day low minus small buffer
        double stopLossPercent = ((currentPrice - dayLow) / currentPrice) * 100.0 + 0.5;
        self.stopLossField.stringValue = [NSString stringWithFormat:@"%.1f", stopLossPercent];
        
        // Set profit target at 2x the risk
        self.profitTargetField.stringValue = [NSString stringWithFormat:@"%.1f", stopLossPercent * 2.0];
        
        self.currentProfitTargetMode = ProfitTargetModePercent;
        self.currentStopLossMode = StopLossModePercent;
        
        [self updateBracketOrdersVisibility];
        [self recalculateAllValues];
    }
}

- (IBAction)applyCustomPreset1:(NSButton *)sender {
    // User-customizable preset 1 - implement based on user preferences
    NSLog(@"Custom Preset 1 applied");
}

- (IBAction)applyCustomPreset2:(NSButton *)sender {
    // User-customizable preset 2 - implement based on user preferences
    NSLog(@"Custom Preset 2 applied");
}

#pragma mark - Order Preview

- (void)updateOrderPreview {
    NSMutableString *preview = [NSMutableString string];
    
    // Order summary
    [preview appendFormat:@"ORDER SUMMARY\n"];
    [preview appendFormat:@"═══════════════════════════════════════\n\n"];
    
    // Basic order info
    [preview appendFormat:@"Symbol: %@\n", self.symbolField.stringValue];
    [preview appendFormat:@"Side: %@\n", self.sidePopup.selectedItem.title];
    [preview appendFormat:@"Type: %@\n", self.orderTypePopup.selectedItem.title];
    [preview appendFormat:@"Quantity: %.0f shares\n", self.calculatedShares];
    [preview appendFormat:@"Time in Force: %@\n\n", self.timeInForcePopup.selectedItem.title];
    
    // Price info
    double effectivePrice = [self getEffectiveSharePrice];
    if (effectivePrice > 0) {
        [preview appendFormat:@"Estimated Price: $%.2f\n", effectivePrice];
        [preview appendFormat:@"Position Value: $%.2f\n\n", self.calculatedPositionValue];
    }
    
    // Bracket orders info
    if (self.bracketOrdersEnabled) {
        [preview appendFormat:@"BRACKET ORDERS\n"];
        [preview appendFormat:@"─────────────────────────────────────\n"];
        [preview appendFormat:@"%@\n", self.calculatedProfitPriceLabel.stringValue];
        [preview appendFormat:@"%@\n", self.calculatedStopPriceLabel.stringValue];
        [preview appendFormat:@"Risk Amount: $%.2f\n", self.calculatedRiskAmount];
        [preview appendFormat:@"Reward Amount: $%.2f\n", self.calculatedRewardAmount];
        [preview appendFormat:@"Risk/Reward Ratio: %.2f:1\n\n", self.calculatedRiskRewardRatio];
    }
    
    // Portfolio impact
    if (self.currentPortfolio) {
        [preview appendFormat:@"PORTFOLIO IMPACT\n"];
        [preview appendFormat:@"─────────────────────────────────────\n"];
        [preview appendFormat:@"Available Cash: $%.2f\n", self.currentPortfolio.cashBalance];
        [preview appendFormat:@"Buying Power: $%.2f\n", self.currentPortfolio.buyingPower];
        if (self.bracketOrdersEnabled && self.calculatedRiskAmount > 0) {
            double riskPercent = (self.calculatedRiskAmount / self.currentPortfolio.totalValue) * 100.0;
            [preview appendFormat:@"Portfolio Risk: %.2f%%\n", riskPercent];
        }
    }
    
    self.orderPreviewTextView.string = preview;
}

@end
