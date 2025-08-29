//
//  MultiChartWidget.h
//  TradingApp
//
//  Multi-symbol chart grid widget for displaying multiple symbols
//

#import "BaseWidget.h"
#import "MiniChart.h"

@interface MultiChartWidget : BaseWidget


@property (nonatomic, strong) NSCollectionView *collectionView;
@property (nonatomic, strong) NSScrollView *collectionScrollView;

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


@property (nonatomic, strong) NSButton *resetSymbolsButton;      // NUOVO: Pulsante reset simboli
@property (nonatomic, strong) NSTextField *itemWidthField;
@property (nonatomic, strong) NSTextField *itemHeightField;
@property (nonatomic, assign) NSInteger itemWidth;
@property (nonatomic, assign) NSInteger itemHeigth;          

// UI Components - REMOVED readonly to allow internal assignment
@property (nonatomic, strong) NSTextField *symbolsTextField;
@property (nonatomic, strong) NSPopUpButton *chartTypePopup;
@property (nonatomic, strong) NSPopUpButton *timeframePopup;
@property (nonatomic, strong) NSPopUpButton *scaleTypePopup;
@property (nonatomic, strong) NSTextField *maxBarsField;
@property (nonatomic, strong) NSButton *volumeCheckbox;

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
