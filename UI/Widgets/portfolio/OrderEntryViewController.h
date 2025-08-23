//
//  OrderEntryViewController.h
//  TradingApp
//
//  Advanced order entry system with bracket orders, risk management, and smart pricing
//

#import <Cocoa/Cocoa.h>
#import "TradingRuntimeModels.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, QuantityMode) {
    QuantityModeShares = 0,         // Direct shares count
    QuantityModePortfolioPercent,   // % of total portfolio value
    QuantityModeCashPercent,        // % of available cash
    QuantityModeDollarAmount,       // Dollar amount (calculate shares)
    QuantityModeRiskAmount          // Risk-based sizing
};

typedef NS_ENUM(NSInteger, ProfitTargetMode) {
    ProfitTargetModePrice = 0,      // Absolute price
    ProfitTargetModePercent,        // % change from entry
    ProfitTargetModeDollarAmount,   // Dollar profit amount
    ProfitTargetModeRRRatio         // Risk/reward ratio
};

typedef NS_ENUM(NSInteger, StopLossMode) {
    StopLossModePrice = 0,          // Absolute price
    StopLossModePercent,            // % change from entry
    StopLossModeDollarAmount,       // Dollar loss amount
    StopLossModeATR,                // ATR-based
    StopLossModeDayLow,             // Day low minus offset
    StopLossModeDayHigh             // Day high plus offset
};

@interface OrderEntryViewController : NSViewController

@property (nonatomic, strong, nullable) MarketQuoteModel *currentQuote;  // CAMBIARE da TradingQuoteModel


#pragma mark - Account Context
@property (nonatomic, strong, nullable) AccountModel *selectedAccount;

#pragma mark - Symbol & Market Data Section
@property (nonatomic, strong) IBOutlet NSTextField *symbolField;
@property (nonatomic, strong) IBOutlet NSButton *symbolLookupButton;

// Market data display
@property (nonatomic, strong) IBOutlet NSView *marketDataPanel;
@property (nonatomic, strong) IBOutlet NSTextField *lastPriceLabel;
@property (nonatomic, strong) IBOutlet NSTextField *bidLabel;
@property (nonatomic, strong) IBOutlet NSTextField *askLabel;
@property (nonatomic, strong) IBOutlet NSTextField *spreadLabel;
@property (nonatomic, strong) IBOutlet NSTextField *volumeLabel;
@property (nonatomic, strong) IBOutlet NSTextField *dayRangeLabel;
@property (nonatomic, strong) IBOutlet NSTextField *changeLabel;

#pragma mark - Order Type & Side
@property (nonatomic, strong) IBOutlet NSPopUpButton *orderTypePopup;   // MARKET/LIMIT/STOP/STOP_LIMIT
@property (nonatomic, strong) IBOutlet NSPopUpButton *sidePopup;        // BUY/SELL/SELL_SHORT
@property (nonatomic, strong) IBOutlet NSPopUpButton *timeInForcePopup; // DAY/GTC/IOC/FOK

#pragma mark - Advanced Quantity Section
@property (nonatomic, strong) IBOutlet NSSegmentedControl *quantityModeControl;
@property (nonatomic, strong) IBOutlet NSTextField *quantityField;
@property (nonatomic, strong) IBOutlet NSTextField *calculatedSharesLabel;
@property (nonatomic, strong) IBOutlet NSTextField *positionValueLabel;
@property (nonatomic, strong) IBOutlet NSTextField *portfolioPercentLabel;

#pragma mark - Price Entry Section
@property (nonatomic, strong) IBOutlet NSTextField *limitPriceField;
@property (nonatomic, strong) IBOutlet NSTextField *stopPriceField;

// Quick price buttons
@property (nonatomic, strong) IBOutlet NSButton *setBidPriceButton;     // Set to current bid
@property (nonatomic, strong) IBOutlet NSButton *setAskPriceButton;     // Set to current ask
@property (nonatomic, strong) IBOutlet NSButton *setLastPriceButton;    // Set to last price

#pragma mark - Bracket Orders Section
@property (nonatomic, strong) IBOutlet NSButton *enableBracketOrdersCheckbox;
@property (nonatomic, strong) IBOutlet NSView *bracketOrdersPanel;

// Profit target
@property (nonatomic, strong) IBOutlet NSSegmentedControl *profitTargetModeControl;
@property (nonatomic, strong) IBOutlet NSTextField *profitTargetField;
@property (nonatomic, strong) IBOutlet NSTextField *calculatedProfitPriceLabel;

// Stop loss
@property (nonatomic, strong) IBOutlet NSSegmentedControl *stopLossModeControl;
@property (nonatomic, strong) IBOutlet NSTextField *stopLossField;
@property (nonatomic, strong) IBOutlet NSTextField *calculatedStopPriceLabel;

#pragma mark - Risk Management Display
@property (nonatomic, strong) IBOutlet NSView *riskManagementPanel;
@property (nonatomic, strong) IBOutlet NSTextField *riskAmountLabel;        // $ at risk
@property (nonatomic, strong) IBOutlet NSTextField *rewardAmountLabel;      // $ potential reward
@property (nonatomic, strong) IBOutlet NSTextField *riskRewardRatioLabel;   // R:R ratio
@property (nonatomic, strong) IBOutlet NSTextField *portfolioRiskLabel;     // % of portfolio at risk
@property (nonatomic, strong) IBOutlet NSTextField *maxLossLabel;           // Maximum possible loss

#pragma mark - Quick Presets
@property (nonatomic, strong) IBOutlet NSView *presetsPanel;
@property (nonatomic, strong) IBOutlet NSButton *scalpPresetButton;         // "Quick Scalp: 0.5% SL, 1% TP"
@property (nonatomic, strong) IBOutlet NSButton *swingPresetButton;         // "Swing Trade: 3% SL, 10% TP"
@property (nonatomic, strong) IBOutlet NSButton *breakoutPresetButton;      // "Breakout: Day range based"
@property (nonatomic, strong) IBOutlet NSButton *customPreset1Button;       // User customizable
@property (nonatomic, strong) IBOutlet NSButton *customPreset2Button;       // User customizable

#pragma mark - Order Preview & Submission
@property (nonatomic, strong) IBOutlet NSTextView *orderPreviewTextView;    // Human-readable order summary
@property (nonatomic, strong) IBOutlet NSButton *validateOrderButton;       // Test validation without submitting
@property (nonatomic, strong) IBOutlet NSButton *submitOrderButton;         // Submit order
@property (nonatomic, strong) IBOutlet NSButton *resetFormButton;           // Reset to defaults


#pragma mark - Current Portfolio Data (for calculations)
@property (nonatomic, strong, nullable) PortfolioSummaryModel *currentPortfolio;

#pragma mark - Form State
@property (nonatomic, assign) QuantityMode currentQuantityMode;
@property (nonatomic, assign) ProfitTargetMode currentProfitTargetMode;
@property (nonatomic, assign) StopLossMode currentStopLossMode;
@property (nonatomic, assign) BOOL bracketOrdersEnabled;

// Calculated values
@property (nonatomic, assign) double calculatedShares;
@property (nonatomic, assign) double calculatedPositionValue;
@property (nonatomic, assign) double calculatedRiskAmount;
@property (nonatomic, assign) double calculatedRewardAmount;
@property (nonatomic, assign) double calculatedRiskRewardRatio;

#pragma mark - Market Data Management

/// Update market data for symbol
- (void)updateMarketDataForSymbol:(NSString *)symbol quote:(TradingQuoteModel *)quote;

/// Refresh current market data
- (void)refreshMarketData;

/// Clear market data display
- (void)clearMarketData;

#pragma mark - Form Actions

/// Symbol field changed - lookup new quote
- (IBAction)symbolFieldChanged:(NSTextField *)sender;

/// Quick symbol lookup button
- (IBAction)lookupSymbol:(NSButton *)sender;

/// Order type changed
- (IBAction)orderTypeChanged:(NSPopUpButton *)sender;

/// Side changed (BUY/SELL/SHORT)
- (IBAction)sideChanged:(NSPopUpButton *)sender;

/// Time in force changed
- (IBAction)timeInForceChanged:(NSPopUpButton *)sender;

#pragma mark - Quantity Calculation Actions

/// Quantity mode changed (shares/$/%)
- (IBAction)quantityModeChanged:(NSSegmentedControl *)sender;

/// Quantity field changed - recalculate
- (IBAction)quantityFieldChanged:(NSTextField *)sender;

#pragma mark - Price Actions

/// Limit/stop price fields changed
- (IBAction)limitPriceChanged:(NSTextField *)sender;
- (IBAction)stopPriceChanged:(NSTextField *)sender;

/// Quick price setting buttons
- (IBAction)setBidPrice:(NSButton *)sender;
- (IBAction)setAskPrice:(NSButton *)sender;
- (IBAction)setLastPrice:(NSButton *)sender;

#pragma mark - Bracket Orders Actions

/// Enable/disable bracket orders
- (IBAction)bracketOrdersToggled:(NSButton *)sender;

/// Bracket order settings changed
- (IBAction)profitTargetModeChanged:(NSSegmentedControl *)sender;
- (IBAction)profitTargetFieldChanged:(NSTextField *)sender;
- (IBAction)stopLossModeChanged:(NSSegmentedControl *)sender;
- (IBAction)stopLossFieldChanged:(NSTextField *)sender;

#pragma mark - Preset Actions

/// Apply quick trading presets
- (IBAction)applyScalpPreset:(NSButton *)sender;
- (IBAction)applySwingPreset:(NSButton *)sender;
- (IBAction)applyBreakoutPreset:(NSButton *)sender;
- (IBAction)applyCustomPreset1:(NSButton *)sender;
- (IBAction)applyCustomPreset2:(NSButton *)sender;

#pragma mark - Order Management Actions

/// Validate order without submitting
- (IBAction)validateOrder:(NSButton *)sender;

/// Submit order to broker
- (IBAction)submitOrder:(NSButton *)sender;

/// Reset form to defaults
- (IBAction)resetForm:(NSButton *)sender;

#pragma mark - Calculations

/// Recalculate all derived values
- (void)recalculateAllValues;

/// Calculate shares from quantity mode
- (void)recalculateShares;

/// Calculate position value
- (void)recalculatePositionValue;

/// Calculate bracket order prices
- (void)recalculateBracketPrices;

/// Calculate risk/reward metrics
- (void)recalculateRiskReward;

/// Update order preview text
- (void)updateOrderPreview;

#pragma mark - Validation

/// Validate current form state
- (BOOL)validateCurrentOrder:(NSError **)error;

/// Check if symbol is valid
- (BOOL)isSymbolValid:(NSString *)symbol;

/// Check if quantity is valid
- (BOOL)isQuantityValid:(double)quantity;

/// Check if prices are valid
- (BOOL)arePricesValid:(NSError **)error;

#pragma mark - Order Building

/// Build simple order dictionary
- (NSDictionary *)buildSimpleOrder;

/// Build bracket order array (parent + children)
- (NSArray<NSDictionary *> *)buildBracketOrder;

#pragma mark - UI State Management

/// Update UI state based on order type
- (void)updateUIForOrderType:(NSString *)orderType;

/// Update UI state based on side
- (void)updateUIForSide:(NSString *)side;

/// Show/hide bracket orders panel
- (void)updateBracketOrdersVisibility;

/// Update calculated values display
- (void)updateCalculatedValuesDisplay;

/// Update risk management display
- (void)updateRiskManagementDisplay;

@end

NS_ASSUME_NONNULL_END
