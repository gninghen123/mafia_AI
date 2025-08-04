//
//  ChartWidget.h
//  TradingApp
//
//  Main chart widget with multi-panel indicator support
//  Clean architecture with separate files
//

#import "BaseWidget.h"
#import "ChartTypes.h"
#import "ChartPanelModel.h"
#import "ChartPanelView.h"
#import "ChartCoordinator.h"
#import "RuntimeModels.h"
#import "IndicatorRenderer.h"
#import "IndicatorsPanelController.h"


NS_ASSUME_NONNULL_BEGIN

@class IndicatorsPanelController;

@interface ChartWidget : BaseWidget <NSSplitViewDelegate>

#pragma mark - Core Properties
@property (nonatomic, strong) NSString *currentSymbol;
@property (nonatomic, strong, nullable) NSArray<HistoricalBarModel *> *historicalData;
@property (nonatomic, strong) ChartCoordinator *coordinator;

#pragma mark - Panels Management
@property (nonatomic, strong) NSMutableArray<ChartPanelModel *> *panelModels;
@property (nonatomic, strong) NSMutableArray<ChartPanelView *> *panelViews;
@property (nonatomic, strong) IndicatorsPanelController *indicatorsPanelController;

#pragma mark - UI Components
// Top toolbar
@property (nonatomic, strong) NSView *toolbarView;
@property (nonatomic, strong) NSComboBox *symbolComboBox;
@property (nonatomic, strong) NSSegmentedControl *timeframeControl;
@property (nonatomic, strong) NSButton *refreshButton;
@property (nonatomic, strong) NSButton *indicatorsButton;
@property (nonatomic, strong) NSProgressIndicator *loadingIndicator;

// Main chart area
@property (nonatomic, strong) NSScrollView *chartScrollView;
@property (nonatomic, strong) NSSplitView *panelsSplitView;

#pragma mark - Settings
@property (nonatomic, assign) NSInteger selectedTimeframe; // 0=1m, 1=5m, 2=15m, 3=1h, 4=1d, 5=1w
@property (nonatomic, assign) NSInteger maxBarsToDisplay;

#pragma mark - Data Management
- (void)loadHistoricalDataForSymbol:(NSString *)symbol;
- (void)refreshCurrentData;
- (void)updateAllPanelsWithData:(NSArray<HistoricalBarModel *> *)data;

#pragma mark - Panel Management
- (void)addPanelWithModel:(ChartPanelModel *)panelModel;
- (void)removePanelWithModel:(ChartPanelModel *)panelModel;
- (void)requestDeletePanel:(ChartPanelModel *)panelModel;
- (ChartPanelModel *)createMainSecurityPanel;

#pragma mark - UI Updates
- (void)refreshAllPanels;
- (void)updateToolbarState;

#pragma mark - Factory Methods for Indicators
- (id<IndicatorRenderer>)createIndicatorOfType:(NSString *)indicatorType;

#pragma mark - Utility Methods
- (BarTimeframe)timeframeEnumForIndex:(NSInteger)index;
- (NSDate *)startDateForTimeframe;

#pragma mark - Actions
- (IBAction)symbolChanged:(id)sender;
- (IBAction)timeframeChanged:(id)sender;
- (IBAction)refreshButtonClicked:(id)sender;
- (IBAction)indicatorsButtonClicked:(id)sender;
- (void)checkIndicatorsPanelStatus;

#pragma mark - Zoom Controls
@property (nonatomic, strong) NSView *zoomControlsView;
@property (nonatomic, strong) NSSlider *zoomSlider;
@property (nonatomic, strong) NSButton *zoomOutButton;
@property (nonatomic, strong) NSButton *zoomInButton;
@property (nonatomic, strong) NSButton *zoomAllButton;

@end

NS_ASSUME_NONNULL_END
