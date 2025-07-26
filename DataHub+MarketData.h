//
//  DataHub+MarketData.h
//  mafia_AI
//
//  Estensione del DataHub per gestire i dati di mercato
//

#import "DataHub.h"
#import "MarketQuote+CoreDataClass.h"
#import "HistoricalBar+CoreDataClass.h"
#import "MarketPerformer+CoreDataClass.h"
#import "CompanyInfo+CoreDataClass.h"

NS_ASSUME_NONNULL_BEGIN

@interface DataHub (MarketData)

#pragma mark - Market Quotes

// Salva o aggiorna una quote
- (MarketQuote *)saveMarketQuote:(NSDictionary *)quoteData forSymbol:(NSString *)symbol;

// Recupera l'ultima quote per un simbolo
- (MarketQuote *)getQuoteForSymbol:(NSString *)symbol;

// Recupera quote per multipli simboli
- (NSArray<MarketQuote *> *)getQuotesForSymbols:(NSArray<NSString *> *)symbols;

// Pulisce quote vecchie (più di N giorni)
- (void)cleanOldQuotes:(NSInteger)daysToKeep;

#pragma mark - Historical Data

// Salva barre storiche
- (void)saveHistoricalBars:(NSArray<NSDictionary *> *)barsData
                 forSymbol:(NSString *)symbol
                timeframe:(NSInteger)timeframe;

// Recupera dati storici
- (NSArray<HistoricalBar *> *)getHistoricalBarsForSymbol:(NSString *)symbol
                                               timeframe:(NSInteger)timeframe
                                               startDate:(NSDate *)startDate
                                                 endDate:(NSDate *)endDate;

// Verifica se ci sono dati storici per un periodo
- (BOOL)hasHistoricalDataForSymbol:(NSString *)symbol
                         timeframe:(NSInteger)timeframe
                         startDate:(NSDate *)startDate;

#pragma mark - Market Lists

// Salva lista di performers (gainers/losers)
- (void)saveMarketPerformers:(NSArray<NSDictionary *> *)performers
                    listType:(NSString *)listType
                   timeframe:(NSString *)timeframe;

// Recupera performers per tipo e timeframe
- (NSArray<MarketPerformer *> *)getMarketPerformersForList:(NSString *)listType
                                                 timeframe:(NSString *)timeframe;

// Recupera tutti i tipi di liste disponibili
- (NSArray<NSString *> *)getAvailableMarketLists;

// Pulisce performers vecchi
- (void)cleanOldMarketPerformers:(NSInteger)hoursToKeep;

#pragma mark - Company Info

// Salva o aggiorna info aziendali
- (CompanyInfo *)saveCompanyInfo:(NSDictionary *)infoData forSymbol:(NSString *)symbol;

// Recupera info aziendali
- (CompanyInfo *)getCompanyInfoForSymbol:(NSString *)symbol;

// Verifica se le info sono aggiornate
- (BOOL)hasRecentCompanyInfoForSymbol:(NSString *)symbol maxAge:(NSTimeInterval)maxAge;

#pragma mark - Batch Operations

// Salva multipli quote in batch
- (void)saveMarketQuotesBatch:(NSArray<NSDictionary *> *)quotesData;

// Recupera tutti i simboli con dati
- (NSArray<NSString *> *)getAllSymbolsWithMarketData;

// Statistiche sui dati salvati
- (NSDictionary *)getMarketDataStatistics;


#pragma mark - update

- (void)requestMarketDataUpdate;
- (void)requestMarketListUpdate:(NSString *)listType timeframe:(NSString *)timeframe;

@end

NS_ASSUME_NONNULL_END
