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

- (NSTimeInterval)TTLForDataType:(DataCacheType)type {
    switch (type) {
        case DataCacheTypeQuote:
            return 10.0; // 10 seconds for quotes
        case DataCacheTypeMarketOverview:
            return 300.0; // 5 minutes
        case DataCacheTypeHistorical:
            return 300.0; // 5 minutes
        case DataCacheTypeCompanyInfo:
            return 86400.0; // 24 hours
        case DataCacheTypeWatchlist:
            return INFINITY; // Never expires
    }
    return 300.0; // Default 5 minutes
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
    
    if (symbolEntity) {
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
    
    NSMutableArray<NSString *> *validSymbols = [NSMutableArray array];
    for (id obj in symbols) {
        if ([obj isKindOfClass:[NSString class]]) {
            NSString *symbol = (NSString *)obj;
            if (symbol.length > 0) {
                [validSymbols addObject:symbol.uppercaseString];
            }
        }
    }
    
    if (validSymbols.count == 0) {
        completion(@{}, NO);
        return;
    }
    
    NSLog(@"📊 DataHub: Getting quotes for %lu symbols", (unsigned long)validSymbols.count);
    
    // Check cache first
    NSMutableDictionary<NSString *, MarketQuoteModel *> *cachedQuotes = [NSMutableDictionary dictionary];
    NSMutableArray<NSString *> *symbolsToFetch = [NSMutableArray array];
    
    [self initializeMarketDataCaches];
    
    for (NSString *symbol in validSymbols) {
        MarketQuoteModel *cachedQuote = self.quotesCache[symbol];
        if (cachedQuote && ![self isCacheStale:symbol dataType:DataCacheTypeQuote]) {
            cachedQuotes[symbol] = cachedQuote;
        } else {
            [symbolsToFetch addObject:symbol];
        }
    }
    
    if (symbolsToFetch.count == 0) {
        completion([cachedQuotes copy], YES);
        return;
    }
    
    // CORREZIONE: Usare requestBatchQuotesForSymbols invece del metodo obsoleto
    [[DataManager sharedManager] requestQuotesForSymbols:symbolsToFetch
                                              completion:^(NSDictionary *rawQuotes, NSError *error) {

    
            if (error) {
                NSLog(@"❌ Error fetching quotes from DataManager: %@", error);
                completion([cachedQuotes copy], NO);
                return;
            }
            
            NSMutableDictionary<NSString *, MarketQuoteModel *> *allQuotes = [cachedQuotes mutableCopy];
            
            for (NSString *symbol in rawQuotes) {
                id quoteData = rawQuotes[symbol];
                MarketQuoteModel *runtimeQuote = nil;
                
                if ([quoteData isKindOfClass:[MarketQuoteModel class]]) {
                    runtimeQuote = (MarketQuoteModel *)quoteData;
                } else if ([quoteData isKindOfClass:[MarketData class]]) {
                    MarketData *marketData = (MarketData *)quoteData;
                    runtimeQuote = [MarketQuoteModel quoteFromMarketData:marketData];
                } else if ([quoteData isKindOfClass:[NSDictionary class]]) {
                    runtimeQuote = [MarketQuoteModel quoteFromDictionary:(NSDictionary *)quoteData];
                }
                
                if (runtimeQuote) {
                    [self cacheQuote:runtimeQuote];
                    [self updateCacheTimestamp:symbol];
                    [self saveQuoteModelToCoreData:runtimeQuote];
                    allQuotes[symbol] = runtimeQuote;
                }
            }
            
            completion([allQuotes copy], symbolsToFetch.count == 0);
        }];
}

#pragma mark - Public API - Historical Data

- (void)getHistoricalBarsForSymbol:(NSString *)symbol
                         timeframe:(BarTimeframe)timeframe
                          barCount:(NSInteger)barCount
                  needExtendedHours:(BOOL)needExtendedHours
                        completion:(void (^)(NSArray<HistoricalBarModel *> *bars, BOOL isFresh))completion {
    
    if (!completion) return;
    
    [self initializeMarketDataCaches];
    
    NSString *cacheKey = [NSString stringWithFormat:@"historical_%@_%ld_%ld_%@",
                          symbol, (long)timeframe, (long)barCount, needExtendedHours ? @"extended" : @"regular"];
    
    // Check cache
    NSArray<HistoricalBarModel *> *cachedBars = self.historicalCache[cacheKey];
    if (cachedBars && ![self isCacheStale:cacheKey dataType:DataCacheTypeHistorical]) {
        completion(cachedBars, YES);
        return;
    }
    
    // Return stale data first if available
    if (cachedBars) {
        completion(cachedBars, NO);
    }
    
    // CORREZIONE: Usare requestHistoricalBarsForSymbol invece del metodo obsoleto
    [[DataManager sharedManager] requestHistoricalDataForSymbol:symbol
                                                      timeframe:timeframe
                                                          count:barCount
                                                     completion:^(NSArray<HistoricalBarModel *> *bars, NSError *error) {

        if (error) {
            NSLog(@"❌ DataHub: Failed to get historical data: %@", error);
            if (!cachedBars) {
                completion(@[], NO);
            }
            return;
        }
        
        // Cache and return fresh data
        @synchronized(self.historicalCache) {
            self.historicalCache[cacheKey] = bars ?: @[];
            [self updateCacheTimestamp:cacheKey];
        }
        
        [self saveHistoricalBarsModelToCoreData:bars ?: @[] symbol:symbol timeframe:timeframe];
        [self broadcastHistoricalDataUpdate:bars ?: @[] forSymbol:symbol];
        
        completion(bars ?: @[], YES);
    }];
}

- (void)loadHistoricalDataFromCoreDataSafely:(NSString *)symbol
                                   timeframe:(BarTimeframe)timeframe
                                    barCount:(NSInteger)barCount
                           needExtendedHours:(BOOL)needExtendedHours
                                  completion:(void(^)(NSArray<HistoricalBarModel *> *bars))completion {
    
    if (!completion || !symbol) {
        if (completion) completion(@[]);
        return;
    }
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSManagedObjectContext *backgroundContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
        backgroundContext.parentContext = self.mainContext;
        
        [backgroundContext performBlock:^{
            NSFetchRequest *symbolRequest = [Symbol fetchRequest];
            symbolRequest.predicate = [NSPredicate predicateWithFormat:@"symbol == %@", symbol];
            
            NSError *error = nil;
            NSArray *symbolResults = [backgroundContext executeFetchRequest:symbolRequest error:&error];
            
            if (error || symbolResults.count == 0) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    completion(@[]);
                });
                return;
            }
            
            Symbol *symbolEntity = symbolResults.firstObject;
            
            // ✅ IMPROVED: Fetch con ordinamento e limit per evitare duplicati
            NSFetchRequest *barsRequest = [HistoricalBar fetchRequest];
            barsRequest.predicate = [NSPredicate predicateWithFormat:
                                   @"symbol == %@ AND timeframe == %d", symbolEntity, (int)timeframe];
            
            // Ordina per data (ascending per poi prendere le ultime)
            NSSortDescriptor *dateSort = [NSSortDescriptor sortDescriptorWithKey:@"date" ascending:YES];
            barsRequest.sortDescriptors = @[dateSort];
            
            // ✅ PERFORMANCE: Fetch solo quello che serve
            barsRequest.fetchLimit = barCount * 2; // Un po' di buffer per sicurezza
            
            NSArray *coreDataBars = [backgroundContext executeFetchRequest:barsRequest error:&error];
            
            if (error) {
                NSLog(@"❌ Error loading historical bars from Core Data: %@", error);
                dispatch_async(dispatch_get_main_queue(), ^{
                    completion(@[]);
                });
                return;
            }
            
            // ✅ DEDUPLICATION: Rimuovi duplicati già in Core Data
            NSArray *deduplicatedBars = [self deduplicateCoreDataBars:coreDataBars];
            
            // Convert to runtime models
            NSMutableArray<HistoricalBarModel *> *runtimeBars = [NSMutableArray array];
            for (HistoricalBar *coreDataBar in deduplicatedBars) {
                HistoricalBarModel *runtimeBar = [self convertCoreDataBarToRuntimeModel:coreDataBar];
                if (runtimeBar) {
                    [runtimeBars addObject:runtimeBar];
                }
            }
            
            // Take only the most recent bars if we have more than requested
            if (runtimeBars.count > barCount) {
                NSRange range = NSMakeRange(runtimeBars.count - barCount, barCount);
                runtimeBars = [[runtimeBars subarrayWithRange:range] mutableCopy];
            }
            
            NSLog(@"📦 DataHub: Loaded %lu bars from Core Data for %@ (timeframe: %ld)",
                  (unsigned long)runtimeBars.count, symbol, (long)timeframe);
            
            dispatch_async(dispatch_get_main_queue(), ^{
                completion([runtimeBars copy]);
            });
        }];
    });
}

#pragma mark - Smart Update Implementation (Private Methods)

/**
 * 🎯 CORE DELLA SMART LOGIC: Aggiorna solo le barre mancanti
 */
- (void)performSmartUpdateForSymbol:(NSString *)symbol
                          timeframe:(BarTimeframe)timeframe
                           barCount:(NSInteger)barCount
                  needExtendedHours:(BOOL)needExtendedHours
                         cachedBars:(NSArray<HistoricalBarModel *> *)cachedBars
                           cacheKey:(NSString *)cacheKey
                         completion:(void (^)(NSArray<HistoricalBarModel *> *bars, BOOL isFresh))completion {
    
    // ============================================================================
    // 🚀 STEP 1: VALIDAZIONI PRELIMINARI per decidere SMART vs FULL REQUEST
    // ============================================================================
    
    // Find last bar date in cache
    HistoricalBarModel *lastBar = [cachedBars lastObject];
    HistoricalBarModel *firstBar = [cachedBars firstObject];
    NSDate *lastCacheDate = lastBar.date;
    NSDate *firstCacheDate = firstBar.date;
    
    if (!lastCacheDate || !firstCacheDate) {
        NSLog(@"❌ DataHub SMART: Invalid cache dates, performing full request");
        [self performFullHistoricalRequest:symbol timeframe:timeframe barCount:barCount
                         needExtendedHours:needExtendedHours cacheKey:cacheKey completion:completion];
        return;
    }
    
    // ============================================================================
    // 🔍 VALIDAZIONE 1: EXTENDED HOURS COMPATIBILITY
    // ============================================================================
    
    // Estrai flag extended dalla cache key esistente
    BOOL cacheHasExtended = [cacheKey containsString:@"_ext"];
    
    if (needExtendedHours != cacheHasExtended) {
        NSLog(@"🔄 DataHub SMART → FULL: Extended hours mismatch (cache: %@, requested: %@)",
              cacheHasExtended ? @"extended" : @"regular",
              needExtendedHours ? @"extended" : @"regular");
        
        [self performFullHistoricalRequest:symbol timeframe:timeframe barCount:barCount
                         needExtendedHours:needExtendedHours cacheKey:cacheKey completion:completion];
        return;
    }
    
    // ============================================================================
    // 🔍 VALIDAZIONE 2: RANGE COMPATIBILITY (barCount)
    // ============================================================================
    
    NSInteger cachedBarCount = cachedBars.count;
    
    // Se richiediamo più barre di quelle in cache, dobbiamo verificare se possiamo estendere
    if (barCount > cachedBarCount) {
        NSLog(@"🔄 DataHub SMART → FULL: Requested bars (%ld) > cached bars (%ld)",
              (long)barCount, (long)cachedBarCount);
        
        [self performFullHistoricalRequest:symbol timeframe:timeframe barCount:barCount
                         needExtendedHours:needExtendedHours cacheKey:cacheKey completion:completion];
        return;
    }
    
    // ============================================================================
    // 🔍 VALIDAZIONE 3: DATE RANGE COMPATIBILITY (per richieste con startDate)
    // ============================================================================
    
    // Calcola il range temporale richiesto basandosi su barCount e timeframe
    NSTimeInterval barIntervalSeconds = [self secondsPerBarForTimeframe:timeframe];
    NSTimeInterval requestedRangeSeconds = barCount * barIntervalSeconds;
    NSDate *requestedStartDate = [NSDate dateWithTimeIntervalSinceNow:-requestedRangeSeconds];
    
    // Verifica se il range richiesto va oltre i dati in cache
    NSTimeInterval cacheRangeSeconds = [lastCacheDate timeIntervalSinceDate:firstCacheDate];
    NSTimeInterval requestedRangeFromCache = [lastCacheDate timeIntervalSinceDate:requestedStartDate];
    
    // Se la richiesta va più indietro dei dati in cache, serve full request
    if (requestedRangeFromCache > cacheRangeSeconds + (barIntervalSeconds * 10)) { // 10 bars di tolleranza
        NSLog(@"🔄 DataHub SMART → FULL: Requested range extends beyond cache");
        NSLog(@"   Cache range: %.1f hours, Requested range: %.1f hours",
              cacheRangeSeconds / 3600.0, requestedRangeFromCache / 3600.0);
        
        [self performFullHistoricalRequest:symbol timeframe:timeframe barCount:barCount
                         needExtendedHours:needExtendedHours cacheKey:cacheKey completion:completion];
        return;
    }
    
    // ============================================================================
    // ✅ VALIDAZIONI SUPERATE: PROCEDI CON SMART UPDATE
    // ============================================================================
    
    NSLog(@"✅ DataHub SMART: All validations passed, proceeding with smart update");
    NSLog(@"   Extended: %@, Cache bars: %ld, Requested: %ld",
          needExtendedHours ? @"YES" : @"NO", (long)cachedBarCount, (long)barCount);
    
    // 🧠 SMART CALCULATION: GoBack period based on timeframe
    NSInteger goBackBars = [self getGoBackPeriodForTimeframe:timeframe];
    NSTimeInterval goBackSeconds = goBackBars * barIntervalSeconds;
    
    // Smart date range: last cache date - goback to NOW
    NSDate *smartStartDate = [lastCacheDate dateByAddingTimeInterval:-goBackSeconds];
    NSDate *smartEndDate = [[NSDate date] dateByAddingTimeInterval:60*60*24];
    
    NSLog(@"🎯 DataHub SMART: Updating %@ from %@ to %@ (goback: %ld bars)",
          symbol, smartStartDate, smartEndDate, (long)goBackBars);
    
    // Smart API call for only missing bars
    [[DataManager sharedManager] requestHistoricalDataForSymbol:symbol
                                                      timeframe:timeframe
                                                      startDate:smartStartDate
                                                        endDate:smartEndDate
                                              needExtendedHours:needExtendedHours
                                                     completion:^(NSArray<HistoricalBarModel *> *newBars, NSError *error) {
        
        if (error) {
            NSLog(@"❌ DataHub SMART: Smart update failed for %@: %@", symbol, error.localizedDescription);
            completion(cachedBars, NO); // Return cached data as fallback
            return;
        }
        
        if (!newBars || newBars.count == 0) {
            NSLog(@"⚠️ DataHub SMART: No new bars received for %@, returning cached data", symbol);
            completion(cachedBars, YES); // Cache is still valid
            return;
        }
        
        // 🔧 MERGE: Intelligent merging with duplicate removal
        NSArray<HistoricalBarModel *> *mergedBars = [self mergeHistoricalBars:cachedBars
                                                                  withNewBars:newBars
                                                                     barCount:barCount];
        
        // Update cache with merged data
        @synchronized(self.historicalCache) {
            self.historicalCache[cacheKey] = mergedBars;
            [self updateCacheTimestamp:cacheKey];
        }
        
        NSLog(@"✅ DataHub SMART: Updated cache for %@ (%lu total bars, %lu new)",
              symbol, (unsigned long)mergedBars.count, (unsigned long)newBars.count);
        
        // Broadcast update and send fresh data
        [self broadcastHistoricalDataUpdate:mergedBars forSymbol:symbol];
        completion(mergedBars, YES);
    }];
}


/**
 * 🧮 GOBACK PERIOD CALCULATION per timeframe
 */
- (NSInteger)getGoBackPeriodForTimeframe:(BarTimeframe)timeframe {
    // Configurabile via UserDefaults per fine-tuning
    NSDictionary *customGoBackPeriods = [[NSUserDefaults standardUserDefaults]
                                        dictionaryForKey:@"SmartCacheGoBackPeriods"];
    
    if (customGoBackPeriods) {
        NSNumber *customPeriod = customGoBackPeriods[@(timeframe)];
        if (customPeriod) {
            return customPeriod.integerValue;
        }
    }
    
    // 🎯 DEFAULT VALUES come da tua proposta:
    switch (timeframe) {
        case BarTimeframe1Min:
            return 4; // 4 barre indietro per 1min (es: 10:31 -> 10:28)
            
        case BarTimeframe5Min:
        case BarTimeframe15Min:
        case BarTimeframe30Min:
        case BarTimeframe1Hour:
        case BarTimeframe4Hour:
            return 2; // 2 barre indietro per altri intraday
            
        case BarTimeframeDaily:
        case BarTimeframeWeekly:
        case BarTimeframeMonthly:
        default:
            return 1; // 1 barra indietro per daily+
    }
}

/**
 * ⏱️ SECONDS PER BAR calculation
 */
- (NSTimeInterval)secondsPerBarForTimeframe:(BarTimeframe)timeframe {
    switch (timeframe) {
        case BarTimeframe1Min:   return 60;        // 1 minuto
        case BarTimeframe5Min:   return 300;       // 5 minuti
        case BarTimeframe15Min:  return 900;       // 15 minuti
        case BarTimeframe30Min:  return 1800;      // 30 minuti
        case BarTimeframe1Hour:  return 3600;      // 1 ora
        case BarTimeframe4Hour:  return 14400;     // 4 ore
        case BarTimeframeDaily:   return 86400;     // 1 giorno
        case BarTimeframeWeekly:  return 604800;    // 1 settimana
        case BarTimeframeMonthly: return 2592000;   // ~30 giorni
        default: return 60;
    }
}

/**
 * 🔧 INTELLIGENT MERGE di cache esistente + nuove barre
 */
- (NSArray<HistoricalBarModel *> *)mergeHistoricalBars:(NSArray<HistoricalBarModel *> *)cachedBars
                                           withNewBars:(NSArray<HistoricalBarModel *> *)newBars
                                              barCount:(NSInteger)barCount {
    
    if (!newBars || newBars.count == 0) {
        return cachedBars ?: @[];
    }
    
    if (!cachedBars || cachedBars.count == 0) {
        return [self limitBarsToCount:newBars maxCount:barCount];
    }
    
    NSMutableArray<HistoricalBarModel *> *allBars = [NSMutableArray array];
    
    // 1. Add all cached bars
    [allBars addObjectsFromArray:cachedBars];
    
    // 2. Add new bars with precise duplicate detection
    for (HistoricalBarModel *newBar in newBars) {
        if (![self isBarDuplicate:newBar inArray:cachedBars]) {
            [allBars addObject:newBar];
        }
    }
    
    // 3. Sort chronologically (oldest to newest)
    [allBars sortUsingComparator:^NSComparisonResult(HistoricalBarModel *bar1, HistoricalBarModel *bar2) {
        return [bar1.date compare:bar2.date];
    }];
    
    // 4. Final pass: remove any remaining duplicates after sorting
    NSArray<HistoricalBarModel *> *finalBars = [self removeDuplicatesFromSortedBars:allBars];
    
    // 5. Limit to requested count
    finalBars = [self limitBarsToCount:finalBars maxCount:barCount];
    
    NSLog(@"🔄 DataHub SMART MERGE: %lu cached + %lu new = %lu final (duplicates removed)",
          (unsigned long)cachedBars.count, (unsigned long)newBars.count, (unsigned long)finalBars.count);
    
    return finalBars;
}

- (BOOL)isBarDuplicate:(HistoricalBarModel *)bar inArray:(NSArray<HistoricalBarModel *> *)array {
    for (HistoricalBarModel *existingBar in array) {
        if ([self areBarsEqual:bar other:existingBar]) {
            return YES;
        }
    }
    return NO;
}
- (BOOL)areBarsEqual:(HistoricalBarModel *)bar1 other:(HistoricalBarModel *)bar2 {
    if (!bar1.date || !bar2.date) return NO;
    
    // ✅ PRECISE: Date comparison with 30-second tolerance for safety
    NSTimeInterval timeDiff = fabs([bar1.date timeIntervalSinceDate:bar2.date]);
    return timeDiff < 30.0;
}

- (NSArray<HistoricalBarModel *> *)removeDuplicatesFromSortedBars:(NSArray<HistoricalBarModel *> *)sortedBars {
    if (sortedBars.count <= 1) return sortedBars;
    
    NSMutableArray<HistoricalBarModel *> *deduplicatedBars = [NSMutableArray arrayWithObject:sortedBars.firstObject];
    
    for (NSInteger i = 1; i < sortedBars.count; i++) {
        HistoricalBarModel *currentBar = sortedBars[i];
        HistoricalBarModel *previousBar = deduplicatedBars.lastObject;
        
        if (![self areBarsEqual:currentBar other:previousBar]) {
            [deduplicatedBars addObject:currentBar];
        }
    }
    
    return [deduplicatedBars copy];
}

- (NSArray<HistoricalBarModel *> *)limitBarsToCount:(NSArray<HistoricalBarModel *> *)bars maxCount:(NSInteger)maxCount {
    if (bars.count <= maxCount) return bars;
    
    // Take the most recent bars
    NSRange range = NSMakeRange(bars.count - maxCount, maxCount);
    return [bars subarrayWithRange:range];
}

- (NSArray<HistoricalBar *> *)deduplicateCoreDataBars:(NSArray<HistoricalBar *> *)coreDataBars {
    if (coreDataBars.count <= 1) return coreDataBars;
    
    NSMutableArray<HistoricalBar *> *deduplicatedBars = [NSMutableArray array];
    
    for (HistoricalBar *bar in coreDataBars) {
        BOOL isDuplicate = NO;
        
        for (HistoricalBar *existingBar in deduplicatedBars) {
            if (existingBar.date && bar.date) {
                NSTimeInterval timeDiff = fabs([existingBar.date timeIntervalSinceDate:bar.date]);
                if (timeDiff < 30.0) { // 30 second tolerance
                    isDuplicate = YES;
                    break;
                }
            }
        }
        
        if (!isDuplicate) {
            [deduplicatedBars addObject:bar];
        }
    }
    
    return [deduplicatedBars copy];
}
/**
 * 📡 FULL REQUEST fallback (unchanged from original)
 */
- (void)performFullHistoricalRequest:(NSString *)symbol
                           timeframe:(BarTimeframe)timeframe
                            barCount:(NSInteger)barCount
                   needExtendedHours:(BOOL)needExtendedHours
                            cacheKey:(NSString *)cacheKey
                          completion:(void (^)(NSArray<HistoricalBarModel *> *bars, BOOL isFresh))completion {
    
    NSLog(@"📡 DataHub: Performing full historical request for %@ (%ld bars)", symbol, (long)barCount);
    
    // Original logic - full request via DataManager
    [[DataManager sharedManager] requestHistoricalDataForSymbol:symbol
                                                      timeframe:timeframe
                                                          count:barCount
                                              needExtendedHours:needExtendedHours
                                                     completion:^(NSArray<HistoricalBarModel *> *bars, NSError *error) {
        
        if (error) {
            NSLog(@"❌ DataHub: Full historical request failed for %@: %@", symbol, error.localizedDescription);
            completion(@[], NO);
            return;
        }
        
        // Cache and return
        @synchronized(self.historicalCache) {
            self.historicalCache[cacheKey] = bars ?: @[];
            [self updateCacheTimestamp:cacheKey];
        }
        
        [self broadcastHistoricalDataUpdate:bars forSymbol:symbol];
        completion(bars ?: @[], YES);
    }];
}


- (void)loadHistoricalDataFromCoreData:(NSString *)symbol
                             timeframe:(BarTimeframe)timeframe
                              barCount:(NSInteger)barCount
                      needExtendedHours:(BOOL)needExtendedHours
                            completion:(void (^)(NSArray<HistoricalBarModel *> *bars))completion {
    
    // Implementation should filter Core Data based on extended hours flag
    // This would require updating the Core Data model to store this information
    // For now, call existing method and add TODO
    
    // TODO: Update Core Data schema to include extended_hours flag
    [self loadHistoricalDataFromCoreData:symbol
                               timeframe:timeframe
                                barCount:barCount
                              completion:completion];
}

- (void)saveHistoricalDataToCoreData:(NSArray<HistoricalBarModel *> *)bars
                              symbol:(NSString *)symbol
                           timeframe:(BarTimeframe)timeframe
                    needExtendedHours:(BOOL)needExtendedHours {
    
    // TODO: Save with extended hours flag to Core Data
    // For now, call existing method
    [self saveHistoricalBarsModelToCoreData:bars symbol:symbol timeframe:timeframe];
}



// AGGIUNGERE ANCHE questo metodo helper per supportare needExtendedHours:
- (void)getHistoricalBarsForSymbol:(NSString *)symbol
                         timeframe:(BarTimeframe)timeframe
                         startDate:(NSDate *)startDate
                           endDate:(NSDate *)endDate
                  needExtendedHours:(BOOL)needExtendedHours
                        completion:(void(^)(NSArray<HistoricalBarModel *> *bars, BOOL isFresh))completion {
    
    if (!symbol || !startDate || !endDate || !completion) {
        NSLog(@"❌ DataHub: Invalid parameters for date range request with extended hours");
        if (completion) completion(@[], NO);
        return;
    }
    
    [self initializeMarketDataCaches];
    
    // Valida date range
    if ([startDate compare:endDate] != NSOrderedAscending) {
        NSLog(@"❌ DataHub: Invalid date range - start date must be before end date");
        if (completion) completion(@[], NO);
        return;
    }
    __block NSArray<HistoricalBarModel *> *resultBars = nil;
    
    NSLog(@"🔬 DataHub: Date range request for %@ from %@ to %@ (timeframe: %ld, extended: %@)",
          symbol, startDate, endDate, (long)timeframe, needExtendedHours ? @"YES" : @"NO");
    
    // Crea cache key che include flag extended hours
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    dateFormatter.dateFormat = @"yyyyMMdd";
    NSString *startDateStr = [dateFormatter stringFromDate:startDate];
    NSString *endDateStr = [dateFormatter stringFromDate:endDate];
    
    NSString *cacheKey = [NSString stringWithFormat:@"historical_range_%@_%ld_%@_%@_%@",
                          symbol, (long)timeframe, startDateStr, endDateStr,
                          needExtendedHours ? @"ext" : @"reg"];
    
    // 1. Controlla cache
    @synchronized(self.historicalCache) {
            NSArray<HistoricalBarModel *> *cachedBars = self.historicalCache[cacheKey];
            if (cachedBars && ![self isCacheStale:cacheKey dataType:DataCacheTypeHistorical]) {
                NSLog(@"✅ DataHub: Returning cached date range data (%lu bars)", (unsigned long)cachedBars.count);
                completion(cachedBars, NO);
                return;
            }
        }
    
    // 2. Fai richiesta diretta a DataManager per date range
    [[DataManager sharedManager] requestHistoricalDataForSymbol:symbol
                                                      timeframe:timeframe
                                                      startDate:startDate
                                                        endDate:endDate
                                              needExtendedHours:needExtendedHours
                                                     completion:^(NSArray<HistoricalBarModel *> *bars, NSError *error) {
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if (error) {
                NSLog(@"❌ DataHub: Date range request failed for %@: %@", symbol, error.localizedDescription);
                completion(@[], NO);
                return;
            }
            
            resultBars = bars ?: @[];
            
            NSLog(@"✅ DataHub: Received %lu bars for date range %@ to %@ (extended: %@)",
                  (unsigned long)bars.count, startDate, endDate, needExtendedHours ? @"YES" : @"NO");
            
            // 3. Salva in cache
            @synchronized(self.historicalCache) {
                self.historicalCache[cacheKey] = bars;
                [self updateCacheTimestamp:cacheKey];
            }
            
            // 4. Opzionalmente salva in Core Data per future lookup
            if (bars.count > 0) {
                [self saveHistoricalDataToCoreData:bars symbol:symbol timeframe:timeframe needExtendedHours:needExtendedHours];
            }
            
            // 5. Broadcast update
            [self broadcastHistoricalDataUpdate:bars forSymbol:symbol];
            
            // 6. Return fresh data
            completion(bars, YES);
        });
    }];
}
#pragma mark - Public API - Company Info

- (void)getCompanyInfoForSymbol:(NSString *)symbol
                     completion:(void(^)(CompanyInfoModel * _Nullable info, BOOL isFresh))completion {
    
    if (!symbol || !completion) return;
    
    [self initializeMarketDataCaches];
    
    // 1. Check memory cache
    CompanyInfoModel *cachedInfo = self.companyInfoCache[symbol];
    NSString *cacheKey = [NSString stringWithFormat:@"company_%@", symbol];
    BOOL isStale = [self isCacheStale:cacheKey dataType:DataCacheTypeCompanyInfo];
    
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
    BarTimeframe timeframe = bars.firstObject ? bars.firstObject.timeframe : BarTimeframeDaily;
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
            
            // ✅ FIX: CAMBIATO DA ascending:NO A ascending:YES per mantenere
            // la coerenza con l'ordine originale di Schwab (più antica → più recente)
            NSSortDescriptor *sortDescriptor = [NSSortDescriptor sortDescriptorWithKey:@"date" ascending:YES];
            NSArray *sortedBars = [filteredBars sortedArrayUsingDescriptors:@[sortDescriptor]];
            
            // Take the LAST N bars (most recent)
            // ✅ FIX: Prendi le ULTIME N barre invece delle prime
            NSInteger totalBars = sortedBars.count;
            NSInteger startIndex = MAX(0, totalBars - barCount);
            NSRange range = NSMakeRange(startIndex, totalBars - startIndex);
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
            
            NSLog(@"✅ DataHub: Loaded %lu HistoricalBarModel objects for %@ (timeframe: %d) - FIXED ORDERING",
                  (unsigned long)runtimeBars.count, symbol, (int)timeframe);
            
           
            
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
    
    if (!bars || bars.count == 0 || !symbol) return;
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        NSManagedObjectContext *backgroundContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
        backgroundContext.parentContext = self.mainContext;
        
        [backgroundContext performBlock:^{
            
            // ✅ STEP 1: Clean existing bars per questo symbol/timeframe
            [self cleanExistingBarsForSymbol:symbol timeframe:timeframe inContext:backgroundContext];
            
            // ✅ STEP 2: Find or create symbol entity
            Symbol *symbolEntity = [self findOrCreateSymbolWithName:symbol inContext:backgroundContext];
            
            // ✅ STEP 3: Save new bars with additional duplicate prevention
            NSArray<HistoricalBarModel *> *deduplicatedBars = [self removeDuplicatesFromBars:bars];
            
            for (HistoricalBarModel *barModel in deduplicatedBars) {
                [self createCoreDataBarFromModel:barModel
                                           symbol:symbolEntity
                                        timeframe:timeframe
                                        inContext:backgroundContext];
            }
            
            // ✅ STEP 4: Save with error handling
            NSError *saveError = nil;
            if (![backgroundContext save:&saveError]) {
                NSLog(@"❌ Error saving historical bars to Core Data: %@", saveError);
                
                // Retry once on conflict
                if (saveError.code == NSManagedObjectMergeError) {
                    [backgroundContext rollback];
                    // Could implement retry logic here if needed
                }
            } else {
                NSLog(@"✅ Successfully saved %lu deduplicated bars to Core Data for %@",
                      (unsigned long)deduplicatedBars.count, symbol);
                
                // ✅ STEP 5: Save to parent context
                dispatch_async(dispatch_get_main_queue(), ^{
                    NSError *parentSaveError = nil;
                    if (![self.mainContext save:&parentSaveError]) {
                        NSLog(@"❌ Error saving to main context: %@", parentSaveError);
                    }
                });
            }
        }];
    });
}
- (NSArray<HistoricalBarModel *> *)removeDuplicatesFromBars:(NSArray<HistoricalBarModel *> *)bars {
    if (bars.count <= 1) return bars;
    
    NSMutableArray<HistoricalBarModel *> *deduplicatedBars = [NSMutableArray array];
    
    for (HistoricalBarModel *bar in bars) {
        if (![self isBarDuplicate:bar inArray:deduplicatedBars]) {
            [deduplicatedBars addObject:bar];
        }
    }
    
    return [deduplicatedBars copy];
}

- (void)createCoreDataBarFromModel:(HistoricalBarModel *)barModel
                            symbol:(Symbol *)symbolEntity
                         timeframe:(BarTimeframe)timeframe
                         inContext:(NSManagedObjectContext *)context {
    
    if (!barModel || !barModel.date || !symbolEntity) return;
    
    HistoricalBar *coreDataBar = [NSEntityDescription insertNewObjectForEntityForName:@"HistoricalBar"
                                                               inManagedObjectContext:context];
    
    // Set all properties
    coreDataBar.date = barModel.date;
    coreDataBar.open = barModel.open;
    coreDataBar.high = barModel.high;
    coreDataBar.low = barModel.low;
    coreDataBar.close = barModel.close;
    coreDataBar.volume = barModel.volume;
    coreDataBar.timeframe = timeframe;
    coreDataBar.symbol = symbolEntity;
}

- (void)cleanExistingBarsForSymbol:(NSString *)symbol
                         timeframe:(BarTimeframe)timeframe
                         inContext:(NSManagedObjectContext *)context {
    
    // ✅ BATCH DELETE for performance
    NSFetchRequest *deleteRequest = [HistoricalBar fetchRequest];
    deleteRequest.predicate = [NSPredicate predicateWithFormat:
                              @"symbol.symbol == %@ AND timeframe == %d", symbol, timeframe];
    
    NSBatchDeleteRequest *batchDelete = [[NSBatchDeleteRequest alloc] initWithFetchRequest:deleteRequest];
    batchDelete.resultType = NSBatchDeleteResultTypeCount;
    
    NSError *deleteError = nil;
    NSBatchDeleteResult *result = [context executeRequest:batchDelete error:&deleteError];
    
    if (deleteError) {
        NSLog(@"⚠️ Error cleaning existing bars for %@: %@", symbol, deleteError);
    } else {
        NSLog(@"🗑️ Cleaned %@ existing bars for %@ timeframe %d",
              result.result, symbol, timeframe);
    }
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
        case BarTimeframeDaily:
            return (NSInteger)(interval / 86400);
        case BarTimeframeWeekly:
            return (NSInteger)(interval / 604800);
        case BarTimeframeMonthly:
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
    
    // CORREZIONE: Usare metodo corretto di DataManager
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

// ============================================================================
// 🛠️ HELPER METHOD: Validate Date Range Request Compatibility
// ============================================================================
/*
 * Valida se una richiesta con date specifiche è compatibile con la cache esistente
 * @param cachedBars Array di barre in cache
 * @param requestedStartDate Data di inizio richiesta
 * @param requestedEndDate Data di fine richiesta
 * @return YES se compatibile (smart update), NO se serve full request
 */
- (BOOL)isDateRangeCompatibleWithCache:(NSArray<HistoricalBarModel *> *)cachedBars
                    requestedStartDate:(NSDate *)requestedStartDate
                      requestedEndDate:(NSDate *)requestedEndDate {
    
    if (!cachedBars || cachedBars.count == 0) return NO;
    
    HistoricalBarModel *firstCachedBar = [cachedBars firstObject];
    HistoricalBarModel *lastCachedBar = [cachedBars lastObject];
    
    NSDate *cacheStartDate = firstCachedBar.date;
    NSDate *cacheEndDate = lastCachedBar.date;
    
    if (!cacheStartDate || !cacheEndDate) return NO;
    
    // Verifica se il range richiesto è contenuto nel range in cache
    BOOL startDateOK = [requestedStartDate compare:cacheStartDate] != NSOrderedAscending;
    BOOL endDateOK = [requestedEndDate compare:cacheEndDate] != NSOrderedDescending;
    
    BOOL isCompatible = startDateOK && endDateOK;
    
    NSLog(@"🔍 Date Range Compatibility Check:");
    NSLog(@"   Cache: %@ to %@", cacheStartDate, cacheEndDate);
    NSLog(@"   Requested: %@ to %@", requestedStartDate, requestedEndDate);
    NSLog(@"   Result: %@", isCompatible ? @"COMPATIBLE" : @"INCOMPATIBLE");
    
    return isCompatible;
}

@end
