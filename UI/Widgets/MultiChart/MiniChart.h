//
//  MiniChart.h
//  TradingApp
//
//  Lightweight chart view for grid display
//

#import <Cocoa/Cocoa.h>

typedef NS_ENUM(NSInteger, MiniChartType) {
    MiniChartTypeLine,
    MiniChartTypeCandle,
    MiniChartTypeBar
};

typedef NS_ENUM(NSInteger, MiniChartTimeframe) {
    MiniChartTimeframe1Min,
    MiniChartTimeframe5Min,
    MiniChartTimeframe15Min,
    MiniChartTimeframe1Hour,
    MiniChartTimeframe4Hour,
    MiniChartTimeframeDaily,
    MiniChartTimeframeWeekly
};

typedef NS_ENUM(NSInteger, MiniChartScaleType) {
    MiniChartScaleLinear,     // Scala normale
    MiniChartScaleLog,        // Scala logaritmica
    MiniChartScalePercent     // Scala percentuale (da primo valore)
};

@interface MiniChart : NSView

// Data
@property (nonatomic, strong) NSString *symbol;
@property (nonatomic, assign) MiniChartType chartType;
@property (nonatomic, assign) MiniChartTimeframe timeframe;
@property (nonatomic, assign) MiniChartScaleType scaleType;
@property (nonatomic, strong) NSArray *priceData;  // Array di HistoricalBar
@property (nonatomic, assign) NSInteger maxBars;  // Numero massimo di barre da visualizzare
@property (nonatomic, assign) BOOL showVolume;    // Mostra volumi sovrapposti

// Display info
@property (nonatomic, strong) NSNumber *currentPrice;
@property (nonatomic, strong) NSNumber *priceChange;
@property (nonatomic, strong) NSNumber *percentChange;

// Appearance
@property (nonatomic, strong) NSColor *positiveColor;
@property (nonatomic, strong) NSColor *negativeColor;
@property (nonatomic, strong) NSColor *backgroundColor;
@property (nonatomic, strong) NSColor *textColor;

// State
@property (nonatomic, assign) BOOL isLoading;
@property (nonatomic, assign) BOOL hasError;
@property (nonatomic, strong) NSString *errorMessage;

// Initialization
+ (instancetype)miniChartWithSymbol:(NSString *)symbol
                          chartType:(MiniChartType)chartType
                          timeframe:(MiniChartTimeframe)timeframe
                          scaleType:(MiniChartScaleType)scaleType
                            maxBars:(NSInteger)maxBars
                         showVolume:(BOOL)showVolume;

// Data management
- (void)updateWithPriceData:(NSArray *)priceData;
- (void)setLoading:(BOOL)loading;
- (void)setError:(NSString *)errorMessage;
- (void)clearError;

// Actions
- (void)refresh;

@end
