//
//  OtherDataSource+TickData.h
//  TradingApp
//
//  Extension for Nasdaq tick data endpoints
//

#import "OtherDataSource.h"

@interface OtherDataSource (TickData)

#pragma mark - Tick Data Endpoints

// Regular hours real-time trades (9:30-16:00 ET)
- (void)fetchRealtimeTradesForSymbol:(NSString *)symbol
                               limit:(NSInteger)limit
                            fromTime:(NSString *)fromTime  // Format: "9:30" or "HH:mm"
                          completion:(void (^)(NSArray *trades, NSError *error))completion;

// After-hours extended trading
- (void)fetchExtendedTradingForSymbol:(NSString *)symbol
                           marketType:(NSString *)marketType  // "pre" or "post"
                           completion:(void (^)(NSArray *trades, NSError *error))completion;

// Get all trades for current session (combines regular + extended)
- (void)fetchFullSessionTradesForSymbol:(NSString *)symbol
                             completion:(void (^)(NSArray *trades, NSError *error))completion;

@end
