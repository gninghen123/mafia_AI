//
//  DataHub+TickData.h
//  mafia_AI
//
//  DataHub extension for tick data management with caching and notifications
//

#import "DataHub.h"
#import "TickDataModel.h"

// Notification names
extern NSString * const DataHubTickDataUpdatedNotification;
extern NSString * const DataHubTickStreamStartedNotification;
extern NSString * const DataHubTickStreamStoppedNotification;

@interface DataHub (TickData)

#pragma mark - Tick Data API

// Get tick data with smart caching (TTL: 30 seconds for active symbols)
- (void)getTickDataForSymbol:(NSString *)symbol
                       limit:(NSInteger)limit
                    fromTime:(NSString *)fromTime
                  completion:(void(^)(NSArray<TickDataModel *> *ticks, BOOL isFresh))completion;

// Get extended hours tick data
- (void)getExtendedTickDataForSymbol:(NSString *)symbol
                          marketType:(NSString *)marketType
                          completion:(void(^)(NSArray<TickDataModel *> *ticks, BOOL isFresh))completion;

// Get full session tick data (pre + regular + after)
- (void)getFullSessionTickDataForSymbol:(NSString *)symbol
                             completion:(void(^)(NSArray<TickDataModel *> *ticks, BOOL isFresh))completion;

#pragma mark - Real-Time Tick Streaming

// Start/stop real-time tick updates for symbol
- (void)startTickStreamForSymbol:(NSString *)symbol;
- (void)stopTickStreamForSymbol:(NSString *)symbol;
- (void)stopAllTickStreams;

// Check if symbol has active tick stream
- (BOOL)hasActiveTickStreamForSymbol:(NSString *)symbol;

// Get list of symbols with active streams
- (NSArray<NSString *> *)activeTickStreamSymbols;

#pragma mark - Tick Analytics

// Calculate volume delta (buy vs sell pressure)
- (double)calculateVolumeDeltaForTicks:(NSArray<TickDataModel *> *)ticks;

// Calculate VWAP for tick data
- (double)calculateVWAPForTicks:(NSArray<TickDataModel *> *)ticks;

// Get buy/sell volume breakdown
- (NSDictionary *)calculateVolumeBreakdownForTicks:(NSArray<TickDataModel *> *)ticks;

// Find significant trades (large blocks)
- (NSArray<TickDataModel *> *)findSignificantTradesInTicks:(NSArray<TickDataModel *> *)ticks
                                             volumeThreshold:(NSInteger)threshold;

@end
