//
//  YahooDataAdapter.h
//  TradingApp
//
//  Dedicated adapter for Yahoo Finance API JSON format
//  Converts Yahoo's modern JSON API responses to standardized app format
//

#import <Foundation/Foundation.h>
#import "DataSourceAdapter.h"

NS_ASSUME_NONNULL_BEGIN

@interface YahooDataAdapter : NSObject <DataSourceAdapter>

#pragma mark - DataSourceAdapter Protocol Implementation

// Quote data standardization
- (MarketData *)standardizeQuoteData:(NSDictionary *)rawData forSymbol:(NSString *)symbol;

// Historical data standardization - returns HistoricalBarModel objects
- (NSArray<HistoricalBarModel *> *)standardizeHistoricalData:(id)rawData forSymbol:(NSString *)symbol;

// Order book standardization
- (NSDictionary *)standardizeOrderBookData:(id)rawData forSymbol:(NSString *)symbol;

// Batch quotes standardization
- (NSDictionary *)standardizeBatchQuotesData:(id)rawData forSymbols:(NSArray<NSString *> *)symbols;

// Account/Portfolio data (future implementation)
- (id)standardizePositionData:(NSDictionary *)rawData;
- (id)standardizeOrderData:(NSDictionary *)rawData;
- (NSDictionary *)standardizeAccountData:(id)rawData;

#pragma mark - Yahoo-Specific Helper Methods

// Parse Yahoo Finance JSON chart response
- (NSDictionary *)parseYahooChartResponse:(NSDictionary *)jsonResponse forSymbol:(NSString *)symbol;

// Extract metadata from Yahoo response
- (NSDictionary *)extractMetadataFromYahooResponse:(NSDictionary *)yahooResult;

// Convert Yahoo timestamp arrays to NSDate objects
- (NSArray<NSDate *> *)convertYahooTimestamps:(NSArray<NSNumber *> *)timestamps;

// Validate Yahoo Finance response structure
- (BOOL)isValidYahooResponse:(NSDictionary *)response;

// Source name for debugging
- (NSString *)sourceName;

@end

NS_ASSUME_NONNULL_END
