//
//  IBKRTestWidget.h
//  TradingApp
//

#import "BaseWidget.h"
#import "IBKRConfiguration.h"

NS_ASSUME_NONNULL_BEGIN

@interface IBKRTestWidget : BaseWidget

@property (nonatomic, strong) NSTextField *statusLabel;
@property (nonatomic, strong) NSTextField *configLabel;
@property (nonatomic, strong) NSButton *connectButton;
@property (nonatomic, strong) NSButton *testQuoteButton;
@property (nonatomic, strong) NSButton *testHistoricalButton;
@property (nonatomic, strong) NSButton *testAccountsButton;
@property (nonatomic, strong) NSButton *testAllSourcesButton;
@property (nonatomic, strong) NSScrollView *resultsScrollView;
@property (nonatomic, strong) NSTextView *resultsTextView;
@property (nonatomic, strong) NSButton *twsPresetButton;
@property (nonatomic, strong) NSButton *gatewayPresetButton;
@property (nonatomic, strong) IBKRConfiguration *config;

- (void)connectButtonClicked:(id)sender;
- (void)testQuoteButtonClicked:(id)sender;
- (void)testHistoricalButtonClicked:(id)sender;
- (void)testAccountsButtonClicked:(id)sender;
- (void)testAllSourcesButtonClicked:(id)sender;
- (void)twsPresetButtonClicked:(id)sender;
- (void)gatewayPresetButtonClicked:(id)sender;

// Direct IBKR testing methods
- (void)testDirectIBKRQuote:(NSString *)symbol;
- (void)testDirectIBKRHistorical:(NSString *)symbol;
- (void)testDirectIBKRAccounts;
- (IBKRDataSource *)getIBKRDataSource;

- (void)updateUI;
- (void)appendResult:(NSString *)result;
- (void)clearResults;

@end

NS_ASSUME_NONNULL_END
