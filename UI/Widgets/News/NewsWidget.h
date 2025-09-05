//
//  NewsWidget.h
//  TradingApp
//
//  Widget for displaying news and market sentiment
//  Uses DataHub for news data with runtime models
//

#import "BaseWidget.h"
#import "RuntimeModels.h"

NS_ASSUME_NONNULL_BEGIN

@interface NewsWidget : BaseWidget <NSTableViewDelegate, NSTableViewDataSource>

#pragma mark - UI Components

@property (nonatomic, strong) NSScrollView *scrollView;
@property (nonatomic, strong) NSTableView *tableView;
@property (nonatomic, strong) NSTextField *symbolField;
@property (nonatomic, strong) NSButton *refreshButton;
@property (nonatomic, strong) NSSegmentedControl *sourceControl;
@property (nonatomic, strong) NSTextField *statusLabel;

#pragma mark - Data

@property (nonatomic, strong) NSString *currentSymbol;
@property (nonatomic, strong) NSArray<NewsModel *> *news;
@property (nonatomic, assign) BOOL isLoading;
@property (nonatomic, assign) NSInteger selectedSource; // 0=All, 1=Google, 2=Yahoo, 3=SEC, 4=SeekingAlpha

#pragma mark - Configuration

@property (nonatomic, assign) NSInteger newsLimit;     // Default: 25
@property (nonatomic, assign) BOOL autoRefresh;        // Default: YES
@property (nonatomic, assign) NSTimeInterval refreshInterval; // Default: 300 seconds (5 minutes)

@end

NS_ASSUME_NONNULL_END
