//
//  NewsChartBridge.h
//  mafia_AI
//
//  Business logic bridge for correlating news with chart anomalies
//  NO UI - pure data processing and ranking
//

#import <Foundation/Foundation.h>
#import "ChartAnnotation.h"

@class NewsModel;

NS_ASSUME_NONNULL_BEGIN

/**
 * Container for a news item with its calculated relevance score
 */
@interface NewsWithRelevance : NSObject

@property (nonatomic, strong) NewsModel *news;
@property (nonatomic, assign) double relevanceScore;  // 0-100

@end

/**
 * Bridge between chart anomalies and news data
 * Handles fetching news for specific dates and calculating relevance scores
 */
@interface NewsChartBridge : NSObject

#pragma mark - Main Methods

/**
 * Find news correlated to a chart anomaly
 * Fetches news in temporal window around anomaly and ranks by relevance
 *
 * @param anomaly The detected chart anomaly
 * @param completion Returns array of NewsWithRelevance sorted by score (highest first)
 */
- (void)findNewsForAnomaly:(ChartAnomaly *)anomaly
                completion:(void(^)(NSArray<NewsWithRelevance *> *rankedNews, NSError * _Nullable error))completion;

/**
 * Calculate relevance score for a news item relative to an anomaly
 * Score is 0-100 based on multiple factors
 *
 * @param news The news item to score
 * @param anomaly The chart anomaly context
 * @return Relevance score (0-100)
 */
- (double)calculateRelevanceScore:(NewsModel *)news
                      forAnomaly:(ChartAnomaly *)anomaly;

#pragma mark - Configuration

/**
 * Temporal window for news search (default: 36 hours before, 24 after)
 */
@property (nonatomic, assign) NSInteger hoursBeforeAnomaly;  // Default: 36 (1.5 days)
@property (nonatomic, assign) NSInteger hoursAfterAnomaly;   // Default: 24 (1 day)

/**
 * Minimum relevance score to include in results (default: 50)
 */
@property (nonatomic, assign) double minimumRelevanceScore;

@end

NS_ASSUME_NONNULL_END
