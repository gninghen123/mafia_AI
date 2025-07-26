//
//  DataSourceAdapter.h
//  mafia_AI
//
//  Protocollo per gli adapter che convertono dati API
//

#import <Foundation/Foundation.h>
#import "MarketData.h"
#import "HistoricalBar+CoreDataClass.h"
#import "Position.h"
#import "Order.h"

NS_ASSUME_NONNULL_BEGIN

@protocol DataSourceAdapter <NSObject>

@required

// Converte dati quote da formato API a MarketData standard
- (MarketData *)standardizeQuoteData:(NSDictionary *)rawData forSymbol:(NSString *)symbol;

// Converte dati storici da formato API a array di dizionari
- (NSArray<NSDictionary *> *)standardizeHistoricalData:(id)rawData forSymbol:(NSString *)symbol;

// Converte dati posizioni
- (Position *)standardizePositionData:(NSDictionary *)rawData;

// Converte dati ordini
- (Order *)standardizeOrderData:(NSDictionary *)rawData;

@optional

// Nome della fonte per logging/debugging
- (NSString *)sourceName;

@end

NS_ASSUME_NONNULL_END
