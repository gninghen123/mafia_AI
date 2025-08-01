//
//  DataHub+Connections.h
//  mafia_AI
//
//  Estensione DataHub per gestire le Connections
//

#import "DataHub.h"
#import "ConnectionModel.h"
#import "ConnectionTypes.h"

NS_ASSUME_NONNULL_BEGIN

// Notification names
FOUNDATION_EXPORT NSString * const DataHubConnectionsUpdatedNotification;

@interface DataHub (Connections)

#pragma mark - Connection Management

// Creazione connections
- (ConnectionModel *)createConnectionWithSymbols:(NSArray<NSString *> *)symbols
                                            type:(StockConnectionType)type
                                           title:(NSString *)title;

- (ConnectionModel *)createDirectionalConnectionFromSymbol:(NSString *)sourceSymbol
                                                 toSymbols:(NSArray<NSString *> *)targetSymbols
                                                      type:(StockConnectionType)type
                                                     title:(NSString *)title;

- (ConnectionModel *)createBidirectionalConnectionWithSymbols:(NSArray<NSString *> *)symbols
                                                         type:(StockConnectionType)type
                                                        title:(NSString *)title;

// CRUD Operations
- (void)updateConnection:(ConnectionModel *)connection;
- (void)deleteConnection:(ConnectionModel *)connection;
- (void)deleteConnectionWithID:(NSString *)connectionID;

// Retrieve connections
- (NSArray<ConnectionModel *> *)getAllConnections;
- (NSArray<ConnectionModel *> *)getActiveConnections;
- (NSArray<ConnectionModel *> *)getConnectionsForSymbol:(NSString *)symbol;
- (NSArray<ConnectionModel *> *)getConnectionsOfType:(StockConnectionType)type;
- (nullable ConnectionModel *)getConnectionWithID:(NSString *)connectionID;

// Search and filter
- (NSArray<ConnectionModel *> *)searchConnectionsWithQuery:(NSString *)query;
- (NSArray<ConnectionModel *> *)getConnectionsModifiedSince:(NSDate *)date;
- (NSArray<ConnectionModel *> *)getConnectionsWithStrengthAbove:(double)threshold;
- (NSArray<ConnectionModel *> *)getConnectionsRequiringDecayUpdate;

#pragma mark - Symbol Relationships

// Get related symbols for a given symbol
- (NSArray<NSString *> *)getRelatedSymbolsForSymbol:(NSString *)symbol;
- (NSArray<NSString *> *)getRelatedSymbolsForSymbol:(NSString *)symbol ofType:(StockConnectionType)type;

// Get connections between specific symbols
- (NSArray<ConnectionModel *> *)getConnectionsBetweenSymbol:(NSString *)symbol1 andSymbol:(NSString *)symbol2;
- (BOOL)areSymbolsConnected:(NSString *)symbol1 andSymbol:(NSString *)symbol2;

#pragma mark - AI Summary Integration

// AI Summary methods (integra con Claude API)
- (void)generateAISummaryForConnection:(ConnectionModel *)connection
                            completion:(void(^)(NSString * _Nullable summary, NSError * _Nullable error))completion;

- (void)summarizeNewsFromURL:(NSString *)url
                  completion:(void(^)(NSString * _Nullable summary, NSError * _Nullable error))completion;

#pragma mark - Strength Management

// Update strength for all connections
- (void)updateAllConnectionStrengths;
- (void)updateStrengthForConnection:(ConnectionModel *)connection;

// Auto-cleanup
- (NSArray<ConnectionModel *> *)getConnectionsToAutoDelete;
- (void)performAutoCleanup;

// Strength analytics
- (double)averageStrengthForSymbol:(NSString *)symbol;
- (NSArray<ConnectionModel *> *)getWeakestConnections:(NSInteger)count;
- (NSArray<ConnectionModel *> *)getStrongestConnections:(NSInteger)count;

#pragma mark - Bulk Operations

// Import/Export
- (NSDictionary *)exportConnectionsData;
- (BOOL)importConnectionsData:(NSDictionary *)data error:(NSError **)error;

// Batch operations
- (void)updateMultipleConnections:(NSArray<ConnectionModel *> *)connections;
- (void)deleteMultipleConnections:(NSArray<ConnectionModel *> *)connections;

#pragma mark - Statistics

// Connection stats
- (NSInteger)totalConnectionsCount;
- (NSInteger)activeConnectionsCount;
- (NSDictionary<NSNumber *, NSNumber *> *)connectionCountsByType;
- (NSArray<NSString *> *)mostConnectedSymbols:(NSInteger)count;

// Type distribution
- (NSInteger)connectionsCountForType:(StockConnectionType)type;
- (NSArray<NSString *> *)symbolsForType:(StockConnectionType)type;

#pragma mark - Cache Management

// Cache refresh
- (void)refreshConnectionsCache;
- (void)clearConnectionsCache;

// Conversion helpers (internal use)
- (ConnectionModel *)convertCoreDataToRuntimeModel:(StockConnection *)coreDataConnection;
- (void)updateCoreDataFromRuntimeModel:(ConnectionModel *)runtimeModel coreDataConnection:(StockConnection *)coreDataConnection;

@end

NS_ASSUME_NONNULL_END
