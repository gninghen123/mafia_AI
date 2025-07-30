//
//  DataHub+Private.h
//  Private interface for DataHub - internal use only
//

#import "DataHub.h"
#import "RuntimeModels.h"

@interface DataHub ()

// Core Data
@property (nonatomic, strong) NSPersistentContainer *persistentContainer;
@property (nonatomic, strong) NSManagedObjectContext *mainContext;

// Collections
@property (nonatomic, strong) NSMutableArray<Watchlist *> *watchlists;
@property (nonatomic, strong) NSMutableArray<Alert *> *alerts;
@property (nonatomic, strong) NSMutableArray<StockConnection *> *connections;

// Legacy cache (keep for compatibility)
@property (nonatomic, strong) NSMutableDictionary *cache;

// NEW: Runtime model caches
@property (nonatomic, strong) NSMutableDictionary<NSString *, MarketQuote *> *quotesCache;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSArray<HistoricalBar *> *> *historicalCache;
@property (nonatomic, strong) NSMutableDictionary<NSString *, CompanyInfo *> *companyInfoCache;

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

// NEW: Market data internal methods
- (void)initializeMarketDataCaches;

@end
