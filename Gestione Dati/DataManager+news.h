//
//  DataManager+News.h
//  TradingApp
//
//  Extension for DataManager to handle news requests
//  Uses automatic routing to best available data source
//

#import "DataManager.h"
#import "RuntimeModels.h"

NS_ASSUME_NONNULL_BEGIN

@interface DataManager (News)

#pragma mark - News Requests (Automatic Routing)

/**
 * Request news from all available sources (automatic routing)
 * @param symbol Stock symbol
 * @param limit Maximum number of news items (default: 50)
 * @param completion Completion handler with NewsModel array
 * @return Request ID for tracking
 */
- (NSString *)requestNewsForSymbol:(NSString *)symbol
                             limit:(NSInteger)limit
                        completion:(void (^)(NSArray<NewsModel *> *news, NSError *error))completion;

/**
 * Request news from specific source
 * @param symbol Stock symbol
 * @param newsType Type of news request (DataRequestType enum value)
 * @param limit Maximum number of news items
 * @param preferredSource Preferred data source (or -1 for auto-select)
 * @param completion Completion handler with NewsModel array
 * @return Request ID for tracking
 */
- (NSString *)requestNewsForSymbol:(NSString *)symbol
                          newsType:(DataRequestType)newsType
                             limit:(NSInteger)limit
                   preferredSource:(DataSourceType)preferredSource
                        completion:(void (^)(NSArray<NewsModel *> *news, NSError *error))completion;

/**
 * Request Google Finance news
 * @param symbol Stock symbol
 * @param completion Completion handler with NewsModel array
 */
- (NSString *)requestGoogleFinanceNewsForSymbol:(NSString *)symbol
                                     completion:(void (^)(NSArray<NewsModel *> *news, NSError *error))completion;

/**
 * Request SEC filings
 * @param symbol Stock symbol
 * @param completion Completion handler with NewsModel array
 */
- (NSString *)requestSECFilingsForSymbol:(NSString *)symbol
                              completion:(void (^)(NSArray<NewsModel *> *filings, NSError *error))completion;

/**
 * Request Yahoo Finance news
 * @param symbol Stock symbol
 * @param completion Completion handler with NewsModel array
 */
- (NSString *)requestYahooFinanceNewsForSymbol:(NSString *)symbol
                                    completion:(void (^)(NSArray<NewsModel *> *news, NSError *error))completion;

/**
 * Request Seeking Alpha news
 * @param symbol Stock symbol
 * @param completion Completion handler with NewsModel array
 */
- (NSString *)requestSeekingAlphaNewsForSymbol:(NSString *)symbol
                                    completion:(void (^)(NSArray<NewsModel *> *news, NSError *error))completion;

/**
 * Request press releases
 * @param symbol Stock symbol
 * @param limit Maximum number of releases
 * @param completion Completion handler with NewsModel array
 */
- (NSString *)requestPressReleasesForSymbol:(NSString *)symbol
                                      limit:(NSInteger)limit
                                 completion:(void (^)(NSArray<NewsModel *> *releases, NSError *error))completion;

@end

NS_ASSUME_NONNULL_END
