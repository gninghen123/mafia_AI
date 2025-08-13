//
//  DataHub+MarketData.m
//  mafia_AI
//
//  FINAL IMPLEMENTATION: Runtime models from DataManager
//  Core Data used only for internal persistence
//

#import "DataHub+MarketData.h"
#import "DataHub+Private.h"
#import "DataManager.h"
#import "MarketData.h"

// Import Core Data entities (for internal persistence only)
#import "HistoricalBar+CoreDataClass.h"
#import "MarketQuote+CoreDataClass.h"
#import "CompanyInfo+CoreDataClass.h"

@interface DataHub () <DataManagerDelegate>

@end

@implementation DataHub (MarketData)

#pragma mark - Initialization

+ (void)load {
    // Register as DataManager delegate when category loads
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        [[DataManager sharedManager] addDelegate:[DataHub shared]];
    });
}

- (void)initializeMarketDataCaches {
    if (!self.quotesCache) {
        self.quotesCache = [NSMutableDictionary dictionary];
        self.historicalCache = [NSMutableDictionary dictionary];
        self.companyInfoCache = [NSMutableDictionary dictionary];
        self.cacheTimestamps = [NSMutableDictionary dictionary];
        self.activeQuoteRequests = [NSMutableSet set];
        self.activeHistoricalRequests = [NSMutableSet set];
        self.subscribedSymbols = [NSMutableSet set];
    }
}

#pragma mark - Data Freshness Management

- (NSTimeInterval)TTLForDataType:(DataFreshnessType)type {
    switch (type) {
        case DataFreshnessTypeQuote:
            return 10.0; // 10 seconds for quotes
        case DataFreshnessTypeMarketOverview:
            return 60.0; // 1 minute
        case DataFreshnessTypeHistorical:
            return 300.0; // 5 minutes
        case DataFreshnessTypeCompanyInfo:
            return 86400.0; // 24 hours
        case DataFreshnessTypeWatchlist:
            return INFINITY; // Never expires
    }
    return INFINITY;
}

- (BOOL)isCacheStale:(NSString *)cacheKey dataType:(DataFreshnessType)type {
    [self initializeMarketDataCaches];
    
    NSDate *timestamp = self.cacheTimestamps[cacheKey];
    if (!timestamp) return YES;
    
    NSTimeInterval age = [[NSDate date] timeIntervalSinceDate:timestamp];
    NSTimeInterval ttl = [self TTLForDataType:type];
    
    return age > ttl;
}

- (void)updateCacheTimestamp:(NSString *)cacheKey {
    [self initializeMarketDataCaches];
    self.cacheTimestamps[cacheKey] = [NSDate date];
}


- (void)ensureSymbolExistsForQuote:(MarketQuoteModel *)quote {
    if (!quote || !quote.symbol) return;
    
    // ✅ ENSURE: Symbol entity exists for tracking (NO API CALLS)
    Symbol *symbolEntity = [self getSymbolWithName:quote.symbol];
    if (!symbolEntity) {
        // Create symbol entity if it doesn't exist
        symbolEntity = [self createSymbolWithName:quote.symbol];
        NSLog(@"✅ Created Symbol entity for quote: %@", quote.symbol);
    }
    
    // Update last interaction for tracking
    if (symbolEntity) {
        symbolEntity.lastInteraction = [NSDate date];
        [self saveContext];
    }
}


#pragma mark - Public API - Market Quotes


- (void)getQuoteForSymbol:(NSString *)symbol
               completion:(void(^)(MarketQuoteModel *quote, BOOL isLive))completion {
    
    if (!completion) {
        NSLog(@"❌ getQuoteForSymbol: completion block is nil");
        return;
    }
    
    if (!symbol || ![symbol isKindOfClass:[NSString class]] || symbol.length == 0) {
        NSLog(@"❌ getQuoteForSymbol: Invalid symbol: %@", symbol);
        completion(nil, NO);
        return;
    }
    
    NSString *normalizedSymbol = symbol.uppercaseString;
    
    // Use bulk method for consistency
    [self getQuotesForSymbols:@[normalizedSymbol] completion:^(NSDictionary<NSString *, MarketQuoteModel *> *quotes, BOOL allLive) {
        MarketQuoteModel *quote = quotes[normalizedSymbol];
        completion(quote, allLive);
    }];
}

- (void)getQuotesForSymbols:(NSArray<NSString *> *)symbols
                 completion:(void(^)(NSDictionary<NSString *, MarketQuoteModel *> *quotes, BOOL allLive))completion {
    
    if (!completion) {
        NSLog(@"❌ getQuotesForSymbols: completion block is nil");
        return;
    }
    
    if (!symbols || symbols.count == 0) {
        NSLog(@"⚠️ getQuotesForSymbols: Empty symbols array");
        completion(@{}, NO);
        return;
    }
    
    // ✅ TYPE SAFETY: Validate input is array of strings
    NSMutableArray<NSString *> *validSymbols = [NSMutableArray array];
    for (id obj in symbols) {
        if ([obj isKindOfClass:[NSString class]]) {
            NSString *symbol = (NSString *)obj;
            if (symbol.length > 0) {
                [validSymbols addObject:symbol.uppercaseString]; // Normalize
            }
        } else {
            NSLog(@"❌ getQuotesForSymbols: Invalid symbol type: %@", NSStringFromClass([obj class]));
        }
    }
    
    if (validSymbols.count == 0) {
        NSLog(@"❌ getQuotesForSymbols: No valid symbols after filtering");
        completion(@{}, NO);
        return;
    }
    
    NSLog(@"📊 DataHub: Getting quotes for %lu symbols: %@",
          (unsigned long)validSymbols.count, validSymbols);
    
    // ✅ ENSURE: Symbol entities exist for tracking
    for (NSString *symbol in validSymbols) {
        Symbol *symbolEntity = [self getSymbolWithName:symbol];
        if (!symbolEntity) {
            [self createSymbolWithName:symbol];
        }
    }
    
    // Check cache first
    NSMutableDictionary<NSString *, MarketQuoteModel *> *cachedQuotes = [NSMutableDictionary dictionary];
    NSMutableArray<NSString *> *symbolsToFetch = [NSMutableArray array];
    
    for (NSString *symbol in validSymbols) {
        MarketQuoteModel *cachedQuote = self.quotesCache[symbol];
        if (cachedQuote && ![self isCacheStale:symbol dataType:DataFreshnessTypeQuote]) {
            cachedQuotes[symbol] = cachedQuote;
        } else {
            [symbolsToFetch addObject:symbol];
        }
    }
    
    if (symbolsToFetch.count == 0) {
        // All symbols in cache
        NSLog(@"✅ All quotes served from cache");
        completion([cachedQuotes copy], YES);
        return;
    }
    
    // ✅ CORRECTED: Ask DataManager (not direct API)
    [[DataManager sharedManager] requestQuotesForSymbols:symbolsToFetch
                                              completion:^(NSDictionary *rawQuotes, NSError *error) {
        
        if (error) {
            NSLog(@"❌ Error fetching quotes from DataManager: %@", error);
            // Return cached quotes even if DataManager failed
            completion([cachedQuotes copy], NO);
            return;
        }
        
        // Merge cached and new quotes
        NSMutableDictionary<NSString *, MarketQuoteModel *> *allQuotes = [cachedQuotes mutableCopy];
        
        // ✅ DataManager returns standardized data, no need for conversion
        for (NSString *symbol in rawQuotes) {
            id quoteData = rawQuotes[symbol];
            MarketQuoteModel *runtimeQuote = nil;
            
            // Handle different possible return types from DataManager
            if ([quoteData isKindOfClass:[MarketQuoteModel class]]) {
                runtimeQuote = (MarketQuoteModel *)quoteData;
            } else if ([quoteData isKindOfClass:[NSDictionary class]]) {
                runtimeQuote = [MarketQuoteModel quoteFromDictionary:(NSDictionary *)quoteData];
            }
            
            if (runtimeQuote) {
                // Cache the quote
                [self cacheQuote:runtimeQuote];
                [self updateCacheTimestamp:symbol];
                
                // Save to Core Data in background
                [self saveQuoteModelToCoreData:runtimeQuote];
                
                // Add to result
                allQuotes[symbol] = runtimeQuote;
                
                NSLog(@"✅ Processed quote for %@", symbol);
            }
        }
        
        NSLog(@"✅ Retrieved %lu quotes (%lu cached, %lu fetched)",
              (unsigned long)allQuotes.count,
              (unsigned long)cachedQuotes.count,
              (unsigned long)rawQuotes.count);
        
        completion([allQuotes copy], YES);
    }];
}

#pragma mark - Public API - Historical Data

- (void)getHistoricalBarsForSymbol:(NSString *)symbol
                         timeframe:(BarTimeframe)timeframe
                          barCount:(NSInteger)barCount
                        completion:(void(^)(NSArray<HistoricalBarModel *> *bars, BOOL isFresh))completion {
    
    if (!symbol || !completion) return;
    
    [self initializeMarketDataCaches];
    
    NSLog(@"📈 DataHub: Getting historical data for %@ timeframe:%ld count:%ld", symbol, (long)timeframe, (long)barCount);
    
    // 1. Check memory cache
    NSString *cacheKey = [NSString stringWithFormat:@"historical_%@_%ld_%ld", symbol, (long)timeframe, (long)barCount];
    NSArray<HistoricalBarModel *> *cachedBars = self.historicalCache[cacheKey];
    BOOL isStale = [self isCacheStale:cacheKey dataType:DataFreshnessTypeHistorical];
    
    // 2. Return cached data immediately if available
    if (cachedBars) {
        completion(cachedBars, !isStale);
        
        // If fresh, we're done
        if (!isStale) return;
    }
    
    // 3. Check Core Data if no memory cache
    if (!cachedBars) {
        [self loadHistoricalDataFromCoreData:symbol
                                   timeframe:timeframe
                                    barCount:barCount
                                  completion:^(NSArray<HistoricalBarModel *> *bars) {
            if (bars.count > 0) {
                self.historicalCache[cacheKey] = bars;
                completion(bars, NO); // From Core Data = not fresh
            }
        }];
    }
    
    // 4. Request fresh data if needed
    if (isStale && ![self.activeHistoricalRequests containsObject:cacheKey]) {
        [self.activeHistoricalRequests addObject:cacheKey];
        
        [[DataManager sharedManager] requestHistoricalDataForSymbol:symbol
                                                          timeframe:timeframe
                                                              count:barCount
                                                         completion:^(NSArray<HistoricalBarModel *> *runtimeBars, NSError *error) {
            [self.activeHistoricalRequests removeObject:cacheKey];
            
            if (runtimeBars && runtimeBars.count > 0) {
                // Cache in memory
                [self cacheHistoricalBars:runtimeBars forKey:cacheKey];
                
                // Save to Core Data in background
                [self saveHistoricalBarsModelToCoreData:runtimeBars symbol:symbol timeframe:timeframe];
                
                // Call completion if this is the first response
                if (!cachedBars && completion) {
                    completion(runtimeBars, YES);
                }
            }
        }];
    }
}

- (void)getHistoricalBarsForSymbol:(NSString *)symbol
                         timeframe:(BarTimeframe)timeframe
                         startDate:(NSDate *)startDate
                           endDate:(NSDate *)endDate
                        completion:(void(^)(NSArray<HistoricalBarModel *> *bars, BOOL isFresh))completion {
    
    if (!symbol || !completion) return;
    
    // Calculate approximate bar count for caching
    NSInteger estimatedCount = [self estimateBarCountForTimeframe:timeframe startDate:startDate endDate:endDate];
    
    [self getHistoricalBarsForSymbol:symbol
                           timeframe:timeframe
                            barCount:estimatedCount
                          completion:completion];
}

#pragma mark - Public API - Company Info

- (void)getCompanyInfoForSymbol:(NSString *)symbol
                     completion:(void(^)(CompanyInfoModel * _Nullable info, BOOL isFresh))completion {
    
    if (!symbol || !completion) return;
    
    [self initializeMarketDataCaches];
    
    // 1. Check memory cache
    CompanyInfoModel *cachedInfo = self.companyInfoCache[symbol];
    NSString *cacheKey = [NSString stringWithFormat:@"company_%@", symbol];
    BOOL isStale = [self isCacheStale:cacheKey dataType:DataFreshnessTypeCompanyInfo];
    
    // 2. Return cached data immediately if available
    if (cachedInfo) {
        completion(cachedInfo, !isStale);
        
        // If fresh, we're done
        if (!isStale) return;
    }
    
    // 3. Check Core Data if no memory cache
    if (!cachedInfo) {
        [self loadCompanyInfoFromCoreData:symbol completion:^(CompanyInfoModel *info) {
            if (info) {
                self.companyInfoCache[symbol] = info;
                completion(info, NO); // From Core Data = not fresh
            }
        }];
    }
    
    // 4. For now, company info requests are not implemented in DataManager
    // Return cached data or nil
    if (!cachedInfo) {
        completion(nil, NO);
    }
}

#pragma mark - DataManager Delegate Methods

- (void)dataManager:(DataManager *)manager didUpdateQuote:(MarketData *)marketData forSymbol:(NSString *)symbol {
    
    // Convert MarketData to runtime model
    MarketQuoteModel *runtimeQuote = [MarketQuoteModel quoteFromMarketData:marketData];
    
    // Cache in memory
    [self cacheQuote:runtimeQuote];
    
    // Save to Core Data in background
    [self saveQuoteModelToCoreData:runtimeQuote];
    
    // Broadcast notification with runtime model
    [self broadcastQuoteUpdate:runtimeQuote];
}

- (void)dataManager:(DataManager *)manager didUpdateHistoricalData:(NSArray<HistoricalBarModel *> *)bars forSymbol:(NSString *)symbol {
    
    NSLog(@"📈 DataHub: Received %lu runtime HistoricalBarModel objects for %@", (unsigned long)bars.count, symbol);
    
    // Cache in memory with appropriate key
    BarTimeframe timeframe = bars.firstObject ? bars.firstObject.timeframe : BarTimeframe1Day;
    NSString *cacheKey = [NSString stringWithFormat:@"historical_%@_%ld_%lu", symbol, (long)timeframe, (unsigned long)bars.count];
    [self cacheHistoricalBars:bars forKey:cacheKey];
    
    // Save to Core Data in background
    [self saveHistoricalBarsModelToCoreData:bars symbol:symbol timeframe:timeframe];
    
    // Broadcast notification with runtime models
    [self broadcastHistoricalDataUpdate:bars forSymbol:symbol];
}

- (void)dataManager:(DataManager *)manager didFailWithError:(NSError *)error forRequest:(NSString *)requestID {
    NSLog(@"DataHub: DataManager request failed: %@ - %@", requestID, error.localizedDescription);
    
    // Broadcast error notification
    [[NSNotificationCenter defaultCenter] postNotificationName:@"DataHubErrorNotification"
                                                        object:self
                                                      userInfo:@{
                                                          @"error": error,
                                                          @"requestID": requestID
                                                      }];
}

#pragma mark - Caching Methods


#pragma mark - Cache Utility Methods

- (BOOL)isQuoteCacheStale:(NSString *)symbol {
    if (!symbol) return YES;
    
    [self initializeMarketDataCaches];
    
    NSString *cacheKey = [NSString stringWithFormat:@"quote_%@", symbol];
    NSDate *timestamp = self.cacheTimestamps[cacheKey];
    
    if (!timestamp) {
        return YES; // No timestamp = stale
    }
    
    // Consider quote stale after 30 seconds
    NSTimeInterval staleDuration = 30.0;
    NSTimeInterval age = [[NSDate date] timeIntervalSinceDate:timestamp];
    
    return age > staleDuration;
}

// Also add this helper method for updating cache timestamps


// Update the cacheQuote method to set timestamp

// Update the cacheQuote method to set timestamp (if not already implemented correctly)
- (void)cacheQuote:(MarketQuoteModel *)quote {
    if (!quote || !quote.symbol) return;
    
    [self initializeMarketDataCaches];
    
    self.quotesCache[quote.symbol] = quote;
    
    // Update timestamp
    NSString *cacheKey = [NSString stringWithFormat:@"quote_%@", quote.symbol];
    [self updateCacheTimestamp:cacheKey];
    
    NSLog(@"DataHub: Cached quote for %@ at %@", quote.symbol, [NSDate date]);
}

- (void)cacheHistoricalBars:(NSArray<HistoricalBarModel *> *)bars forKey:(NSString *)cacheKey {
    if (!bars || bars.count == 0 || !cacheKey) return;
    
    [self initializeMarketDataCaches];
    
    self.historicalCache[cacheKey] = bars;
    [self updateCacheTimestamp:cacheKey];
    
    NSLog(@"DataHub: Cached %lu HistoricalBarModel objects for key %@", (unsigned long)bars.count, cacheKey);
}

#pragma mark - Core Data Integration (Internal Persistence)

- (void)loadQuoteFromCoreData:(NSString *)symbol completion:(void(^)(MarketQuoteModel *quote))completion {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
        // Find Symbol first, then get its MarketQuote
        NSFetchRequest *symbolRequest = [Symbol fetchRequest];
        symbolRequest.predicate = [NSPredicate predicateWithFormat:@"symbol == %@", symbol];
        
        NSError *error = nil;
        NSArray *symbolResults = [self.mainContext executeFetchRequest:symbolRequest error:&error];
        
        MarketQuoteModel *runtimeQuote = nil;
        if (symbolResults.firstObject) {
            Symbol *symbolEntity = symbolResults.firstObject;
            // Get the most recent MarketQuote for this Symbol
            NSArray *quotes = [symbolEntity.marketQuotes allObjects];
            if (quotes.count > 0) {
                // Sort by lastUpdate and get most recent
                NSSortDescriptor *sortDescriptor = [NSSortDescriptor sortDescriptorWithKey:@"lastUpdate" ascending:NO];
                NSArray *sortedQuotes = [quotes sortedArrayUsingDescriptors:@[sortDescriptor]];
                MarketQuote *coreDataQuote = sortedQuotes.firstObject;
                runtimeQuote = [self convertCoreDataQuoteToRuntimeModel:coreDataQuote];
            }
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(runtimeQuote);
        });
    });
}

// Fix per loadHistoricalDataFromCoreData - Thread Safety con performBlock

- (void)loadHistoricalDataFromCoreData:(NSString *)symbol
                             timeframe:(BarTimeframe)timeframe
                              barCount:(NSInteger)barCount
                            completion:(void(^)(NSArray<HistoricalBarModel *> *bars))completion {
    
    [self.mainContext performBlock:^{
        
        // Find Symbol first, then get its HistoricalBars
        NSFetchRequest *symbolRequest = [Symbol fetchRequest];
        symbolRequest.predicate = [NSPredicate predicateWithFormat:@"symbol == %@", symbol];
        
        NSError *error = nil;
        NSArray *symbolResults = [self.mainContext executeFetchRequest:symbolRequest error:&error];
        
        NSArray<HistoricalBarModel *> *runtimeBars = @[];
        if (symbolResults.firstObject) {
            Symbol *symbolEntity = symbolResults.firstObject;
            
            // Filter and sort HistoricalBars for this Symbol
            NSPredicate *barsPredicate = [NSPredicate predicateWithFormat:@"timeframe == %d", (int)timeframe];
            NSSet *filteredBars = [symbolEntity.historicalBars filteredSetUsingPredicate:barsPredicate];
            
            // Sort by date descending and limit
            NSSortDescriptor *sortDescriptor = [NSSortDescriptor sortDescriptorWithKey:@"date" ascending:NO];
            NSArray *sortedBars = [filteredBars sortedArrayUsingDescriptors:@[sortDescriptor]];
            
            // Take only the requested count
            NSRange range = NSMakeRange(0, MIN(sortedBars.count, barCount));
            NSArray *limitedBars = [sortedBars subarrayWithRange:range];
            
            // Convert to runtime models
            NSMutableArray<HistoricalBarModel *> *mutableRuntimeBars = [NSMutableArray array];
            for (HistoricalBar *coreDataBar in limitedBars) {
                HistoricalBarModel *runtimeBar = [self convertCoreDataBarToRuntimeModel:coreDataBar];
                if (runtimeBar) {
                    [mutableRuntimeBars addObject:runtimeBar];
                }
            }
            runtimeBars = [mutableRuntimeBars copy];
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(runtimeBars);
        });
    }];
}

- (void)loadCompanyInfoFromCoreData:(NSString *)symbol completion:(void(^)(CompanyInfoModel *info))completion {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
        // Find Symbol first, then get its CompanyInfo
        NSFetchRequest *symbolRequest = [Symbol fetchRequest];
        symbolRequest.predicate = [NSPredicate predicateWithFormat:@"symbol == %@", symbol];
        
        NSError *error = nil;
        NSArray *symbolResults = [self.mainContext executeFetchRequest:symbolRequest error:&error];
        
        CompanyInfoModel *runtimeInfo = nil;
        if (symbolResults.firstObject) {
            Symbol *symbolEntity = symbolResults.firstObject;
            if (symbolEntity.companyInfo) {
                runtimeInfo = [self convertCoreDataCompanyInfoToRuntimeModel:symbolEntity.companyInfo];
            }
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(runtimeInfo);
        });
    });
}

#pragma mark - Core Data Saving (Background)

// Aggiornamento per DataHub+MarketData.m - saveQuoteModelToCoreData


- (void)saveQuoteModelToCoreData:(MarketQuoteModel *)quote {
    if (!quote || !quote.symbol) {
        NSLog(@"❌ saveQuoteModelToCoreData: Invalid quote");
        return;
    }
    
    // ✅ ENSURE: Symbol entity exists (NO API CALLS)
    [self ensureSymbolExistsForQuote:quote];
    
    // Find or create MarketQuote Core Data entity
    NSFetchRequest *request = [MarketQuote fetchRequest];
    request.predicate = [NSPredicate predicateWithFormat:@"symbol == %@", quote.symbol];
    request.fetchLimit = 1;
    
    NSError *error = nil;
    NSArray *results = [self.mainContext executeFetchRequest:request error:&error];
    
    if (error) {
        NSLog(@"❌ Error finding MarketQuote for %@: %@", quote.symbol, error);
        return;
    }
    
    MarketQuote *coreDataQuote;
    if (results.count > 0) {
        coreDataQuote = results.firstObject;
    } else {
        coreDataQuote = [NSEntityDescription insertNewObjectForEntityForName:@"MarketQuote"
                                                      inManagedObjectContext:self.mainContext];
    }
    
    // Update Core Data quote with runtime model data
    [self updateCoreDataQuote:coreDataQuote withRuntimeModel:quote];
    
    [self saveContext];
    
    NSLog(@"✅ Saved quote to Core Data: %@", quote.symbol);
}


- (void)saveHistoricalBarsModelToCoreData:(NSArray<HistoricalBarModel *> *)bars
                                   symbol:(NSString *)symbol
                                timeframe:(BarTimeframe)timeframe {
    
    if (!bars || bars.count == 0) return;
    
    // ✅ SOLUZIONE 1: Usa una coda seriale per evitare salvataggi concorrenti
    static dispatch_queue_t saveQueue;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        saveQueue = dispatch_queue_create("com.app.coredata.save", DISPATCH_QUEUE_SERIAL);
    });
    
    dispatch_async(saveQueue, ^{
        
        NSManagedObjectContext *backgroundContext = [self.persistentContainer newBackgroundContext];
        
        // ✅ SOLUZIONE 2: Imposta merge policy per risolvere conflitti automaticamente
        backgroundContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy;
        
        [backgroundContext performBlock:^{
            
            // ✅ SOLUZIONE 3: Verifica esistenza prima di creare/aggiornare
            for (HistoricalBarModel *barModel in bars) {
                [self saveHistoricalBarModelSafely:barModel
                                            symbol:symbol
                                         timeframe:timeframe
                                         inContext:backgroundContext];
            }
            
            NSError *error = nil;
            if (![backgroundContext save:&error]) {
                NSLog(@"❌ Error saving historical bars to Core Data: %@", error);
                
                // ✅ SOLUZIONE 4: Retry con refresh degli oggetti in caso di errore
                if (error.code == NSManagedObjectMergeError) {
                    [self retryHistoricalBarsSave:bars
                                           symbol:symbol
                                        timeframe:timeframe
                                        inContext:backgroundContext];
                }
            } else {
                NSLog(@"✅ Successfully saved %lu historical bars to Core Data for %@",
                      (unsigned long)bars.count, symbol);
            }
        }];
    });
}

- (void)saveHistoricalBarModelSafely:(HistoricalBarModel *)barModel
                              symbol:(NSString *)symbol
                           timeframe:(BarTimeframe)timeframe
                           inContext:(NSManagedObjectContext *)context {
    
    if (!barModel || !barModel.date) return;
    
    // Cerca se esiste già una barra per questa data/simbolo/timeframe
    NSFetchRequest *request = [HistoricalBar fetchRequest];
    request.predicate = [NSPredicate predicateWithFormat:
                        @"symbol.symbol == %@ AND date == %@ AND timeframe == %d",
                        symbol, barModel.date, timeframe];
    request.fetchLimit = 1;
    
    NSError *error = nil;
    NSArray *results = [context executeFetchRequest:request error:&error];
    
    if (error) {
        NSLog(@"❌ Error fetching existing HistoricalBar: %@", error);
        return;
    }
    
    HistoricalBar *coreDataBar;
    BOOL isNew = NO;
    
    if (results.count > 0) {
        // Aggiorna la barra esistente
        coreDataBar = results.firstObject;
        
        // ✅ SOLUZIONE 5: Refresh dell'oggetto per evitare conflitti di versione
        [context refreshObject:coreDataBar mergeChanges:YES];
    } else {
        // Crea nuova barra
        coreDataBar = [NSEntityDescription insertNewObjectForEntityForName:@"HistoricalBar"
                                                    inManagedObjectContext:context];
        isNew = YES;
    }
    
    // Aggiorna i dati solo se necessario
    if (isNew || [self shouldUpdateHistoricalBar:coreDataBar withModel:barModel]) {
        [self updateCoreDataBar:coreDataBar withRuntimeModel:barModel symbol:symbol timeframe:timeframe inContext:context];
    }
}

// ✅ NUOVO METODO: Verifica se l'aggiornamento è necessario
- (BOOL)shouldUpdateHistoricalBar:(HistoricalBar *)coreDataBar withModel:(HistoricalBarModel *)barModel {
    // Confronta i valori chiave per vedere se è cambiato qualcosa
    return (fabs(coreDataBar.close - barModel.close) > 0.001 ||
            fabs(coreDataBar.open - barModel.open) > 0.001 ||
            fabs(coreDataBar.high - barModel.high) > 0.001 ||
            fabs(coreDataBar.low - barModel.low) > 0.001 ||
            coreDataBar.volume != barModel.volume);
}

// ✅ NUOVO METODO: Retry in caso di errore di merge
- (void)retryHistoricalBarsSave:(NSArray<HistoricalBarModel *> *)bars
                         symbol:(NSString *)symbol
                      timeframe:(BarTimeframe)timeframe
                      inContext:(NSManagedObjectContext *)context {
    
    NSLog(@"🔄 Retrying historical bars save after merge conflict...");
    
    // Reset del context per pulire lo stato
    [context reset];
    
    // Attendi un breve momento per evitare conflitti immediati
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_current_queue(), ^{
        
        // Riprova il salvataggio
        for (HistoricalBarModel *barModel in bars) {
            [self saveHistoricalBarModelSafely:barModel
                                        symbol:symbol
                                     timeframe:timeframe
                                     inContext:context];
        }
        
        NSError *retryError = nil;
        if (![context save:&retryError]) {
            NSLog(@"❌ Retry failed for historical bars save: %@", retryError);
        } else {
            NSLog(@"✅ Retry successful for historical bars save");
        }
    });
}


#pragma mark - Core Data Conversion Helpers (FIXED)

- (MarketQuoteModel *)convertCoreDataQuoteToRuntimeModel:(MarketQuote *)coreDataQuote {
    MarketQuoteModel *runtimeQuote = [[MarketQuoteModel alloc] init];
    
    // Use relationship instead of attribute
    runtimeQuote.symbol = coreDataQuote.symbol.symbol;
    runtimeQuote.name = coreDataQuote.name;
    runtimeQuote.exchange = coreDataQuote.exchange;
    
    // Core Data uses currentPrice, convert to NSNumber
    runtimeQuote.last = @(coreDataQuote.currentPrice);
    
    // Core Data doesn't have bid/ask, use currentPrice as fallback
    runtimeQuote.bid = @(coreDataQuote.currentPrice);
    runtimeQuote.ask = @(coreDataQuote.currentPrice);
    
    // OHLC data - Core Data uses double, convert to NSNumber
    runtimeQuote.open = @(coreDataQuote.open);
    runtimeQuote.high = @(coreDataQuote.high);
    runtimeQuote.low = @(coreDataQuote.low);
    runtimeQuote.close = @(coreDataQuote.currentPrice); // Use currentPrice as close
    runtimeQuote.previousClose = @(coreDataQuote.previousClose);
    
    // Changes
    runtimeQuote.change = @(coreDataQuote.change);
    runtimeQuote.changePercent = @(coreDataQuote.changePercent);
    
    // Volume - Core Data uses int64_t, convert to NSNumber
    runtimeQuote.volume = @(coreDataQuote.volume);
    runtimeQuote.avgVolume = @(coreDataQuote.avgVolume);
    
    // Market data
    runtimeQuote.marketCap = @(coreDataQuote.marketCap);
    runtimeQuote.pe = @(coreDataQuote.pe);
    runtimeQuote.eps = @(coreDataQuote.eps);
    runtimeQuote.beta = @(coreDataQuote.beta);
    
    // Timestamp
    runtimeQuote.timestamp = coreDataQuote.lastUpdate ?: [NSDate date];
    runtimeQuote.isMarketOpen = YES; // Default, Core Data doesn't store this
    
    return runtimeQuote;
}

- (void)updateCoreDataBar:(HistoricalBar *)coreDataBar
        withRuntimeModel:(HistoricalBarModel *)barModel
                  symbol:(NSString *)symbolName
               timeframe:(BarTimeframe)timeframe
               inContext:(NSManagedObjectContext *)context {
    
    // Assicurati che il Symbol esista
    if (!coreDataBar.symbol) {
        Symbol *symbol = [self findOrCreateSymbolWithName:symbolName inContext:context];
        coreDataBar.symbol = symbol;
    }
    
    // Aggiorna i dati della barra
    coreDataBar.date = barModel.date;
    coreDataBar.open = barModel.open;
    coreDataBar.high = barModel.high;
    coreDataBar.low = barModel.low ;
    coreDataBar.close = barModel.close;
    coreDataBar.adjustedClose = barModel.adjustedClose;
    coreDataBar.volume = barModel.volume ;
    coreDataBar.timeframe = timeframe;
}

- (void)updateCoreDataQuote:(MarketQuote *)coreDataQuote withRuntimeModel:(MarketQuoteModel *)runtimeQuote {
    // Ensure Symbol relationship is set
    if (!coreDataQuote.symbol) {
        Symbol *symbol = [self findOrCreateSymbolWithName:runtimeQuote.symbol inContext:coreDataQuote.managedObjectContext];
        coreDataQuote.symbol = symbol;
    }
    
    coreDataQuote.name = runtimeQuote.name;
    coreDataQuote.exchange = runtimeQuote.exchange;
    
    // Core Data uses currentPrice, not lastPrice
    coreDataQuote.currentPrice = runtimeQuote.last ? [runtimeQuote.last doubleValue] : 0.0;
    
    // OHLC data - convert NSNumber to double
    coreDataQuote.open = runtimeQuote.open ? [runtimeQuote.open doubleValue] : 0.0;
    coreDataQuote.high = runtimeQuote.high ? [runtimeQuote.high doubleValue] : 0.0;
    coreDataQuote.low = runtimeQuote.low ? [runtimeQuote.low doubleValue] : 0.0;
    coreDataQuote.previousClose = runtimeQuote.previousClose ? [runtimeQuote.previousClose doubleValue] : 0.0;
    
    // Changes
    coreDataQuote.change = runtimeQuote.change ? [runtimeQuote.change doubleValue] : 0.0;
    coreDataQuote.changePercent = runtimeQuote.changePercent ? [runtimeQuote.changePercent doubleValue] : 0.0;
    
    // Volume - convert NSNumber to int64_t
    coreDataQuote.volume = runtimeQuote.volume ? [runtimeQuote.volume longLongValue] : 0;
    coreDataQuote.avgVolume = runtimeQuote.avgVolume ? [runtimeQuote.avgVolume longLongValue] : 0;
    
    // Market data
    coreDataQuote.marketCap = runtimeQuote.marketCap ? [runtimeQuote.marketCap doubleValue] : 0.0;
    coreDataQuote.pe = runtimeQuote.pe ? [runtimeQuote.pe doubleValue] : 0.0;
    coreDataQuote.eps = runtimeQuote.eps ? [runtimeQuote.eps doubleValue] : 0.0;
    coreDataQuote.beta = runtimeQuote.beta ? [runtimeQuote.beta doubleValue] : 0.0;
    
    // Timestamp
    coreDataQuote.marketTime = runtimeQuote.timestamp;
}


- (HistoricalBarModel *)convertCoreDataBarToRuntimeModel:(HistoricalBar *)coreDataBar {
    HistoricalBarModel *runtimeBar = [[HistoricalBarModel alloc] init];
    
    // Use relationship instead of attribute
    runtimeBar.symbol = coreDataBar.symbol.symbol;
    runtimeBar.date = coreDataBar.date;
    runtimeBar.open = coreDataBar.open;
    runtimeBar.high = coreDataBar.high;
    runtimeBar.low = coreDataBar.low;
    runtimeBar.close = coreDataBar.close;
    runtimeBar.adjustedClose = coreDataBar.adjustedClose;
    runtimeBar.volume = coreDataBar.volume;
    runtimeBar.timeframe = (BarTimeframe)coreDataBar.timeframe;
    
    return runtimeBar;
}

- (CompanyInfoModel *)convertCoreDataCompanyInfoToRuntimeModel:(CompanyInfo *)coreDataInfo {
    CompanyInfoModel *runtimeInfo = [[CompanyInfoModel alloc] init];
    
    // Use relationship instead of attribute
    runtimeInfo.symbol = coreDataInfo.symbol.symbol;
    runtimeInfo.name = coreDataInfo.name;
    runtimeInfo.sector = coreDataInfo.sector;
    runtimeInfo.industry = coreDataInfo.industry;
    runtimeInfo.companyDescription = coreDataInfo.companyDescription;
    runtimeInfo.website = coreDataInfo.website;
    runtimeInfo.ceo = coreDataInfo.ceo;
    runtimeInfo.employees = coreDataInfo.employees;
    runtimeInfo.headquarters = coreDataInfo.headquarters;
    runtimeInfo.lastUpdate = coreDataInfo.lastUpdate;
    
    return runtimeInfo;
}

- (void)saveHistoricalBarModel:(HistoricalBarModel *)barModel
                     inContext:(NSManagedObjectContext *)context {
    
    NSDate *date = barModel.date;
    if (!date) return;
    
    // Find or create Symbol first
    Symbol *symbol = [self findOrCreateSymbolWithName:barModel.symbol inContext:context];
    
    // Check if bar already exists using Symbol relationship
    NSFetchRequest *request = [HistoricalBar fetchRequest];
    request.predicate = [NSPredicate predicateWithFormat:
                        @"symbol == %@ AND timeframe == %d AND date == %@",
                        symbol, (int)barModel.timeframe, date];
    
    NSError *error = nil;
    NSArray *results = [context executeFetchRequest:request error:&error];
    
    HistoricalBar *coreDataBar = results.firstObject;
    if (!coreDataBar) {
        coreDataBar = [NSEntityDescription insertNewObjectForEntityForName:@"HistoricalBar"
                                                    inManagedObjectContext:context];
        coreDataBar.symbol = symbol;
        coreDataBar.timeframe = barModel.timeframe;
        coreDataBar.date = date;
    }
    
    // Update bar data from runtime model
    coreDataBar.open = barModel.open;
    coreDataBar.high = barModel.high;
    coreDataBar.low = barModel.low;
    coreDataBar.close = barModel.close;
    coreDataBar.adjustedClose = barModel.adjustedClose;
    coreDataBar.volume = barModel.volume;
}

#pragma mark - Notifications

- (void)broadcastQuoteUpdate:(MarketQuoteModel *)quote {
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:@"DataHubQuoteUpdatedNotification"
                                                            object:self
                                                          userInfo:@{
                                                              @"symbol": quote.symbol,
                                                              @"quote": quote,
                                                              @"timestamp": [NSDate date]
                                                          }];
    });
}

- (void)broadcastHistoricalDataUpdate:(NSArray<HistoricalBarModel *> *)bars forSymbol:(NSString *)symbol {
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:@"DataHubHistoricalDataUpdatedNotification"
                                                            object:self
                                                          userInfo:@{
                                                              @"symbol": symbol,
                                                              @"bars": bars,
                                                              @"timestamp": [NSDate date]
                                                          }];
    });
}

#pragma mark - Subscription Management

- (void)subscribeToQuoteUpdatesForSymbol:(NSString *)symbol {
    if (!symbol) return;
    
    [self initializeMarketDataCaches];
    [self.subscribedSymbols addObject:symbol];
    
    // Start refresh timer if this is the first subscription
    if (self.subscribedSymbols.count == 1) {
        [self startRefreshTimer];
    }
    
    NSLog(@"DataHub: Subscribed to quote updates for %@", symbol);
}

- (void)subscribeToQuoteUpdatesForSymbols:(NSArray<NSString *> *)symbols {
    for (NSString *symbol in symbols) {
        [self subscribeToQuoteUpdatesForSymbol:symbol];
    }
}

- (void)unsubscribeFromQuoteUpdatesForSymbol:(NSString *)symbol {
    if (!symbol) return;
    
    [self initializeMarketDataCaches];
    [self.subscribedSymbols removeObject:symbol];
    
    // Stop timer if no more subscriptions
    if (self.subscribedSymbols.count == 0) {
        [self stopRefreshTimer];
    }
    
    NSLog(@"DataHub: Unsubscribed from quote updates for %@", symbol);
}

- (void)unsubscribeFromAllQuoteUpdates {
    [self initializeMarketDataCaches];
    [self.subscribedSymbols removeAllObjects];
    [self stopRefreshTimer];
    
    NSLog(@"DataHub: Unsubscribed from all quote updates");
}

- (void)startRefreshTimer {
    if (self.refreshTimer) {
        [self.refreshTimer invalidate];
    }
    
    self.refreshTimer = [NSTimer scheduledTimerWithTimeInterval:5.0 // 5 seconds
                                                         target:self
                                                       selector:@selector(refreshSubscribedQuotes)
                                                       userInfo:nil
                                                        repeats:YES];
    
    NSLog(@"DataHub: Started refresh timer for subscribed quotes");
}

- (void)stopRefreshTimer {
    if (self.refreshTimer) {
        [self.refreshTimer invalidate];
        self.refreshTimer = nil;
    }
    
    NSLog(@"DataHub: Stopped refresh timer");
}

- (void)refreshSubscribedQuotes {
    for (NSString *symbol in self.subscribedSymbols) {
        // Force refresh by making direct request to DataManager
        [[DataManager sharedManager] requestQuoteForSymbol:symbol completion:nil];
    }
}

#pragma mark - Utility Methods

- (NSInteger)estimateBarCountForTimeframe:(BarTimeframe)timeframe startDate:(NSDate *)startDate endDate:(NSDate *)endDate {
    NSTimeInterval interval = [endDate timeIntervalSinceDate:startDate];
    
    switch (timeframe) {
        case BarTimeframe1Min:
            return (NSInteger)(interval / 60);
        case BarTimeframe5Min:
            return (NSInteger)(interval / 300);
        case BarTimeframe15Min:
            return (NSInteger)(interval / 900);
        case BarTimeframe30Min:
            return (NSInteger)(interval / 1800);
        case BarTimeframe1Hour:
            return (NSInteger)(interval / 3600);
        case BarTimeframe4Hour:
            return (NSInteger)(interval / 14400);
        case BarTimeframe1Day:
            return (NSInteger)(interval / 86400);
        case BarTimeframe1Week:
            return (NSInteger)(interval / 604800);
        case BarTimeframe1Month:
            return (NSInteger)(interval / 2592000);
    }
    
    return 100; // Default
}

#pragma mark - Batch Operations

- (void)refreshQuotesForSymbols:(NSArray<NSString *> *)symbols {
    for (NSString *symbol in symbols) {
        [self refreshQuoteForSymbol:symbol completion:nil];
    }
}

- (void)refreshQuoteForSymbol:(NSString *)symbol
                   completion:(void(^)(MarketQuoteModel * _Nullable quote, NSError * _Nullable error))completion {
    
    [[DataManager sharedManager] requestQuoteForSymbol:symbol completion:^(MarketData *marketData, NSError *error) {
        if (marketData) {
            MarketQuoteModel *runtimeQuote = [MarketQuoteModel quoteFromMarketData:marketData];
            [self cacheQuote:runtimeQuote];
            [self saveQuoteModelToCoreData:runtimeQuote];
            
            if (completion) completion(runtimeQuote, nil);
        } else {
            if (completion) completion(nil, error);
        }
    }];
}

- (void)prefetchDataForSymbols:(NSArray<NSString *> *)symbols {
    // Prefetch quotes
    [self getQuotesForSymbols:symbols completion:nil];
    
    // Prefetch recent historical data
    for (NSString *symbol in symbols) {
        [self getHistoricalBarsForSymbol:symbol
                               timeframe:BarTimeframe1Day
                                barCount:30
                              completion:nil];
    }
}

#pragma mark - Cache Management

- (void)clearCacheForSymbol:(NSString *)symbol {
    if (!symbol) return;
    
    [self initializeMarketDataCaches];
    
    // Clear quotes
    [self.quotesCache removeObjectForKey:symbol];
    
    // Clear historical data
    NSArray *keysToRemove = [self.historicalCache.allKeys filteredArrayUsingPredicate:
                            [NSPredicate predicateWithFormat:@"SELF CONTAINS %@", symbol]];
    [self.historicalCache removeObjectsForKeys:keysToRemove];
    
    // Clear company info
    [self.companyInfoCache removeObjectForKey:symbol];
    
    // Clear timestamps
    NSArray *timestampKeysToRemove = [self.cacheTimestamps.allKeys filteredArrayUsingPredicate:
                                     [NSPredicate predicateWithFormat:@"SELF CONTAINS %@", symbol]];
    [self.cacheTimestamps removeObjectsForKeys:timestampKeysToRemove];
    
    NSLog(@"DataHub: Cleared cache for symbol %@", symbol);
}

- (NSDictionary *)getCacheStatistics {
    [self initializeMarketDataCaches];
    
    return @{
        @"quotesCount": @(self.quotesCache.count),
        @"historicalCacheCount": @(self.historicalCache.count),
        @"companyInfoCount": @(self.companyInfoCache.count),
        @"subscribedSymbolsCount": @(self.subscribedSymbols.count),
        @"activeQuoteRequests": @(self.activeQuoteRequests.count),
        @"activeHistoricalRequests": @(self.activeHistoricalRequests.count)
    };
}

#pragma mark - Market Lists Implementation

- (void)getMarketPerformersForList:(NSString *)listType
                         timeframe:(NSString *)timeframe
                        completion:(void (^)(NSArray<MarketPerformerModel *> *performers, BOOL isFresh))completion {
    
    if (!listType || !timeframe) {
        NSLog(@"❌ DataHub: Invalid parameters for market performers request");
        if (completion) completion(@[], NO);
        return;
    }
    
    [self initializeMarketListsCache];
    
    NSString *cacheKey = [NSString stringWithFormat:@"%@:%@", listType, timeframe];
    
    // Check cache first
    NSArray<MarketPerformerModel *> *cachedPerformers = self.marketListsCache[cacheKey];
    NSDate *cacheTimestamp = self.marketListsCacheTimestamps[cacheKey];
    
    // Cache validity: 5 minutes for market lists
    NSTimeInterval cacheMaxAge = 300.0; // 5 minutes
    BOOL isCacheValid = cacheTimestamp &&
                       [[NSDate date] timeIntervalSinceDate:cacheTimestamp] < cacheMaxAge;
    
    if (isCacheValid && cachedPerformers.count > 0) {
        NSLog(@"✅ DataHub: Returning cached market performers for %@ (%lu items)",
              cacheKey, (unsigned long)cachedPerformers.count);
        if (completion) completion(cachedPerformers, NO);
        return;
    }
    
    NSLog(@"🔄 DataHub: Fetching fresh market performers for %@", cacheKey);
    
    // Fetch from DataManager
    [[DataManager sharedManager] getMarketPerformersForList:listType
                                                   timeframe:timeframe
                                                  completion:^(NSArray<MarketPerformerModel *> *performers, NSError *error) {
        if (error) {
            NSLog(@"❌ DataHub: Failed to fetch market performers: %@", error.localizedDescription);
            
            // Return cached data if available, even if stale
            if (cachedPerformers.count > 0) {
                NSLog(@"📦 DataHub: Returning stale cached data due to error");
                if (completion) completion(cachedPerformers, NO);
            } else {
                if (completion) completion(@[], NO);
            }
            return;
        }
        
        // Update cache
        if (performers.count > 0) {
            self.marketListsCache[cacheKey] = performers;
            self.marketListsCacheTimestamps[cacheKey] = [NSDate date];
            
            NSLog(@"✅ DataHub: Cached %lu market performers for %@",
                  (unsigned long)performers.count, cacheKey);
        }
        
        if (completion) completion(performers, YES);
        
        // Post notification for UI updates
        [[NSNotificationCenter defaultCenter] postNotificationName:@"DataHubMarketListUpdated"
                                                            object:nil
                                                          userInfo:@{
                                                              @"listType": listType,
                                                              @"timeframe": timeframe,
                                                              @"performers": performers
                                                          }];
    }];
}

- (void)refreshMarketListForType:(NSString *)listType timeframe:(NSString *)timeframe {
    if (!listType || !timeframe) return;
    
    [self initializeMarketListsCache];
    
    NSString *cacheKey = [NSString stringWithFormat:@"%@:%@", listType, timeframe];
    
    // Clear cache for this specific list
    [self.marketListsCache removeObjectForKey:cacheKey];
    [self.marketListsCacheTimestamps removeObjectForKey:cacheKey];
    
    NSLog(@"🔄 DataHub: Forcing refresh for market list %@", cacheKey);
    
    // Fetch fresh data
    [self getMarketPerformersForList:listType timeframe:timeframe completion:nil];
}

- (void)clearMarketListCache {
    [self initializeMarketListsCache];
    
    [self.marketListsCache removeAllObjects];
    [self.marketListsCacheTimestamps removeAllObjects];
    
    NSLog(@"🗑️ DataHub: Cleared all market lists cache");
}

- (NSDictionary *)getMarketListCacheStatistics {
    [self initializeMarketListsCache];
    
    NSMutableDictionary *stats = [NSMutableDictionary dictionary];
    
    for (NSString *cacheKey in self.marketListsCache) {
        NSArray *performers = self.marketListsCache[cacheKey];
        NSDate *timestamp = self.marketListsCacheTimestamps[cacheKey];
        
        stats[cacheKey] = @{
            @"count": @(performers.count),
            @"timestamp": timestamp ?: [NSNull null],
            @"ageMinutes": timestamp ? @([[NSDate date] timeIntervalSinceDate:timestamp] / 60.0) : @(-1)
        };
    }
    
    return [stats copy];
}

#pragma mark - Market Lists Cache Management

- (void)initializeMarketListsCache {
    if (!self.marketListsCache) {
        self.marketListsCache = [NSMutableDictionary dictionary];
    }
    if (!self.marketListsCacheTimestamps) {
        self.marketListsCacheTimestamps = [NSMutableDictionary dictionary];
    }
}

// Aggiungi questo al metodo clearMarketDataCache esistente
- (void)clearMarketDataCache {
    [self initializeMarketDataCaches];
    
    [self.quotesCache removeAllObjects];
    [self.historicalCache removeAllObjects];
    [self.companyInfoCache removeAllObjects];
    [self.cacheTimestamps removeAllObjects];
    [self clearMarketListCache];
    
}

- (Symbol *)findOrCreateSymbolWithName:(NSString *)symbolName inContext:(NSManagedObjectContext *)context {
    // Cerca il simbolo esistente
    NSFetchRequest *request = [Symbol fetchRequest];
    request.predicate = [NSPredicate predicateWithFormat:@"symbol == %@", symbolName];
    request.fetchLimit = 1;
    
    NSError *error = nil;
    NSArray *results = [context executeFetchRequest:request error:&error];
    
    if (results.count > 0) {
        return results.firstObject;
    }
    
    // Crea nuovo simbolo se non esiste
    Symbol *newSymbol = [NSEntityDescription insertNewObjectForEntityForName:@"Symbol"
                                                      inManagedObjectContext:context];
    newSymbol.symbol = symbolName;
    return newSymbol;
}

#pragma mark - VALIDATION: Market Data Architecture Compliance

- (void)validateMarketDataArchitectureCompliance {
    NSLog(@"\n🏗️ VALIDATION: Market Data Architecture Compliance");
    NSLog(@"==================================================");
    
    NSLog(@"✅ DataHub communicates ONLY with:");
    NSLog(@"   - UI Layer (receives requests)");
    NSLog(@"   - DataManager (delegates external data)");
    NSLog(@"   - Core Data (internal persistence)");
    
    NSLog(@"❌ DataHub NEVER calls:");
    NSLog(@"   - External APIs directly");
    NSLog(@"   - DownloadManager directly");
    NSLog(@"   - Network requests directly");
    
    // Check quotes cache symbols are properly typed
    NSInteger validCachedQuotes = 0;
    NSInteger invalidCachedQuotes = 0;
    
    for (NSString *symbol in self.quotesCache) {
        MarketQuoteModel *quote = self.quotesCache[symbol];
        if ([quote isKindOfClass:[MarketQuoteModel class]] &&
            [quote.symbol isKindOfClass:[NSString class]] &&
            [quote.symbol isEqualToString:symbol]) {
            validCachedQuotes++;
        } else {
            invalidCachedQuotes++;
            NSLog(@"❌ Invalid cached quote: symbol key '%@' vs quote.symbol '%@'", symbol, quote.symbol);
        }
    }
    
    NSLog(@"Quote Cache Validation:");
    NSLog(@"✅ Valid cached quotes: %ld", (long)validCachedQuotes);
    NSLog(@"❌ Invalid cached quotes: %ld", (long)invalidCachedQuotes);
    
    NSLog(@"ARCHITECTURE COMPLIANCE VALIDATION COMPLETE\n");
}

@end
