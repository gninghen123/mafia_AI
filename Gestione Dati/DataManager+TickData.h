//
//  DataManager+TickData.h
//  mafia_AI
//
//  Extension for handling tick data requests and standardization
//

#import "DataManager.h"
#import "TickDataModel.h"

@interface DataManager (TickData)

#pragma mark - Tick Data Requests

// Request real-time trades for symbol
- (void)requestRealtimeTicksForSymbol:(NSString *)symbol
                                limit:(NSInteger)limit
                             fromTime:(NSString *)fromTime
                           completion:(void(^)(NSArray<TickDataModel *> *ticks, NSError *error))completion;

// Request extended trading ticks
- (void)requestExtendedTicksForSymbol:(NSString *)symbol
                           marketType:(NSString *)marketType
                           completion:(void(^)(NSArray<TickDataModel *> *ticks, NSError *error))completion;

// Request full session ticks (pre + regular + after)
- (void)requestFullSessionTicksForSymbol:(NSString *)symbol
                              completion:(void(^)(NSArray<TickDataModel *> *ticks, NSError *error))completion;

@end
