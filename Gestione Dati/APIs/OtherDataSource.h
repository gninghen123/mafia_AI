//
//  OtherDataSource.h
//  TradingApp
//
//  Multi-API data source for various endpoints that don't require complex authentication
//  Includes: Nasdaq APIs, Finviz, Zacks, OpenInsider scraping, StockCatalyst scraping
//

#import <Foundation/Foundation.h>
#import "DownloadManager.h"

@interface OtherDataSource : NSObject <DataSource>

#pragma mark - Market Overview Data

// 52-week highs/lows
- (void)fetch52WeekHighsWithCompletion:(void (^)(NSArray *results, NSError *error))completion;

// Stocks and ETF lists
- (void)fetchStocksListWithCompletion:(void (^)(NSArray *stocks, NSError *error))completion;
- (void)fetchETFListWithCompletion:(void (^)(NSArray *etfs, NSError *error))completion;

// Earnings calendar
- (void)fetchEarningsCalendarForDate:(NSString *)date
                          completion:(void (^)(NSArray *earnings, NSError *error))completion;

// Earnings surprise
- (void)fetchEarningsSurpriseForDate:(NSString *)date
                          completion:(void (^)(NSArray *surprises, NSError *error))completion;

// Institutional transactions > 1M
- (void)fetchInstitutionalTransactionsWithType:(NSInteger)type
                                         limit:(NSInteger)limit
                                    completion:(void (^)(NSArray *transactions, NSError *error))completion;

// Pre/Post market movers (StockCatalyst scraping)
- (void)fetchPrePostMarketMoversWithCompletion:(void (^)(NSArray *movers, NSError *error))completion;

#pragma mark - Company Specific Data

// News and press releases
- (void)fetchNewsForSymbol:(NSString *)symbol
                     limit:(NSInteger)limit
                completion:(void (^)(NSArray *news, NSError *error))completion;

- (void)fetchPressReleasesForSymbol:(NSString *)symbol
                              limit:(NSInteger)limit
                         completion:(void (^)(NSArray *releases, NSError *error))completion;

// Financial statements
- (void)fetchFinancialsForSymbol:(NSString *)symbol
                       frequency:(NSInteger)frequency
                      completion:(void (^)(NSDictionary *financials, NSError *error))completion;

// Analyst data
- (void)fetchPEGRatioForSymbol:(NSString *)symbol
                    completion:(void (^)(NSDictionary *pegData, NSError *error))completion;

- (void)fetchPriceTargetForSymbol:(NSString *)symbol
                       completion:(void (^)(NSDictionary *target, NSError *error))completion;

- (void)fetchRatingsForSymbol:(NSString *)symbol
                   completion:(void (^)(NSArray *ratings, NSError *error))completion;

// Insider and institutional data
- (void)fetchShortInterestForSymbol:(NSString *)symbol
                         completion:(void (^)(NSDictionary *shortData, NSError *error))completion;

- (void)fetchInsiderTradesForSymbol:(NSString *)symbol
                              limit:(NSInteger)limit
                         completion:(void (^)(NSArray *trades, NSError *error))completion;

- (void)fetchInstitutionalHoldingsForSymbol:(NSString *)symbol
                                      limit:(NSInteger)limit
                                 completion:(void (^)(NSArray *holdings, NSError *error))completion;

// SEC filings
- (void)fetchSECFilingsForSymbol:(NSString *)symbol
                           limit:(NSInteger)limit
                      completion:(void (^)(NSArray *filings, NSError *error))completion;

// Revenue and EPS
- (void)fetchRevenueForSymbol:(NSString *)symbol
                        limit:(NSInteger)limit
                   completion:(void (^)(NSDictionary *revenue, NSError *error))completion;

- (void)fetchEPSForSymbol:(NSString *)symbol
               completion:(void (^)(NSDictionary *eps, NSError *error))completion;

- (void)fetchEarningsDateForSymbol:(NSString *)symbol
                        completion:(void (^)(NSDictionary *earningsDate, NSError *error))completion;

- (void)fetchEarningsSurpriseForSymbol:(NSString *)symbol
                            completion:(void (^)(NSArray *surprises, NSError *error))completion;

- (void)fetchEarningsForecastForSymbol:(NSString *)symbol
                            completion:(void (^)(NSDictionary *forecast, NSError *error))completion;

- (void)fetchAnalystMomentumForSymbol:(NSString *)symbol
                           completion:(void (^)(NSDictionary *momentum, NSError *error))completion;

#pragma mark - Finviz Data

// Financial statements from Finviz
- (void)fetchFinvizStatementForSymbol:(NSString *)symbol
                            statement:(NSString *)statement // IA, IQ, BA, BQ, CA, CQ
                           completion:(void (^)(NSDictionary *data, NSError *error))completion;

#pragma mark - Zacks Data

// Zacks chart data
- (void)fetchZacksFundamentalChartForSymbol:(NSString *)symbol
                         wrapper:(NSString *)wrapper // revenue, eps_diluted, etc.
                      completion:(void (^)(NSDictionary *chartData, NSError *error))completion;

#pragma mark - Web Scraping Data

// OpenInsider CSV data
- (void)fetchOpenInsiderDataWithCompletion:(void (^)(NSArray *insiderData, NSError *error))completion;

#pragma mark - DataSource Protocol Implementation

// Market list dispatcher (implements DataSource protocol)
- (void)fetchMarketListForType:(DataRequestType)listType
                    parameters:(NSDictionary *)parameters
                    completion:(void (^)(NSArray *results, NSError *error))completion;
#pragma mark - Enhanced News Data Methods

/**
 * Fetch news from Google Finance RSS feed
 * @param symbol Stock symbol
 * @param completion Completion handler with parsed news array
 */
- (void)fetchGoogleFinanceNewsForSymbol:(NSString *)symbol
                             completion:(void (^)(NSArray *news, NSError *error))completion;

/**
 * Fetch SEC EDGAR filings from Atom feed
 * @param symbol Stock symbol (will be converted to CIK if needed)
 * @param completion Completion handler with parsed filings array
 */
- (void)fetchSECFilingsForSymbol:(NSString *)symbol
                      completion:(void (^)(NSArray *filings, NSError *error))completion;

/**
 * Fetch news from Yahoo Finance RSS feed
 * @param symbol Stock symbol
 * @param completion Completion handler with parsed news array
 */
- (void)fetchYahooFinanceNewsForSymbol:(NSString *)symbol
                            completion:(void (^)(NSArray *news, NSError *error))completion;

/**
 * Fetch news from Seeking Alpha RSS feed
 * @param symbol Stock symbol
 * @param completion Completion handler with parsed news array
 */
- (void)fetchSeekingAlphaNewsForSymbol:(NSString *)symbol
                            completion:(void (^)(NSArray *news, NSError *error))completion;
@end
