//
//  DataSourceAdapter.h
//  mafia_AI
//
//  Protocollo per gli adapter che convertono dati API
//  UPDATED: Now returns runtime models directly
//

#import <Foundation/Foundation.h>
#import "MarketData.h"
#import "RuntimeModels.h"  // Import runtime models
#import "OrderBookEntry.h"

NS_ASSUME_NONNULL_BEGIN

@protocol DataSourceAdapter <NSObject>

@required

// Converte dati quote da formato API a MarketData standard (unchanged)
- (MarketData *)standardizeQuoteData:(NSDictionary *)rawData forSymbol:(NSString *)symbol;

// UPDATED: Converte dati storici da formato API direttamente a runtime HistoricalBarModel objects
- (NSArray<HistoricalBarModel *> *)standardizeHistoricalData:(id)rawData forSymbol:(NSString *)symbol;

// Converte dati order book da formato API
- (NSDictionary *)standardizeOrderBookData:(id)rawData forSymbol:(NSString *)symbol;

// TODO: Future - convert these to runtime models too
- (id)standardizePositionData:(NSDictionary *)rawData;
- (id)standardizeOrderData:(NSDictionary *)rawData;

@optional

// Nome della fonte per logging/debugging
- (NSString *)sourceName;

@end

NS_ASSUME_NONNULL_END
