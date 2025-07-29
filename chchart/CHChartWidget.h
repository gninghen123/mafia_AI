//
//  CHChartWidget.h
//  ChartWidget
//
//  Chart widget that inherits from BaseWidget
//  This is the primary interface for using charts in your application
//

#import "BaseWidget.h"
#import "CHChartConfiguration.h"
#import "CHChartDataSource.h"
#import "CHChartDelegate.h"

// Forward declarations for chart-specific types
typedef NS_ENUM(NSInteger, CHLineChartStyle);
typedef NS_ENUM(NSInteger, CHBarChartStyle);

// Forward declarations for data types
typedef NS_ENUM(NSInteger, BarTimeframe);

@class CHDataPoint;
@class CHChartData;
@class HistoricalBar;

// Block-based data source as an alternative to protocol
typedef NSInteger (^CHChartWidgetSeriesCountBlock)(void);
typedef NSInteger (^CHChartWidgetPointCountBlock)(NSInteger series);
typedef CGFloat (^CHChartWidgetValueBlock)(NSInteger series, NSInteger index);
typedef NSString* (^CHChartWidgetLabelBlock)(NSInteger series);
typedef NSColor* (^CHChartWidgetColorBlock)(NSInteger series);

@interface CHChartWidget : BaseWidget

#pragma mark - Initialization

// Metodi di inizializzazione
- (instancetype)initWithFrame:(NSRect)frame;
- (instancetype)initWithCoder:(NSCoder *)coder;

#pragma mark - Configuration

// Chart type and appearance
@property (nonatomic) CHChartType chartType;
@property (nonatomic, strong) CHChartConfiguration *configuration;

// Data source (choose one approach)
@property (nonatomic, weak) id<CHChartDataSource> dataSource;
@property (nonatomic, weak) id<CHChartDelegate> delegate;

// Direct data setting (alternative to data source)
@property (nonatomic, strong) CHChartData *chartData;

#pragma mark - Quick Setup Methods

// Create with frame and type
+ (instancetype)chartWidgetWithFrame:(NSRect)frame type:(CHChartType)type;

// Create with common configurations
+ (instancetype)lineChartWithFrame:(NSRect)frame;
+ (instancetype)barChartWithFrame:(NSRect)frame;
+ (instancetype)histogramWithFrame:(NSRect)frame;
+ (instancetype)scatterPlotWithFrame:(NSRect)frame;

#pragma mark - Data Management

// Simple data setting
- (void)setDataPoints:(NSArray<NSNumber *> *)values;
- (void)setDataPoints:(NSArray<NSNumber *> *)xValues yValues:(NSArray<NSNumber *> *)yValues;
- (void)setMultipleSeries:(NSArray<NSArray<NSNumber *> *> *)seriesData;
- (void)setMultipleSeries:(NSArray<NSArray<NSNumber *> *> *)seriesData
              seriesNames:(NSArray<NSString *> *)names;

// Block-based data source (alternative to protocol)
- (void)setDataSourceWithSeriesCount:(CHChartWidgetSeriesCountBlock)seriesCount
                          pointCount:(CHChartWidgetPointCountBlock)pointCount
                         valueGetter:(CHChartWidgetValueBlock)valueGetter;

// Refresh data
- (void)reloadData;
- (void)reloadDataAnimated:(BOOL)animated;

#pragma mark - Market Data Integration

// FIX: Aggiunte dichiarazioni per i metodi mancanti
- (void)loadChartData;
- (void)updateAvailableSymbols:(NSArray<NSString *> *)symbols;
- (void)changeTimeframe:(BarTimeframe)timeframe;

// Symbol and timeframe management
- (void)setCurrentSymbol:(NSString *)symbol;
- (void)setCurrentTimeframe:(BarTimeframe)timeframe;

// Historical data handling
- (void)loadHistoricalDataForCurrentSymbol;
- (void)displayHistoricalData:(NSArray<HistoricalBar *> *)bars;

#pragma mark - UI State Management

// Loading and error states
- (void)showLoadingState;
- (void)hideLoadingState;
- (void)showErrorState:(NSError *)error;

#pragma mark - Appearance Customization

// Quick theme application
- (void)applyTheme:(NSString *)themeName; // "dark", "light", "minimal", etc.

// Colors and styling
- (void)setSeriesColors:(NSArray<NSColor *> *)colors;
- (void)setLineWidth:(CGFloat)width;
- (void)setMarkerSize:(CGFloat)size;

#pragma mark - Chart-specific Styling

// Line chart specific
- (void)setLineStyle:(CHLineChartStyle)style forSeries:(NSInteger)series;
- (void)setLineDashPattern:(NSArray<NSNumber *> *)pattern forSeries:(NSInteger)series;

// Bar chart specific
- (void)setBarStyle:(CHBarChartStyle)style;
- (void)setBarWidth:(CGFloat)width;

#pragma mark - Selection and Interaction

// Selection handling
@property (nonatomic, readonly) NSInteger selectedSeriesIndex;
@property (nonatomic, readonly) NSInteger selectedPointIndex;
@property (nonatomic, readonly) CHDataPoint *selectedPoint;

// Interaction
- (void)selectPointAtIndex:(NSInteger)pointIndex inSeries:(NSInteger)seriesIndex;
- (void)clearSelection;
- (void)zoomToFitData;
- (void)resetZoom;

#pragma mark - Real-time Data

// Real-time updates
- (void)enableRealTimeMode;
- (void)disableRealTimeMode;
- (void)addDataPoint:(CGFloat)value;
- (void)addDataPoint:(CGFloat)value toSeries:(NSInteger)series;

// Real-time data management
@property (nonatomic) NSInteger maxDataPoints;

#pragma mark - Labels and Titles

// Chart labels
@property (nonatomic, strong) NSString *chartTitle;
@property (nonatomic, strong) NSString *xAxisTitle;
@property (nonatomic, strong) NSString *yAxisTitle;

#pragma mark - Export

// Export functionality
- (NSImage *)chartImage;
- (NSData *)chartImageDataWithType:(NSBitmapImageFileType)fileType;
- (BOOL)exportChartToFile:(NSString *)filePath withType:(NSBitmapImageFileType)fileType;

@end

// Notifications
extern NSString * const CHChartWidgetSelectionDidChangeNotification;
extern NSString * const CHChartWidgetDataDidReloadNotification;
extern NSString * const CHChartWidgetAnimationDidCompleteNotification;
