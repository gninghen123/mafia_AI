//
//  NewsAnnotationProvider.h
//  mafia_AI
//
//  Provider for news-based annotations
//  Detects anomalies in chart and correlates with news
//

#import <Foundation/Foundation.h>
#import "ChartAnnotationProvider.h"

@class NewsChartBridge;
@class HistoricalBarModel;

NS_ASSUME_NONNULL_BEGIN

@interface NewsAnnotationProvider : NSObject <ChartAnnotationProvider>

/**
 * Bridge for news-anomaly correlation
 */
@property (nonatomic, strong) NewsChartBridge *newsChartBridge;

/**
 * Chart data for anomaly detection
 * Set this before calling getAnnotationsForSymbol
 */
@property (nonatomic, strong, nullable) NSArray<HistoricalBarModel *> *chartData;

#pragma mark - Anomaly Detection Configuration

/**
 * Volume threshold for spike detection (default: 2.0 = 2x average)
 */
@property (nonatomic, assign) double volumeSpikeThreshold;

/**
 * Gap threshold for gap detection (default: 2.0%)
 */
@property (nonatomic, assign) double gapThreshold;

/**
 * Volume threshold for gap+volume detection (default: 1.2 = 1.2x average)
 */
@property (nonatomic, assign) double gapVolumeThreshold;

/**
 * Period for moving average volume calculation (default: 50)
 */
@property (nonatomic, assign) NSInteger volumeAveragePeriod;

@end

NS_ASSUME_NONNULL_END
