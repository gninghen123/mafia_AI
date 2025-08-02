//
//  SeasonalChartWidget.h
//  TradingApp
//
//  Seasonal quarterly chart widget for YoY analysis
//

#import "BaseWidget.h"

@class SeasonalDataModel;
@class QuarterlyDataPoint;

NS_ASSUME_NONNULL_BEGIN

@interface SeasonalChartWidget : BaseWidget

#pragma mark - UI Components

// Header controls
@property (nonatomic, strong) NSTextField *symbolTextField;
@property (nonatomic, strong) NSComboBox *dataTypeComboBox;
@property (nonatomic, strong) NSProgressIndicator *loadingIndicator;

// Main chart view
@property (nonatomic, strong) NSView *chartView;

// Footer controls
@property (nonatomic, strong) NSSlider *zoomSlider;
@property (nonatomic, strong) NSButton *zoomOutButton;
@property (nonatomic, strong) NSButton *zoomInButton;
@property (nonatomic, strong) NSButton *zoomAllButton;

#pragma mark - Data Properties

@property (nonatomic, strong, nullable) SeasonalDataModel *seasonalData;
@property (nonatomic, strong) NSString *currentSymbol;
@property (nonatomic, strong) NSString *currentDataType;

// Display properties
@property (nonatomic, assign) NSInteger yearsToShow;    // Controlled by zoom
@property (nonatomic, assign) NSInteger maxYears;       // Maximum available years

#pragma mark - Chart State

@property (nonatomic, assign) CGPoint mouseLocation;    // For crosshair
@property (nonatomic, assign) BOOL isMouseInChart;
@property (nonatomic, strong, nullable) QuarterlyDataPoint *hoveredQuarter;

#pragma mark - Public Methods

// Data loading
- (void)loadDataForSymbol:(NSString *)symbol dataType:(NSString *)dataType;
- (void)refreshCurrentData;

// Chart interaction
- (void)setZoomLevel:(NSInteger)years;
- (void)zoomIn;
- (void)zoomOut;
- (void)zoomToAll;

// Formatting helpers
- (NSString *)formatValue:(double)value;
- (NSString *)formatPercentChange:(double)percentChange;

@end

NS_ASSUME_NONNULL_END
