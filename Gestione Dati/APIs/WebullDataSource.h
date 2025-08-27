//
//  WebullDataSource.h - UNIFICAZIONE PROTOCOLLO COMPLETA
//  TradingApp
//
//  ✅ UNIFIED: Implementa SOLO i metodi del protocollo DataSource unificato
//  🔥 ELIMINATI: Metodi Webull-specifici legacy non del protocollo
//

#import <Foundation/Foundation.h>
#import "DownloadManager.h"
#import "CommonTypes.h"

@interface WebullDataSource : NSObject <DataSource>

#pragma mark - DataSource Protocol - UNIFIED METHODS

// Connection Management (UNIFIED)
- (void)connectWithCompletion:(void (^)(BOOL success, NSError *error))completion;
- (void)disconnect;

// Market Data (UNIFIED - Required)
- (void)fetchQuoteForSymbol:(NSString *)symbol
                 completion:(void (^)(id quote, NSError *error))completion;

- (void)fetchQuotesForSymbols:(NSArray<NSString *> *)symbols
                   completion:(void (^)(NSDictionary *quotes, NSError *error))completion;

// Historical Data (UNIFIED - Required) - ✅ PARAMETRI CORRETTI
- (void)fetchHistoricalDataForSymbol:(NSString *)symbol
                           timeframe:(BarTimeframe)timeframe  // ✅ BarTimeframe non NSString
                           startDate:(NSDate *)startDate
                             endDate:(NSDate *)endDate
                   needExtendedHours:(BOOL)needExtendedHours  // ✅ AGGIUNTO
                          completion:(void (^)(NSArray *bars, NSError *error))completion;

- (void)fetchHistoricalDataForSymbol:(NSString *)symbol
                           timeframe:(BarTimeframe)timeframe  // ✅ BarTimeframe non NSString
                            barCount:(NSInteger)barCount      // ✅ barCount non count
                   needExtendedHours:(BOOL)needExtendedHours  // ✅ AGGIUNTO
                          completion:(void (^)(NSArray *bars, NSError *error))completion;

#pragma mark - Market Lists (UNIFIED - Optional)
- (void)fetchMarketListForType:(DataRequestType)listType
                    parameters:(NSDictionary *)parameters
                    completion:(void (^)(NSArray *results, NSError *error))completion;

@end

