//
//  MultiChartWidget.h
//  TradingApp
//
//  Multi-symbol chart grid widget for displaying multiple symbols
//

#import "BaseWidget.h"
#import "MiniChart.h"

@interface MultiChartWidget : BaseWidget

// Configuration
@property (nonatomic, assign) MiniChartType chartType;
@property (nonatomic, assign) MiniChartTimeframe timeframe;
@property (nonatomic, assign) MiniChartScaleType scaleType;
@property (nonatomic, assign) NSInteger maxBars;
@property (nonatomic, assign) BOOL showVolume;
@property (nonatomic, assign) NSInteger columnsCount;  // Numero di colonne nella griglia

// Symbols management
@property (nonatomic, strong) NSArray<NSString *> *symbols;
@property (nonatomic, copy) NSString *symbolsString;  // Simboli separati da virgola

// UI Components
@property (nonatomic, strong, readonly) NSTextField *symbolsTextField;
@property (nonatomic, strong, readonly) NSPopUpButton *chartTypePopup;
@property (nonatomic, strong, readonly) NSPopUpButton *timeframePopup;
@property (nonatomic, strong, readonly) NSPopUpButton *scaleTypePopup;
@property (nonatomic, strong, readonly) NSTextField *maxBarsField;
@property (nonatomic, strong, readonly) NSButton *volumeCheckbox;
@property (nonatomic, strong, readonly) NSSegmentedControl *columnsControl;

// Mini charts container
@property (nonatomic, strong, readonly) NSScrollView *scrollView;
@property (nonatomic, strong, readonly) NSView *chartsContainer;
@property (nonatomic, strong, readonly) NSMutableArray<MiniChart *> *miniCharts;

// Actions
- (void)setSymbolsFromString:(NSString *)symbolsString;
- (void)addSymbol:(NSString *)symbol;
- (void)removeSymbol:(NSString *)symbol;
- (void)removeAllSymbols;

// Updates
- (void)refreshAllCharts;
- (void)refreshChartForSymbol:(NSString *)symbol;

// Layout
- (void)setColumnsCount:(NSInteger)count animated:(BOOL)animated;
- (void)optimizeLayoutForSize:(NSSize)size;

@end
