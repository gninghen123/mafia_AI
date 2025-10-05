//
// ComparisonChartWidget.h
// TradingApp
//
// Multi-symbol comparison chart with normalized percentage display
//

#import "BaseWidget.h"
#import "RuntimeModels.h"

NS_ASSUME_NONNULL_BEGIN

// Range selector options for historical data
typedef NS_ENUM(NSInteger, ComparisonRange) {
    ComparisonRange3Months,
    ComparisonRange6Months,
    ComparisonRange1Year,
    ComparisonRange5Years,
    ComparisonRangeMax
};

// Data point for normalized comparison
@interface ComparisonDataPoint : NSObject
@property (nonatomic, strong) NSDate *date;
@property (nonatomic, assign) double percentChange;  // % change from baseline
@end

@interface ComparisonChartWidget : BaseWidget

#pragma mark - Data Properties
@property (nonatomic, strong) NSMutableArray<NSString *> *symbols;  // Symbols to compare
@property (nonatomic, assign) BarTimeframe currentTimeframe;
@property (nonatomic, assign) ComparisonRange currentRange;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSArray<HistoricalBarModel *> *> *symbolsData;  // Raw data cache

#pragma mark - UI Components
@property (nonatomic, strong) NSComboBox *symbolsInputCombo;
@property (nonatomic, strong) NSPopUpButton *timeframeSelector;
@property (nonatomic, strong) NSSegmentedControl *rangeSelector;
@property (nonatomic, strong) NSButton *refreshButton;
@property (nonatomic, strong) NSView *chartCanvasView;
@property (nonatomic, strong) NSTextField *statusLabel;

#pragma mark - Rendering
@property (nonatomic, strong) CALayer *chartLayer;
@property (nonatomic, strong) CALayer *gridLayer;
@property (nonatomic, strong) CALayer *legendLayer;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSColor *> *symbolColors;

#pragma mark - State
@property (nonatomic, assign) BOOL isLoading;
@property (nonatomic, strong, nullable) NSDate *commonStartDate;  // Computed common baseline date

#pragma mark - Public Methods
- (void)addSymbol:(NSString *)symbol;
- (void)removeSymbol:(NSString *)symbol;
- (void)setSymbols:(NSArray<NSString *> *)symbols;
- (void)refreshData;
- (void)updateChart;

@end

NS_ASSUME_NONNULL_END
