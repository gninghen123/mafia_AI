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

// Block-based data source as an alternative to protocol
typedef NSInteger (^CHChartWidgetSeriesCountBlock)(void);
typedef NSInteger (^CHChartWidgetPointCountBlock)(NSInteger series);
typedef CGFloat (^CHChartWidgetValueBlock)(NSInteger series, NSInteger index);
typedef NSString* (^CHChartWidgetLabelBlock)(NSInteger series);
typedef NSColor* (^CHChartWidgetColorBlock)(NSInteger series);

@interface CHChartWidget : BaseWidget

#pragma mark - Initialization

// FIX: Aggiunte dichiarazioni per i metodi di inizializzazione
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

#pragma mark - Appearance Customization

// Quick theme application
- (void)applyTheme:(NSString *)themeName; // "dark", "light", "minimal", etc.

// Color customization
- (void)setSeriesColors:(NSArray<NSColor *> *)colors;
- (void)addSeriesWithColor:(NSColor *)color;

// Line chart specific (only active when chartType is CHChartTypeLine)
- (void)setLineStyle:(CHLineChartStyle)style;
- (void)setShowDataPoints:(BOOL)show;
- (void)setFillArea:(BOOL)fill;
- (void)setSmoothLines:(BOOL)smooth;

// Bar chart specific (only active when chartType is CHChartTypeBar)
- (void)setBarStyle:(CHBarChartStyle)style;
- (void)setBarWidth:(CGFloat)width;
- (void)setGrouped:(BOOL)grouped;

#pragma mark - Real-time Data

// For live data feeds
- (void)enableRealTimeMode;
- (void)disableRealTimeMode;
- (void)addDataPoint:(CGFloat)value;
- (void)addDataPoint:(CGFloat)value toSeries:(NSInteger)series;
- (void)setMaxDataPoints:(NSInteger)maxPoints;

#pragma mark - Export

// Export chart as image
- (NSImage *)chartImage;
- (NSData *)chartImageDataWithType:(NSBitmapImageFileType)fileType;
- (BOOL)exportChartToFile:(NSString *)filePath withType:(NSBitmapImageFileType)fileType;

#pragma mark - Labels and Titles

// Chart labeling
- (void)setTitle:(NSString *)title;
- (void)setXAxisLabel:(NSString *)label;
- (void)setYAxisLabel:(NSString *)label;

@end
