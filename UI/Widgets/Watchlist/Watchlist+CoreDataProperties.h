//
//  Watchlist+CoreDataProperties.h
//  mafia_AI
//

#import "Watchlist+CoreDataClass.h"

NS_ASSUME_NONNULL_BEGIN

@interface Watchlist (CoreDataProperties)

+ (NSFetchRequest<Watchlist *> *)fetchRequest;

@property (nullable, nonatomic, copy) NSString *name;
@property (nullable, nonatomic, retain) NSSet<NSString *> *symbols;
@property (nullable, nonatomic, copy) NSDate *createdAt;
@property (nullable, nonatomic, copy) NSDate *modifiedAt;
@property (nonatomic) BOOL isFavorite;
@property (nonatomic) int16_t sortOrder;

// Relationships
@property (nullable, nonatomic, retain) NSSet<Alert *> *alerts;
@property (nullable, nonatomic, retain) NSSet<StockConnection *> *connections;

@end

// Core Data generated accessors for symbols
@interface Watchlist (CoreDataGeneratedAccessors)

- (void)addSymbolsObject:(NSString *)value;
- (void)removeSymbolsObject:(NSString *)value;
- (void)addSymbols:(NSSet<NSString *> *)values;
- (void)removeSymbols:(NSSet<NSString *> *)values;

@end

// Core Data generated accessors for alerts
@interface Watchlist (CoreDataGeneratedAccessors)

- (void)addAlertsObject:(Alert *)value;
- (void)removeAlertsObject:(Alert *)value;
- (void)addAlerts:(NSSet<Alert *> *)values;
- (void)removeAlerts:(NSSet<Alert *> *)values;

@end

// Core Data generated accessors for connections
@interface Watchlist (CoreDataGeneratedAccessors)

- (void)addConnectionsObject:(StockConnection *)value;
- (void)removeConnectionsObject:(StockConnection *)value;
- (void)addConnections:(NSSet<StockConnection *> *)values;
- (void)removeConnections:(NSSet<StockConnection *> *)values;

@end

NS_ASSUME_NONNULL_END
