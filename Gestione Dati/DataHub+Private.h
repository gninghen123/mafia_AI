//
//  DataHub+Private.h
//  Private interface for DataHub - internal use only
//

#import "DataHub.h"
#import "RuntimeModels.h"
#import "CommonTypes.h"

// Forward declarations for Core Data entities
@class MarketQuote;
@class HistoricalBar;
@class CompanyInfo;
@class Watchlist;
@class Alert;
@class StockConnection;
@class TradingModel;

@class MarketQuoteModel;
@class HistoricalBarModel;
@class CompanyInfoModel;
@class SeasonalDataModel;


@interface DataHub ()




// Seasonal Data Cache (NEW)
@property (nonatomic, strong) NSMutableDictionary<NSString *, SeasonalDataModel *> *seasonalDataCache;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSDate *> *seasonalCacheTimestamps;

// Core Data
@property (nonatomic, strong) NSPersistentContainer *persistentContainer;
@property (nonatomic, strong) NSManagedObjectContext *mainContext;

// Collections (Core Data entities)
@property (nonatomic, strong) NSMutableArray<Watchlist *> *watchlists;
@property (nonatomic, strong) NSMutableArray<Alert *> *alerts;
@property (nonatomic, strong) NSMutableArray<StockConnection *> *connections;
@property (nonatomic, strong) NSMutableArray<TradingModel *> *tradingModels;

// Legacy cache (keep for compatibility)
@property (nonatomic, strong) NSMutableDictionary *cache;
@property (nonatomic, strong) NSMutableDictionary *symbolDataCache;

// FIXED: Runtime model caches (not Core Data entities)
@property (nonatomic, strong) NSMutableDictionary<NSString *, MarketQuoteModel *> *quotesCache;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSArray<HistoricalBarModel *> *> *historicalCache;
@property (nonatomic, strong) NSMutableDictionary<NSString *, CompanyInfoModel *> *companyInfoCache;

// Market Lists Cache (NEW)
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSArray<MarketPerformerModel *> *> *marketListsCache;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSDate *> *marketListsCacheTimestamps;

// Cache timestamps for TTL management
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSDate *> *cacheTimestamps;

// Active requests tracking
@property (nonatomic, strong) NSMutableSet<NSString *> *activeQuoteRequests;
@property (nonatomic, strong) NSMutableSet<NSString *> *activeHistoricalRequests;

// Subscriptions for real-time updates
@property (nonatomic, strong) NSMutableSet<NSString *> *subscribedSymbols;
@property (nonatomic, strong) NSTimer *refreshTimer;

// Timers
@property (nonatomic, strong) NSTimer *alertCheckTimer;

// Tracking richieste in corso (legacy)
@property (nonatomic, strong) NSMutableDictionary *pendingRequests;

// Internal methods
- (void)saveContext;
- (void)loadWatchlists;
- (void)loadAlerts;
- (void)loadConnections;
- (void)startAlertMonitoring;
- (void)checkAlerts;
- (void)checkAlert:(Alert *)alert;
- (void)triggerAlert:(Alert *)alert;
- (void)showNotificationForAlert:(Alert *)alert;
- (NSDictionary *)getDataForSymbol:(NSString *)symbol;

// Market data internal methods
- (void)initializeMarketDataCaches;
- (void)initializeMarketListsCache;

// Core Data <-> Runtime Model conversion methods (ESSENTIAL)
- (MarketQuoteModel *)convertCoreDataQuoteToRuntimeModel:(MarketQuote *)coreDataQuote;
- (HistoricalBarModel *)convertCoreDataBarToRuntimeModel:(HistoricalBar *)coreDataBar;
- (CompanyInfoModel *)convertCoreDataCompanyInfoToRuntimeModel:(CompanyInfo *)coreDataInfo;
- (void)updateCoreDataQuote:(MarketQuote *)coreDataQuote withRuntimeModel:(MarketQuoteModel *)runtimeQuote;
- (void)saveHistoricalBarModel:(HistoricalBarModel *)barModel inContext:(NSManagedObjectContext *)context;

// Cache management methods
- (void)cacheQuote:(MarketQuoteModel *)quote;
- (void)cacheHistoricalBars:(NSArray<HistoricalBarModel *> *)bars forKey:(NSString *)cacheKey;

// Notification broadcast methods
- (void)broadcastQuoteUpdate:(MarketQuoteModel *)quote;
- (void)broadcastHistoricalDataUpdate:(NSArray<HistoricalBarModel *> *)bars forSymbol:(NSString *)symbol;

// Data freshness and TTL methods
- (NSTimeInterval)TTLForDataType:(DataFreshnessType)type;
- (BOOL)isCacheStale:(NSString *)cacheKey dataType:(DataFreshnessType)type;
- (void)updateCacheTimestamp:(NSString *)cacheKey;

// Core Data loading methods
- (void)loadQuoteFromCoreData:(NSString *)symbol completion:(void(^)(MarketQuoteModel *quote))completion;
- (void)loadHistoricalDataFromCoreData:(NSString *)symbol timeframe:(BarTimeframe)timeframe barCount:(NSInteger)barCount completion:(void(^)(NSArray<HistoricalBarModel *> *bars))completion;
- (void)loadCompanyInfoFromCoreData:(NSString *)symbol completion:(void(^)(CompanyInfoModel *info))completion;

// Core Data saving methods
- (void)saveQuoteModelToCoreData:(MarketQuoteModel *)quote;
- (void)saveHistoricalBarsModelToCoreData:(NSArray<HistoricalBarModel *> *)bars symbol:(NSString *)symbol timeframe:(BarTimeframe)timeframe;

// Subscription timer methods
- (void)startRefreshTimer;
- (void)stopRefreshTimer;
- (void)refreshSubscribedQuotes;

// Utility methods
- (NSInteger)estimateBarCountForTimeframe:(BarTimeframe)timeframe startDate:(NSDate *)startDate endDate:(NSDate *)endDate;

- (Symbol *)findOrCreateSymbolWithName:(NSString *)symbolName inContext:(NSManagedObjectContext *)context;
#pragma mark - Smart Cache Methods (NEW)



#pragma mark - Smart Cache Methods (NEW)

// Core smart cache methods
- (void)performSmartUpdateForSymbol:(NSString *)symbol
                          timeframe:(BarTimeframe)timeframe
                           barCount:(NSInteger)barCount
                  needExtendedHours:(BOOL)needExtendedHours
                         cachedBars:(NSArray<HistoricalBarModel *> *)cachedBars
                           cacheKey:(NSString *)cacheKey
                         completion:(void (^)(NSArray<HistoricalBarModel *> *bars, BOOL isFresh))completion;

- (NSInteger)getGoBackPeriodForTimeframe:(BarTimeframe)timeframe;
- (NSTimeInterval)secondsPerBarForTimeframe:(BarTimeframe)timeframe;

- (NSArray<HistoricalBarModel *> *)mergeHistoricalBars:(NSArray<HistoricalBarModel *> *)cachedBars
                                           withNewBars:(NSArray<HistoricalBarModel *> *)newBars
                                              barCount:(NSInteger)barCount;

- (void)performFullHistoricalRequest:(NSString *)symbol
                           timeframe:(BarTimeframe)timeframe
                            barCount:(NSInteger)barCount
                   needExtendedHours:(BOOL)needExtendedHours
                            cacheKey:(NSString *)cacheKey
                          completion:(void (^)(NSArray<HistoricalBarModel *> *bars, BOOL isFresh))completion;

#pragma mark - Core Data Safe Loading (NEW)

// Safe Core Data loading with deduplication
- (void)loadHistoricalDataFromCoreDataSafely:(NSString *)symbol
                                   timeframe:(BarTimeframe)timeframe
                                    barCount:(NSInteger)barCount
                           needExtendedHours:(BOOL)needExtendedHours
                                  completion:(void(^)(NSArray<HistoricalBarModel *> *bars))completion;

#pragma mark - Deduplication Utilities (NEW)

// Duplicate detection and removal
- (BOOL)isBarDuplicate:(HistoricalBarModel *)bar inArray:(NSArray<HistoricalBarModel *> *)array;
- (BOOL)areBarsEqual:(HistoricalBarModel *)bar1 other:(HistoricalBarModel *)bar2;
- (NSArray<HistoricalBarModel *> *)removeDuplicatesFromSortedBars:(NSArray<HistoricalBarModel *> *)sortedBars;
- (NSArray<HistoricalBarModel *> *)limitBarsToCount:(NSArray<HistoricalBarModel *> *)bars maxCount:(NSInteger)maxCount;
- (NSArray<HistoricalBar *> *)deduplicateCoreDataBars:(NSArray<HistoricalBar *> *)coreDataBars;
- (NSArray<HistoricalBarModel *> *)removeDuplicatesFromBars:(NSArray<HistoricalBarModel *> *)bars;

#pragma mark - Core Data Duplicate Prevention (NEW)

// Core Data saving with complete duplicate prevention
- (void)cleanExistingBarsForSymbol:(NSString *)symbol
                         timeframe:(BarTimeframe)timeframe
                         inContext:(NSManagedObjectContext *)context;

- (void)createCoreDataBarFromModel:(HistoricalBarModel *)barModel
                            symbol:(Symbol *)symbolEntity
                         timeframe:(BarTimeframe)timeframe
                         inContext:(NSManagedObjectContext *)context;
@end
