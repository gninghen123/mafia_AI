//
//  MiniChart.h
//  TradingApp
//
//  Lightweight chart view for grid display
//  UPDATED: Uses RuntimeModels instead of Core Data
//

#import <Cocoa/Cocoa.h>
#import "RuntimeModels.h"

// Forward declaration
@class HistoricalBarModel;

typedef NS_ENUM(NSInteger, MiniChartType) {
    MiniChartTypeLine,
    MiniChartTypeCandle,
    MiniChartTypeBar
};

typedef NS_ENUM(NSInteger, MiniBarTimeframe) {
    MiniBarTimeframe1Min,
    MiniBarTimeframe5Min,
    MiniBarTimeframe15Min,
    MiniBarTimeframe30Min,
    MiniBarTimeframe1Hour,
    MiniBarTimeframe12Hour,
    MiniBarTimeframeDaily,
    MiniBarTimeframeWeekly,
    MiniBarTimeframeMonthly
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
@property (nonatomic, assign) MiniBarTimeframe timeframe;
@property (nonatomic, assign) MiniChartScaleType scaleType;
@property (nonatomic, strong) NSArray<HistoricalBarModel *> *priceData;  // UPDATED: Array di RuntimeModels
@property (nonatomic, assign) NSInteger maxBars;  // Numero massimo di barre da visualizzare
@property (nonatomic, assign) BOOL showVolume;    // Mostra volumi sovrapposti

// Display info
@property (nonatomic, strong) NSNumber *currentPrice;
@property (nonatomic, strong) NSNumber *priceChange;
@property (nonatomic, strong) NSNumber *percentChange;
@property (nonatomic, strong) NSNumber *aptrValue;     // NUOVO: APTR calcolato


// Appearance
@property (nonatomic, strong) NSColor *positiveColor;
@property (nonatomic, strong) NSColor *negativeColor;
@property (nonatomic, strong) NSColor *backgroundColor;
@property (nonatomic, strong) NSColor *textColor;

// State
@property (nonatomic, assign) BOOL isLoading;
@property (nonatomic, assign) BOOL hasError;
@property (nonatomic, strong) NSString *errorMessage;

// UI Components (read-only access)
@property (nonatomic, strong, readonly) NSTextField *symbolLabel;
@property (nonatomic, strong, readonly) NSTextField *descriptionLabel;
@property (nonatomic, strong, readonly) NSTextField *priceLabel;
@property (nonatomic, strong, readonly) NSTextField *changeLabel;
@property (nonatomic, strong, readonly) NSTextField *aptrLabel;        // NUOVO: Label per APTR
@property (nonatomic, strong, readonly) NSView *chartArea;
@property (nonatomic, strong, readonly) NSView *volumeArea;
@property (nonatomic, strong, readonly) NSProgressIndicator *loadingIndicator;

// Initialization
+ (instancetype)miniChartWithSymbol:(NSString *)symbol
                          chartType:(MiniChartType)chartType
                          timeframe:(MiniBarTimeframe)timeframe
                          scaleType:(MiniChartScaleType)scaleType
                            maxBars:(NSInteger)maxBars
                         showVolume:(BOOL)showVolume;

// Data management - UPDATED for RuntimeModels
- (void)updateWithHistoricalBars:(NSArray<HistoricalBarModel *> *)bars;

// DEPRECATED: Remove old method
// - (void)updateWithPriceData:(NSArray *)priceData;

- (void)calculateAPTR;                                                    // NUOVO: Calcola APTR dalle price data
- (double)calculateAPTRFromBars:(NSArray<HistoricalBarModel *> *)bars;  

// UI State
- (void)setLoading:(BOOL)loading;
- (void)setError:(NSString *)errorMessage;
- (void)clearError;

// Actions
- (void)refresh;

@end
