//
//  QuoteWidget.h
//  TradingApp
//
//  Widget for displaying real-time quotes
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

// Subscribe to a new symbol
- (void)setSymbol:(NSString *)symbol;

@end
