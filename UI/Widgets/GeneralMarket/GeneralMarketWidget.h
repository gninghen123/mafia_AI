//
//  GeneralMarketWidget.h
//  TradingApp
//
//  Widget per visualizzare liste di mercato usando i modelli standard
//

#import <Cocoa/Cocoa.h>
#import "BaseWidget.h"
#import "StandardModels.h"

@interface GeneralMarketWidget : BaseWidget <NSOutlineViewDelegate, NSOutlineViewDataSource>

// UI Components
@property (nonatomic, strong) NSOutlineView *outlineView;
@property (nonatomic, strong) NSScrollView *scrollView;
@property (nonatomic, strong) NSButton *refreshButton;
@property (nonatomic, strong) NSProgressIndicator *progressIndicator;

// Data Structure - ora usa i modelli standard
@property (nonatomic, strong) NSMutableArray<MarketList *> *marketLists;
@property (nonatomic, strong) NSMutableDictionary<NSString *, MarketQuote *> *quotesCache;

// Public Methods
- (void)refreshData;
- (void)createWatchlistFromSelection;
- (void)createWatchlistFromList:(NSArray *)symbols;

@end
