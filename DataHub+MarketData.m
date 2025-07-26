//
//  DataHub+MarketData.m
//  mafia_AI
//

#import "DataHub+MarketData.h"
#import "DataHub+MarketData.h"
#import "DataManager.h"            // <-- AGGIUNGI QUESTO
#import "DataManager+MarketLists.h"

@implementation DataHub (MarketData)

#pragma mark - Market Quotes

- (MarketQuote *)saveMarketQuote:(NSDictionary *)quoteData forSymbol:(NSString *)symbol {
    // Cerca quote esistente o crea nuova
    NSFetchRequest *request = [MarketQuote fetchRequest];
    request.predicate = [NSPredicate predicateWithFormat:@"symbol == %@", symbol];
    
    NSError *error = nil;
    NSArray *results = [self.mainContext executeFetchRequest:request error:&error];
    
    MarketQuote *quote = results.firstObject;
    if (!quote) {
        quote = [NSEntityDescription insertNewObjectForEntityForName:@"MarketQuote"
                                              inManagedObjectContext:self.mainContext];
        quote.symbol = symbol;
    }
    
    // Aggiorna dati
    quote.name = quoteData[@"name"] ?: symbol;
    quote.exchange = quoteData[@"exchange"] ?: @"";
    
    quote.currentPrice = [quoteData[@"currentPrice"] doubleValue];
    quote.previousClose = [quoteData[@"previousClose"] doubleValue];
    quote.open = [quoteData[@"open"] doubleValue];
    quote.high = [quoteData[@"high"] doubleValue];
    quote.low = [quoteData[@"low"] doubleValue];
    
    quote.change = [quoteData[@"change"] doubleValue];
    quote.changePercent = [quoteData[@"changePercent"] doubleValue];
    
    quote.volume = [quoteData[@"volume"] longLongValue];
    quote.avgVolume = [quoteData[@"avgVolume"] longLongValue];
    
    quote.marketCap = [quoteData[@"marketCap"] doubleValue];
    quote.pe = [quoteData[@"pe"] doubleValue];
    quote.eps = [quoteData[@"eps"] doubleValue];
    quote.beta = [quoteData[@"beta"] doubleValue];
    
    quote.lastUpdate = [NSDate date];
    quote.marketTime = quoteData[@"marketTime"] ?: [NSDate date];
    
    [self saveContext];
    
    // Notifica aggiornamento
    [[NSNotificationCenter defaultCenter] postNotificationName:@"DataHubMarketQuoteUpdated"
                                                        object:self
                                                      userInfo:@{@"symbol": symbol, @"quote": quote}];
    
    return quote;
}

- (MarketQuote *)getQuoteForSymbol:(NSString *)symbol {
    NSFetchRequest *request = [MarketQuote fetchRequest];
    request.predicate = [NSPredicate predicateWithFormat:@"symbol == %@", symbol];
    
    NSError *error = nil;
    NSArray *results = [self.mainContext executeFetchRequest:request error:&error];
    
    return results.firstObject;
}

- (NSArray<MarketQuote *> *)getQuotesForSymbols:(NSArray<NSString *> *)symbols {
    NSFetchRequest *request = [MarketQuote fetchRequest];
    request.predicate = [NSPredicate predicateWithFormat:@"symbol IN %@", symbols];
    
    NSError *error = nil;
    NSArray *results = [self.mainContext executeFetchRequest:request error:&error];
    
    return results ?: @[];
}

- (void)cleanOldQuotes:(NSInteger)daysToKeep {
    NSDate *cutoffDate = [[NSDate date] dateByAddingTimeInterval:-daysToKeep * 24 * 60 * 60];
    
    NSFetchRequest *request = [MarketQuote fetchRequest];
    request.predicate = [NSPredicate predicateWithFormat:@"lastUpdate < %@", cutoffDate];
    
    NSError *error = nil;
    NSArray *oldQuotes = [self.mainContext executeFetchRequest:request error:&error];
    
    for (MarketQuote *quote in oldQuotes) {
        [self.mainContext deleteObject:quote];
    }
    
    [self saveContext];
}

#pragma mark - Historical Data

- (void)saveHistoricalBars:(NSArray<NSDictionary *> *)barsData
                 forSymbol:(NSString *)symbol
                timeframe:(NSInteger)timeframe {
    
    // Prima elimina barre esistenti per evitare duplicati
    NSFetchRequest *deleteRequest = [HistoricalBar fetchRequest];
    deleteRequest.predicate = [NSPredicate predicateWithFormat:@"symbol == %@ AND timeframe == %d",
                             symbol, timeframe];
    
    NSBatchDeleteRequest *batchDelete = [[NSBatchDeleteRequest alloc] initWithFetchRequest:deleteRequest];
    [self.mainContext executeRequest:batchDelete error:nil];
    
    // Salva nuove barre
    for (NSDictionary *barData in barsData) {
        HistoricalBar *bar = [NSEntityDescription insertNewObjectForEntityForName:@"HistoricalBar"
                                                        inManagedObjectContext:self.mainContext];
        
        bar.symbol = symbol;
        bar.date = barData[@"date"];
        bar.open = [barData[@"open"] doubleValue];
        bar.high = [barData[@"high"] doubleValue];
        bar.low = [barData[@"low"] doubleValue];
        bar.close = [barData[@"close"] doubleValue];
        bar.adjustedClose = [barData[@"adjustedClose"] doubleValue];
        bar.volume = [barData[@"volume"] longLongValue];
        bar.timeframe = timeframe;
    }
    
    [self saveContext];
}

- (NSArray<HistoricalBar *> *)getHistoricalBarsForSymbol:(NSString *)symbol
                                               timeframe:(NSInteger)timeframe
                                               startDate:(NSDate *)startDate
                                                 endDate:(NSDate *)endDate {
    
    NSFetchRequest *request = [HistoricalBar fetchRequest];
    
    NSMutableArray *predicates = [NSMutableArray array];
    [predicates addObject:[NSPredicate predicateWithFormat:@"symbol == %@", symbol]];
    [predicates addObject:[NSPredicate predicateWithFormat:@"timeframe == %d", timeframe]];
    
    if (startDate) {
        [predicates addObject:[NSPredicate predicateWithFormat:@"date >= %@", startDate]];
    }
    if (endDate) {
        [predicates addObject:[NSPredicate predicateWithFormat:@"date <= %@", endDate]];
    }
    
    request.predicate = [NSCompoundPredicate andPredicateWithSubpredicates:predicates];
    request.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"date" ascending:YES]];
    
    NSError *error = nil;
    NSArray *results = [self.mainContext executeFetchRequest:request error:&error];
    
    return results ?: @[];
}

- (BOOL)hasHistoricalDataForSymbol:(NSString *)symbol
                         timeframe:(NSInteger)timeframe
                         startDate:(NSDate *)startDate {
    
    NSFetchRequest *request = [HistoricalBar fetchRequest];
    request.predicate = [NSPredicate predicateWithFormat:@"symbol == %@ AND timeframe == %d AND date >= %@",
                        symbol, timeframe, startDate];
    request.fetchLimit = 1;
    
    NSError *error = nil;
    NSUInteger count = [self.mainContext countForFetchRequest:request error:&error];
    
    return count > 0;
}

#pragma mark - Market Lists

- (void)saveMarketPerformers:(NSArray<NSDictionary *> *)performers
                    listType:(NSString *)listType
                   timeframe:(NSString *)timeframe {
    
    // Elimina performers vecchi per questa lista
    NSFetchRequest *deleteRequest = [MarketPerformer fetchRequest];
    deleteRequest.predicate = [NSPredicate predicateWithFormat:@"listType == %@ AND timeframe == %@",
                             listType, timeframe];
    
    NSBatchDeleteRequest *batchDelete = [[NSBatchDeleteRequest alloc] initWithFetchRequest:deleteRequest];
    [self.mainContext executeRequest:batchDelete error:nil];
    
    // Salva nuovi performers
    for (NSDictionary *performerData in performers) {
        MarketPerformer *performer = [NSEntityDescription insertNewObjectForEntityForName:@"MarketPerformer"
                                                               inManagedObjectContext:self.mainContext];
        
        performer.symbol = performerData[@"symbol"];
        performer.name = performerData[@"name"] ?: performerData[@"symbol"];
        performer.price = [performerData[@"price"] doubleValue];
        performer.changePercent = [performerData[@"changePercent"] doubleValue];
        performer.volume = [performerData[@"volume"] longLongValue];
        performer.listType = listType;
        performer.timeframe = timeframe;
        performer.timestamp = [NSDate date];
    }
    
    [self saveContext];
    
    // Notifica aggiornamento lista
    [[NSNotificationCenter defaultCenter] postNotificationName:@"DataHubMarketListUpdated"
                                                        object:self
                                                      userInfo:@{@"listType": listType,
                                                               @"timeframe": timeframe}];
}

- (NSArray<MarketPerformer *> *)getMarketPerformersForList:(NSString *)listType
                                                 timeframe:(NSString *)timeframe {
    
    NSFetchRequest *request = [MarketPerformer fetchRequest];
    request.predicate = [NSPredicate predicateWithFormat:@"listType == %@ AND timeframe == %@",
                        listType, timeframe];
    request.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"changePercent"
                                                            ascending:(![listType isEqualToString:@"gainers"])]];
    
    NSError *error = nil;
    NSArray *results = [self.mainContext executeFetchRequest:request error:&error];
    
    return results ?: @[];
}

- (NSArray<NSString *> *)getAvailableMarketLists {
    NSFetchRequest *request = [MarketPerformer fetchRequest];
    request.resultType = NSDictionaryResultType;
    request.propertiesToFetch = @[@"listType", @"timeframe"];
    request.returnsDistinctResults = YES;
    
    NSError *error = nil;
    NSArray *results = [self.mainContext executeFetchRequest:request error:&error];
    
    NSMutableArray *lists = [NSMutableArray array];
    for (NSDictionary *result in results) {
        NSString *listIdentifier = [NSString stringWithFormat:@"%@-%@",
                                  result[@"listType"], result[@"timeframe"]];
        [lists addObject:listIdentifier];
    }
    
    return lists;
}

- (void)cleanOldMarketPerformers:(NSInteger)hoursToKeep {
    NSDate *cutoffDate = [[NSDate date] dateByAddingTimeInterval:-hoursToKeep * 60 * 60];
    
    NSFetchRequest *request = [MarketPerformer fetchRequest];
    request.predicate = [NSPredicate predicateWithFormat:@"timestamp < %@", cutoffDate];
    
    NSBatchDeleteRequest *batchDelete = [[NSBatchDeleteRequest alloc] initWithFetchRequest:request];
    [self.mainContext executeRequest:batchDelete error:nil];
    
    [self saveContext];
}

#pragma mark - Company Info

- (CompanyInfo *)saveCompanyInfo:(NSDictionary *)infoData forSymbol:(NSString *)symbol {
    NSFetchRequest *request = [CompanyInfo fetchRequest];
    request.predicate = [NSPredicate predicateWithFormat:@"symbol == %@", symbol];
    
    NSError *error = nil;
    NSArray *results = [self.mainContext executeFetchRequest:request error:&error];
    
    CompanyInfo *info = results.firstObject;
    if (!info) {
        info = [NSEntityDescription insertNewObjectForEntityForName:@"CompanyInfo"
                                          inManagedObjectContext:self.mainContext];
        info.symbol = symbol;
    }
    
    // Aggiorna dati
    info.name = infoData[@"name"] ?: symbol;
    info.sector = infoData[@"sector"] ?: @"";
    info.industry = infoData[@"industry"] ?: @"";
    info.companyDescription = infoData[@"description"] ?: @"";
    info.website = infoData[@"website"] ?: @"";
    info.ceo = infoData[@"ceo"] ?: @"";
    info.employees = [infoData[@"employees"] intValue];
    info.headquarters = infoData[@"headquarters"] ?: @"";
    info.ipoDate = infoData[@"ipoDate"];
    info.lastUpdate = [NSDate date];
    
    [self saveContext];
    
    return info;
}

- (CompanyInfo *)getCompanyInfoForSymbol:(NSString *)symbol {
    NSFetchRequest *request = [CompanyInfo fetchRequest];
    request.predicate = [NSPredicate predicateWithFormat:@"symbol == %@", symbol];
    
    NSError *error = nil;
    NSArray *results = [self.mainContext executeFetchRequest:request error:&error];
    
    return results.firstObject;
}

- (BOOL)hasRecentCompanyInfoForSymbol:(NSString *)symbol maxAge:(NSTimeInterval)maxAge {
    CompanyInfo *info = [self getCompanyInfoForSymbol:symbol];
    if (!info) return NO;
    
    NSTimeInterval age = [[NSDate date] timeIntervalSinceDate:info.lastUpdate];
    return age < maxAge;
}

#pragma mark - Batch Operations

- (void)saveMarketQuotesBatch:(NSArray<NSDictionary *> *)quotesData {
    for (NSDictionary *quoteData in quotesData) {
        NSString *symbol = quoteData[@"symbol"];
        if (symbol) {
            [self saveMarketQuote:quoteData forSymbol:symbol];
        }
    }
}

- (NSArray<NSString *> *)getAllSymbolsWithMarketData {
    NSMutableSet *symbols = [NSMutableSet set];
    
    // Simboli da quotes
    NSFetchRequest *quotesRequest = [MarketQuote fetchRequest];
    quotesRequest.resultType = NSDictionaryResultType;
    quotesRequest.propertiesToFetch = @[@"symbol"];
    quotesRequest.returnsDistinctResults = YES;
    
    NSArray *quoteResults = [self.mainContext executeFetchRequest:quotesRequest error:nil];
    for (NSDictionary *result in quoteResults) {
        [symbols addObject:result[@"symbol"]];
    }
    
    // Simboli da historical
    NSFetchRequest *historicalRequest = [HistoricalBar fetchRequest];
    historicalRequest.resultType = NSDictionaryResultType;
    historicalRequest.propertiesToFetch = @[@"symbol"];
    historicalRequest.returnsDistinctResults = YES;
    
    NSArray *historicalResults = [self.mainContext executeFetchRequest:historicalRequest error:nil];
    for (NSDictionary *result in historicalResults) {
        [symbols addObject:result[@"symbol"]];
    }
    
    return [symbols allObjects];
}

- (NSDictionary *)getMarketDataStatistics {
    NSMutableDictionary *stats = [NSMutableDictionary dictionary];
    
    // Conta quotes
    NSFetchRequest *quotesCount = [MarketQuote fetchRequest];
    stats[@"totalQuotes"] = @([self.mainContext countForFetchRequest:quotesCount error:nil]);
    
    // Conta historical bars
    NSFetchRequest *barsCount = [HistoricalBar fetchRequest];
    stats[@"totalHistoricalBars"] = @([self.mainContext countForFetchRequest:barsCount error:nil]);
    
    // Conta performers
    NSFetchRequest *performersCount = [MarketPerformer fetchRequest];
    stats[@"totalPerformers"] = @([self.mainContext countForFetchRequest:performersCount error:nil]);
    
    // Conta company info
    NSFetchRequest *infoCount = [CompanyInfo fetchRequest];
    stats[@"totalCompanyInfo"] = @([self.mainContext countForFetchRequest:infoCount error:nil]);
    
    return stats;
}



- (void)requestHistoricalDataUpdateForSymbol:(NSString *)symbol
                                   timeframe:(BarTimeframe)timeframe {
    // DataHub chiede internamente a DataManager di aggiornare
    // Questo mantiene l'incapsulamento - le UI non sanno di DataManager
    
    DataManager *dm = [DataManager sharedManager];
    NSDate *endDate = [NSDate date];
    NSDate *startDate = [endDate dateByAddingTimeInterval:-(30 * 24 * 60 * 60)]; // 30 giorni
    
    [dm requestHistoricalDataForSymbol:symbol
                            timeframe:timeframe
                            startDate:startDate
                              endDate:endDate
                           completion:^(NSArray<HistoricalBar *> *bars, NSError *error) {
        if (!error && bars.count > 0) {
            // I dati vengono salvati automaticamente tramite DataManager+Persistence
            // Invia notifica
            [[NSNotificationCenter defaultCenter] postNotificationName:@"DataHubHistoricalDataUpdated"
                                                                object:self
                                                              userInfo:@{
                                                                  @"symbol": symbol,
                                                                  @"timeframe": @(timeframe),
                                                                  @"barsCount": @(bars.count)
                                                              }];
        }
    }];
}

- (void)requestMarketDataUpdate {
    // DataHub chiede a DataManager di aggiornare
    DataManager *dm = [DataManager sharedManager];
    
    // Richiedi aggiornamenti per le liste principali
    [dm requestTopGainersWithRankType:@"1d" pageSize:50 completion:nil];
    [dm requestTopLosersWithRankType:@"1d" pageSize:50 completion:nil];
    [dm requestETFListWithCompletion:nil];
    
    // I dati verranno salvati automaticamente qui tramite DataManager+Persistence
}

@end
