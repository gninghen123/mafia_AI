//
//  QuoteWidget.h
//  TradingApp
//
//  Widget for displaying stock quotes - ON DEMAND LOADING ONLY
//

#import "BaseWidget.h"
#import "DataManager.h"

@interface QuoteWidget : BaseWidget <DataManagerDelegate>

@property (nonatomic, strong) NSString *symbol;

// UI Elements
@property (nonatomic, strong, readonly) NSTextField *symbolLabel;
@property (nonatomic, strong, readonly) NSTextField *priceLabel;
@property (nonatomic, strong, readonly) NSTextField *changeLabel;
@property (nonatomic, strong, readonly) NSTextField *volumeLabel;
@property (nonatomic, strong, readonly) NSTextField *bidAskLabel;
@property (nonatomic, strong, readonly) NSButton *refreshButton;

// Data loading - ON DEMAND ONLY
- (void)setSymbol:(NSString *)symbol;
- (void)refreshQuote;
- (void)loadQuoteData;

@end
