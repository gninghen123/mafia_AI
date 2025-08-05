//
//  ChartWidget.h
//  TradingApp
//
//  Chart widget with multiple coordinated panels
//

#import "BaseWidget.h"
#import "ObjectsPanel.h"

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

#pragma mark - UI Components (Programmatic - STRONG references)
@property (nonatomic, strong) NSTextField *symbolTextField;
@property (nonatomic, strong) NSSegmentedControl *timeframeSegmented;
@property (nonatomic, strong) NSTextField *barsCountTextField;
@property (nonatomic, strong) NSPopUpButton *templatePopup;
@property (nonatomic, strong) NSButton *preferencesButton;
@property (nonatomic, strong) NSSplitView *panelsSplitView;
@property (nonatomic, strong) NSSlider *panSlider;
@property (nonatomic, strong) NSButton *zoomOutButton;
@property (nonatomic, strong) NSButton *zoomInButton;
@property (nonatomic, strong) NSButton *zoomAllButton;
// Objects UI
@property (nonatomic, strong) NSButton *objectsPanelToggle;
@property (nonatomic, strong) ObjectsPanel *objectsPanel;
@property (nonatomic, strong) ChartObjectsManager *objectsManager;
@property (nonatomic, assign) BOOL isObjectsPanelVisible;

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
