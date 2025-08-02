//
//  OtherDataAdapter.h
//  TradingApp
//
//  Adapter for OtherDataSource - converts various API responses to standard formats
//

#import <Foundation/Foundation.h>
#import "DataSourceAdapter.h"
#import "SeasonalDataModel.h"
#import "QuarterlyDataPoint.h"

@interface OtherDataAdapter : NSObject <DataSourceAdapter>

#pragma mark - Zacks Data Conversion

// Convert Zacks chart data to SeasonalDataModel
- (SeasonalDataModel *)convertZacksChartToSeasonalModel:(NSDictionary *)rawData
                                                 symbol:(NSString *)symbol
                                               dataType:(NSString *)dataType;

#pragma mark - Market Data Conversion

// Convert 52-week highs/lows to standard format
- (NSArray *)convertFrom52WeekHighs:(NSArray *)rawData;

// Convert stocks/ETF lists to standard format
- (NSArray *)convertFromStocksList:(NSArray *)rawData;
- (NSArray *)convertFromETFList:(NSArray *)rawData;

// Convert earnings data
- (NSArray *)convertFromEarningsCalendar:(NSArray *)rawData;
- (NSArray *)convertFromEarningsSurprise:(NSArray *)rawData;

// Convert institutional transactions
- (NSArray *)convertFromInstitutionalTransactions:(NSArray *)rawData;

#pragma mark - Company Data Conversion

// Convert news and press releases
- (NSArray *)convertFromNews:(NSArray *)rawData;
- (NSArray *)convertFromPressReleases:(NSArray *)rawData;

// Convert financial statements
- (NSDictionary *)convertFromFinancials:(NSDictionary *)rawData;

// Convert analyst data
- (NSDictionary *)convertFromPEGRatio:(NSDictionary *)rawData;
- (NSDictionary *)convertFromPriceTarget:(NSDictionary *)rawData;
- (NSArray *)convertFromRatings:(NSArray *)rawData;

// Convert insider/institutional data
- (NSDictionary *)convertFromShortInterest:(NSDictionary *)rawData;
- (NSArray *)convertFromInsiderTrades:(NSArray *)rawData;
- (NSArray *)convertFromInstitutionalHoldings:(NSArray *)rawData;

// Convert SEC filings
- (NSArray *)convertFromSECFilings:(NSArray *)rawData;

// Convert revenue/EPS data
- (NSDictionary *)convertFromRevenue:(NSDictionary *)rawData;
- (NSDictionary *)convertFromEPS:(NSDictionary *)rawData;
- (NSDictionary *)convertFromEarningsDate:(NSDictionary *)rawData;
- (NSArray *)convertFromEarningsSurpriseSymbol:(NSArray *)rawData;
- (NSDictionary *)convertFromEarningsForecast:(NSDictionary *)rawData;
- (NSDictionary *)convertFromAnalystMomentum:(NSDictionary *)rawData;

#pragma mark - External Data Conversion

// Convert Finviz statements
- (NSDictionary *)convertFromFinvizStatement:(NSDictionary *)rawData;

// Convert OpenInsider data
- (NSArray *)convertFromOpenInsider:(NSArray *)rawData;

// Convert StockCatalyst pre/post market movers
- (NSArray *)convertFromPrePostMarketMovers:(NSArray *)rawData;

@end
