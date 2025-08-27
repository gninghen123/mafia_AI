//
//  YahooDataSource.h - UNIFICAZIONE PROTOCOLLO
//  TradingApp
//
//  Yahoo Finance data source implementation - UNIFIED PROTOCOL SUPPORT
//

#import <Foundation/Foundation.h>
#import "DownloadManager.h"
#import "CommonTypes.h"

@interface YahooDataSource : NSObject <DataSource>

// Yahoo-specific configuration
@property (nonatomic, assign) BOOL useCrumbAuthentication;
@property (nonatomic, assign) NSTimeInterval cacheTimeout;

#pragma mark - DataSource Protocol - UNIFIED METHODS

// Connection (UNIFIED) - ✅ AGGIUNTO
- (void)connectWithCompletion:(void (^)(BOOL success, NSError *error))completion;
- (void)disconnect;

// Market Data (UNIFIED)
- (void)fetchQuoteForSymbol:(NSString *)symbol
                 completion:(void (^)(id quote, NSError *error))completion;

- (void)fetchQuotesForSymbols:(NSArray<NSString *> *)symbols
                   completion:(void (^)(NSDictionary *quotes, NSError *error))completion;

// Historical Data (UNIFIED) - ✅ AGGIORNATO con API Yahoo completa
- (void)fetchHistoricalDataForSymbol:(NSString *)symbol
                           timeframe:(BarTimeframe)timeframe
                           startDate:(NSDate *)startDate
                             endDate:(NSDate *)endDate
                   needExtendedHours:(BOOL)needExtendedHours
                          completion:(void (^)(NSArray *bars, NSError *error))completion;

- (void)fetchHistoricalDataForSymbol:(NSString *)symbol
                           timeframe:(BarTimeframe)timeframe
                            barCount:(NSInteger)barCount
                   needExtendedHours:(BOOL)needExtendedHours
                          completion:(void (^)(NSArray *bars, NSError *error))completion;

#pragma mark - Yahoo-Specific Helper Methods

// Authentication helpers
- (void)fetchCrumbWithCompletion:(void (^)(BOOL success, NSError *error))completion;

// Conversion helpers
- (NSString *)intervalStringForTimeframe:(BarTimeframe)timeframe;
- (NSString *)rangeStringForBarCount:(NSInteger)barCount timeframe:(BarTimeframe)timeframe;

// Parsing helpers
- (id)parseQuoteFromJSON:(NSDictionary *)json forSymbol:(NSString *)symbol;
- (NSArray *)parseHistoricalDataFromJSON:(NSDictionary *)json;

@end
