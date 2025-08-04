//
//  ChartWidget.h
//  TradingApp
//
//  Chart widget with multiple coordinated panels
//

#import "BaseWidget.h"

@class ChartPanelView;

typedef NS_ENUM(NSInteger, ChartTimeframe) {
    ChartTimeframe1Min,
    ChartTimeframe5Min,
    ChartTimeframe15Min,
    ChartTimeframe30Min,
    ChartTimeframe1Hour,
    ChartTimeframe4Hour,
    ChartTimeframeDaily,
    ChartTimeframeWeekly,
    ChartTimeframeMonthly
};

@interface ChartWidget : BaseWidget

#pragma mark - UI Components (da XIB)
@property (nonatomic, weak) IBOutlet NSTextField *symbolTextField;
@property (nonatomic, weak) IBOutlet NSSegmentedControl *timeframeSegmented;
@property (nonatomic, weak) IBOutlet NSTextField *barsCountTextField;
@property (nonatomic, weak) IBOutlet NSPopUpButton *templatePopup;
@property (nonatomic, weak) IBOutlet NSButton *preferencesButton;
@property (nonatomic, weak) IBOutlet NSSplitView *panelsSplitView;
@property (nonatomic, weak) IBOutlet NSSlider *panSlider;
@property (nonatomic, weak) IBOutlet NSButton *zoomOutButton;
@property (nonatomic, weak) IBOutlet NSButton *zoomInButton;
@property (nonatomic, weak) IBOutlet NSButton *zoomAllButton;

#pragma mark - Data Properties
@property (nonatomic, strong, readwrite) NSString *currentSymbol;
@property (nonatomic, assign, readwrite) ChartTimeframe currentTimeframe;
@property (nonatomic, assign, readwrite) NSInteger barsToDownload;
@property (nonatomic, assign, readwrite) NSInteger initialBarsToShow;

#pragma mark - Chart Panels
@property (nonatomic, strong, readwrite) NSMutableArray<ChartPanelView *> *chartPanels;

#pragma mark - Viewport State (for ChartPanelView access)
@property (nonatomic, assign, readwrite) NSInteger visibleStartIndex;
@property (nonatomic, assign, readwrite) NSInteger visibleEndIndex;
@property (nonatomic, assign) double yRangeMin;
@property (nonatomic, assign) double yRangeMax;
@property (nonatomic, assign) BOOL isYRangeOverridden;

#pragma mark - Public Methods
- (void)loadSymbol:(NSString *)symbol;
- (void)setTimeframe:(ChartTimeframe)timeframe;
- (void)zoomToRange:(NSInteger)startIndex endIndex:(NSInteger)endIndex;
- (void)synchronizePanels;

// Zoom methods for panels
- (void)zoomIn:(id)sender;
- (void)zoomOut:(id)sender;
- (void)zoomAll:(id)sender;

@end
