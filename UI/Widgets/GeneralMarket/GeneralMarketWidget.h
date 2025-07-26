//
//  GeneralMarketWidget.h
//  TradingApp
//

#import <Cocoa/Cocoa.h>
#import "BaseWidget.h"

#import "MarketPerformer+CoreDataClass.h"

@interface GeneralMarketWidget : BaseWidget <NSOutlineViewDelegate, NSOutlineViewDataSource>

// UI Components
@property (nonatomic, strong) NSOutlineView *outlineView;
@property (nonatomic, strong) NSScrollView *scrollView;
@property (nonatomic, strong) NSButton *refreshButton;
@property (nonatomic, strong) NSProgressIndicator *progressIndicator;

// Data Structure - ora usa array di MarketPerformer da Core Data
@property (nonatomic, strong) NSMutableArray<NSMutableDictionary *> *marketLists;@property (nonatomic, assign) NSInteger pageSize;

// Public Methods
- (void)refreshData;
- (void)createWatchlistFromSelection;
- (void)createWatchlistFromList:(NSArray *)symbols;

@end
