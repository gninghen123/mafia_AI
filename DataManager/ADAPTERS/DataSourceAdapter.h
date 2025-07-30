/*
 * SOLUZIONE COMPLETA PER IL CRASH IN standardizeHistoricalData
 *
 * PROBLEMA:
 * Gli adapter tentavano di creare oggetti Core Data (HistoricalBar)
 * con [[HistoricalBar alloc] init], ma HistoricalBar è NSManagedObject
 * e richiede un contesto Core Data.
 *
 * SOLUZIONE:
 * 1. Cambiare il protocollo per restituire array di dizionari
 * 2. Il DataHub converte i dizionari in oggetti Core Data
 * 3. Mantenere separazione di responsabilità
 */

// =======================================
// 1. DataSourceAdapter.h - AGGIORNATO
// =======================================

#import <Foundation/Foundation.h>
#import "MarketData.h"
#import "Position.h"
#import "Order.h"
#import "OrderBookEntry.h"

NS_ASSUME_NONNULL_BEGIN

@protocol DataSourceAdapter <NSObject>

@required

// Converte dati quote da formato API a MarketData standard
- (MarketData *)standardizeQuoteData:(NSDictionary *)rawData forSymbol:(NSString *)symbol;

// CAMBIATO: Ora restituisce array di dizionari invece di HistoricalBar
// I dizionari contengono: @{@"symbol", @"date", @"open", @"high", @"low", @"close", @"volume", @"adjustedClose"}
- (NSArray<NSDictionary *> *)standardizeHistoricalData:(id)rawData forSymbol:(NSString *)symbol;

// Converte dati order book da formato API
- (NSDictionary *)standardizeOrderBookData:(id)rawData forSymbol:(NSString *)symbol;

// Converte dati posizioni
- (Position *)standardizePositionData:(NSDictionary *)rawData;

// Converte dati ordini
- (Order *)standardizeOrderData:(NSDictionary *)rawData;

@optional

// Nome della fonte per logging/debugging
- (NSString *)sourceName;

@end

NS_ASSUME_NONNULL_END
