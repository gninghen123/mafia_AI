//
//  GeneralMarketWidget.h
//  TradingApp
//

#import <Cocoa/Cocoa.h>
#import "BaseWidget.h"

@interface GeneralMarketWidget : BaseWidget <NSOutlineViewDelegate, NSOutlineViewDataSource>

// UI Components
@property (nonatomic, strong) NSOutlineView *outlineView;
@property (nonatomic, strong) NSScrollView *scrollView;
@property (nonatomic, strong) NSButton *refreshButton;
@property (nonatomic, strong) NSProgressIndicator *progressIndicator;

// Data Structure
@property (nonatomic, strong) NSMutableArray *dataSource;
@property (nonatomic, assign) NSInteger pageSize;

// Public Methods
- (void)refreshData;
- (void)createWatchlistFromSelection;
- (void)createWatchlistFromList:(NSArray *)symbols;

@end

// Node structure for OutlineView
@interface MarketDataNode : NSObject

@property (nonatomic, strong) NSString *title;
@property (nonatomic, strong) NSString *symbol;
@property (nonatomic, strong) NSNumber *changePercent;
@property (nonatomic, strong) NSColor *changeColor;
@property (nonatomic, strong) NSMutableArray *children;
@property (nonatomic, assign) BOOL isExpandable;
@property (nonatomic, strong) NSString *nodeType; // "category", "rankType", "symbol"
@property (nonatomic, strong) NSDictionary *rawData;

@end
