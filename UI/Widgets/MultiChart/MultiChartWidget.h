//
//  MultiChartWidget.h
//  TradingApp
//
//  Multi-symbol chart grid widget for displaying multiple symbols
//

#import "BaseWidget.h"
#import "MiniChart.h"



@interface MultiChartWidget : BaseWidget <NSCollectionViewDelegate, NSCollectionViewDataSource>


@property (nonatomic, strong) NSCollectionView *collectionView;
@property (nonatomic, strong) NSScrollView *collectionScrollView;

// Configuration
@property (nonatomic, assign) MiniChartType chartType;
@property (nonatomic, assign) MiniBarTimeframe timeframe;
@property (nonatomic, assign) MiniChartScaleType scaleType;
@property (nonatomic, assign) BOOL showVolume;


// Auto-refresh control
@property (nonatomic, strong) NSButton *autoRefreshToggle;  // Switch toggle
@property (nonatomic, assign) BOOL autoRefreshEnabled;     // State (default: NO)

// Symbols management
@property (nonatomic, strong) NSArray<NSString *> *symbols;
@property (nonatomic, copy) NSString *symbolsString;  // Simboli separati da virgola


@property (nonatomic, strong) NSButton *resetSymbolsButton;      // NUOVO: Pulsante reset simboli
@property (nonatomic, strong) NSTextField *itemWidthField;
@property (nonatomic, strong) NSTextField *itemHeightField;
@property (nonatomic, assign) CGFloat itemWidth;    // ← CGFloat invece di NSInteger
@property (nonatomic, assign) CGFloat itemHeight;   // ← Fix typo + CGFloat

// UI Components - REMOVED readonly to allow internal assignment
@property (nonatomic, strong) NSTextField *symbolsTextField;
@property (nonatomic, strong) NSPopUpButton *chartTypePopup;
@property (nonatomic, strong) NSPopUpButton *scaleTypePopup;
@property (nonatomic, strong) NSButton *volumeCheckbox;
@property (nonatomic, strong) NSSegmentedControl *timeframeSegmented;
@property (nonatomic, strong) NSButton *afterHoursSwitch;
@property (nonatomic, assign) NSInteger timeRange;  // 0=1d, 1=3d, 2=5d, 3=1m, 4=3m, 5=6m, 6=1y, 7=5y
@property (nonatomic, strong) NSSegmentedControl *timeRangeSegmented;

// Mini charts container - REMOVED readonly to allow internal assignment
@property (nonatomic, strong) NSMutableArray<MiniChart *> *miniCharts;

// Actions
- (void)setSymbolsFromString:(NSString *)symbolsString;
- (void)addSymbol:(NSString *)symbol;
- (void)removeSymbol:(NSString *)symbol;
- (void)removeAllSymbols;

// Updates
- (void)refreshAllCharts;
- (void)refreshChartForSymbol:(NSString *)symbol;
- (void)resetSymbolsField;                              // NUOVO: Reset simboli dal textfield

// Layout
- (void)setColumnsCount:(NSInteger)count animated:(BOOL)animated;
- (void)showTemporaryMessageForCollectionView:(NSString *)message;

@end
