//
//  DataHub+Private.h
//  Private interface for DataHub - internal use only
//

#import "DataHub.h"

@interface DataHub ()

// Core Data
@property (nonatomic, strong) NSPersistentContainer *persistentContainer;
@property (nonatomic, strong) NSManagedObjectContext *mainContext;

// Collections
@property (nonatomic, strong) NSMutableArray<Watchlist *> *watchlists;
@property (nonatomic, strong) NSMutableArray<Alert *> *alerts;
@property (nonatomic, strong) NSMutableArray<StockConnection *> *connections;

// Cache
@property (nonatomic, strong) NSMutableDictionary *cache;

// Timers
@property (nonatomic, strong) NSTimer *alertCheckTimer;

// Tracking richieste in corso
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

@end
