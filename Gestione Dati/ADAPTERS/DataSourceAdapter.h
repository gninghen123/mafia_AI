//
//  DataSourceAdapter.h
//  mafia_AI
//
//  Protocollo per gli adapter che convertono dati API
//  UPDATED: All methods now return runtime models directly
//

#import <Foundation/Foundation.h>
#import "MarketData.h"
#import "RuntimeModels.h"
#import "TradingRuntimeModels.h"
#import "OrderBookEntry.h"

NS_ASSUME_NONNULL_BEGIN

@protocol DataSourceAdapter <NSObject>

@required

#pragma mark - Market Data Standardization (Runtime Models)

/**
 * Convert raw quote data from API to MarketData runtime model
 * @param rawData Raw API data dictionary
 * @param symbol Symbol identifier
 * @return MarketData runtime model
 */
- (MarketData *)standardizeQuoteData:(NSDictionary *)rawData forSymbol:(NSString *)symbol;

/**
 * Convert raw historical data from API to HistoricalBarModel runtime models
 * @param rawData Raw API data (array or dictionary)
 * @param symbol Symbol identifier
 * @return Array of HistoricalBarModel runtime models
 */
- (NSArray<HistoricalBarModel *> *)standardizeHistoricalData:(id)rawData forSymbol:(NSString *)symbol;

/**
 * Convert raw order book data from API to standardized dictionary with OrderBookEntry objects
 * @param rawData Raw API data
 * @param symbol Symbol identifier
 * @return Dictionary with "bids" and "asks" arrays containing OrderBookEntry objects
 */
- (NSDictionary *)standardizeOrderBookData:(id)rawData forSymbol:(NSString *)symbol;

/**
 * Convert raw batch quotes data from API to dictionary of MarketData runtime models
 * @param rawData Raw API data
 * @param symbols Array of symbol identifiers
 * @return Dictionary mapping symbols to MarketData runtime models
 */
- (NSDictionary *)standardizeBatchQuotesData:(id)rawData forSymbols:(NSArray<NSString *> *)symbols;

#pragma mark - Market List Standardization (Runtime Models) - NEW

/**
 * Convert raw market list data from API to MarketPerformerModel runtime models
 * @param rawData Raw API data (array or dictionary)
 * @param listType Type of market list ("gainers", "losers", "etf", etc.)
 * @param timeframe Timeframe for the list ("1d", "52w", etc.)
 * @return Array of MarketPerformerModel runtime models
 */
- (NSArray<MarketPerformerModel *> *)standardizeMarketListData:(id)rawData
                                                      listType:(NSString *)listType
                                                     timeframe:(NSString *)timeframe;

#pragma mark - Portfolio Data Standardization (Runtime Models)

/**
 * Convert raw position data from API to AdvancedPositionModel runtime model
 * @param rawData Raw API data dictionary
 * @return AdvancedPositionModel runtime model or nil if conversion fails
 */
- (nullable AdvancedPositionModel *)standardizePositionData:(NSDictionary *)rawData;

/**
 * Convert raw order data from API to AdvancedOrderModel runtime model
 * @param rawData Raw API data dictionary
 * @return AdvancedOrderModel runtime model or nil if conversion fails
 */
- (nullable AdvancedOrderModel *)standardizeOrderData:(NSDictionary *)rawData;

/**
 * Convert raw account data from API to AccountModel runtime models
 * @param rawData Raw API data (array or dictionary)
 * @return Array of AccountModel runtime models
 */
- (NSArray<AccountModel *> *)standardizeAccountData:(id)rawData;

@optional

#pragma mark - Adapter Information

/**
 * Source name for logging and debugging
 * @return Human-readable name of the data source
 */
- (NSString *)sourceName;

@end

NS_ASSUME_NONNULL_END
