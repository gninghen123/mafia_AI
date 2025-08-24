//
//  IBKRTestWidget.h
//  TradingApp
//
//  Simple widget to test IBKR connection and basic functionality
//

#import "BaseWidget.h"
#import "IBKRConfiguration.h"

NS_ASSUME_NONNULL_BEGIN

@interface IBKRTestWidget : BaseWidget

#pragma mark - UI Components

/// Connection status display
@property (nonatomic, strong) NSTextField *statusLabel;

/// Configuration display
@property (nonatomic, strong) NSTextField *configLabel;

/// Connect/Disconnect button
@property (nonatomic, strong) NSButton *connectButton;

/// Test quote button
@property (nonatomic, strong) NSButton *testQuoteButton;

/// Test historical data button
@property (nonatomic, strong) NSButton *testHistoricalButton;

/// Test accounts button
@property (nonatomic, strong) NSButton *testAccountsButton;

/// Results text view
@property (nonatomic, strong) NSScrollView *resultsScrollView;
@property (nonatomic, strong) NSTextView *resultsTextView;

/// Configuration buttons
@property (nonatomic, strong) NSButton *twsPresetButton;
@property (nonatomic, strong) NSButton *gatewayPresetButton;

#pragma mark - Actions

- (void)connectButtonClicked:(id)sender;
- (void)testQuoteButtonClicked:(id)sender;
- (void)testHistoricalButtonClicked:(id)sender;
- (void)testAccountsButtonClicked:(id)sender;
- (void)twsPresetButtonClicked:(id)sender;
- (void)gatewayPresetButtonClicked:(id)sender;

#pragma mark - Helper Methods

- (void)updateUI;
- (void)appendResult:(NSString *)result;
- (void)clearResults;

@end

NS_ASSUME_NONNULL_END
