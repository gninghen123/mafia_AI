//
//  TickChartWidget.h
//  mafia_AI
//
//  Widget for displaying tick-by-tick trade data with volume analysis
//

#import "BaseWidget.h"
#import "TickDataModel.h"

@interface TickChartWidget : BaseWidget

#pragma mark - Configuration

@property (nonatomic, strong) NSString *currentSymbol;
@property (nonatomic) NSInteger tickLimit;              // Number of ticks to display
@property (nonatomic) NSInteger volumeThreshold;        // Threshold for significant trades
@property (nonatomic) BOOL realTimeUpdates;            // Enable/disable real-time streaming

#pragma mark - Data

@property (nonatomic, strong, readonly) NSArray<TickDataModel *> *tickData;
@property (nonatomic, readonly) double cumulativeVolumeDelta;
@property (nonatomic, readonly) double currentVWAP;
@property (nonatomic, readonly) NSDictionary *volumeBreakdown;

#pragma mark - Public Methods

// Set symbol and load data
- (void)setSymbol:(NSString *)symbol;

// Refresh data manually
- (void)refreshData;

// Start/stop real-time updates
- (void)startRealTimeUpdates;
- (void)stopRealTimeUpdates;

// Export data
- (NSArray *)exportTickData;

@end
