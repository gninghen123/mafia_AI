//
//  OtherDataSource+TickData.m
//  TradingApp
//

#import "OtherDataSource+TickData.h"
#import "OtherDataSource+Private.h"

// Nasdaq tick data endpoints
static NSString *const kNasdaqRealtimeTradesURL = @"https://api.nasdaq.com/api/quote/%@/realtime-trades";
static NSString *const kNasdaqExtendedTradingURL = @"https://api.nasdaq.com/api/quote/%@/extended-trading";

@implementation OtherDataSource (TickData)

#pragma mark - Tick Data Methods

- (void)fetchRealtimeTradesForSymbol:(NSString *)symbol
                               limit:(NSInteger)limit
                            fromTime:(NSString *)fromTime
                          completion:(void (^)(NSArray *trades, NSError *error))completion {
    
    if (!symbol || symbol.length == 0) {
        NSError *error = [NSError errorWithDomain:@"OtherDataSource"
                                             code:400
                                         userInfo:@{NSLocalizedDescriptionKey: @"Symbol is required"}];
        if (completion) completion(nil, error);
        return;
    }
    
    // Build URL with parameters
    NSString *baseURL = [NSString stringWithFormat:kNasdaqRealtimeTradesURL, symbol.uppercaseString];
    NSMutableString *urlString = [baseURL mutableCopy];
    
    // Add query parameters
    [urlString appendString:@"?"];
    
    if (limit > 0) {
        [urlString appendFormat:@"limit=%ld&", (long)limit];
    } else {
        [urlString appendString:@"limit=999999999&"];  // Max trades
    }
    
    if (fromTime && fromTime.length > 0) {
        [urlString appendFormat:@"fromTime=%@&", fromTime];
    } else {
        [urlString appendString:@"fromTime=9:30&"];  // Default market open
    }
    
    // Remove trailing &
    if ([urlString hasSuffix:@"&"]) {
        [urlString deleteCharactersInRange:NSMakeRange(urlString.length - 1, 1)];
    }
    
    NSLog(@"Fetching realtime trades: %@", urlString);
    
    [self executeNasdaqRequest:urlString completion:^(id response, NSError *error) {
        if (error) {
            NSLog(@"Error fetching realtime trades for %@: %@", symbol, error.localizedDescription);
            if (completion) completion(nil, error);
            return;
        }
        
        NSArray *tradesData = [self extractDataFromNasdaqResponse:response];
        NSMutableArray *trades = [NSMutableArray array];
        
        for (NSDictionary *item in tradesData) {
            NSDictionary *trade = @{
                @"symbol": symbol.uppercaseString,
                @"timestamp": item[@"nlsTime"] ?: item[@"time"] ?: @"",
                @"price": item[@"price"] ?: @0,
                @"size": item[@"size"] ?: @0,
                @"exchange": item[@"exchange"] ?: @"",
                @"conditions": item[@"conditions"] ?: @"",
                @"marketCenter": item[@"marketCenter"] ?: @"",
                @"dollarVolume": item[@"dollarVolume"] ?: @0
            };
            [trades addObject:trade];
        }
        
        NSLog(@"Fetched %lu realtime trades for %@", (unsigned long)trades.count, symbol);
        if (completion) completion([trades copy], nil);
    }];
}

- (void)fetchExtendedTradingForSymbol:(NSString *)symbol
                           marketType:(NSString *)marketType
                           completion:(void (^)(NSArray *trades, NSError *error))completion {
    
    if (!symbol || symbol.length == 0) {
        NSError *error = [NSError errorWithDomain:@"OtherDataSource"
                                             code:400
                                         userInfo:@{NSLocalizedDescriptionKey: @"Symbol is required"}];
        if (completion) completion(nil, error);
        return;
    }
    
    // Validate market type
    if (!marketType || (![marketType isEqualToString:@"pre"] && ![marketType isEqualToString:@"post"])) {
        marketType = @"post";  // Default to after-hours
    }
    
    // Build URL
    NSString *urlString = [NSString stringWithFormat:@"%@?markettype=%@&assetclass=stocks&time=2",
                          [NSString stringWithFormat:kNasdaqExtendedTradingURL, symbol.uppercaseString],
                          marketType];
    
    NSLog(@"Fetching extended trading (%@): %@", marketType, urlString);
    
    [self executeNasdaqRequest:urlString completion:^(id response, NSError *error) {
        if (error) {
            NSLog(@"Error fetching extended trading for %@: %@", symbol, error.localizedDescription);
            if (completion) completion(nil, error);
            return;
        }
        
        NSArray *tradesData = [self extractDataFromNasdaqResponse:response];
        NSMutableArray *trades = [NSMutableArray array];
        
        for (NSDictionary *item in tradesData) {
            NSDictionary *trade = @{
                @"symbol": symbol.uppercaseString,
                @"timestamp": item[@"nlsTime"] ?: item[@"time"] ?: @"",
                @"price": item[@"price"] ?: @0,
                @"size": item[@"size"] ?: @0,
                @"exchange": item[@"exchange"] ?: @"",
                @"marketType": marketType,
                @"dollarVolume": item[@"dollarVolume"] ?: @0
            };
            [trades addObject:trade];
        }
        
        NSLog(@"Fetched %lu extended trading trades for %@", (unsigned long)trades.count, symbol);
        if (completion) completion([trades copy], nil);
    }];
}

- (void)fetchFullSessionTradesForSymbol:(NSString *)symbol
                             completion:(void (^)(NSArray *trades, NSError *error))completion {
    
    NSMutableArray *allTrades = [NSMutableArray array];
    __block NSInteger completedRequests = 0;
    __block NSError *lastError = nil;
    
    void (^checkCompletion)(void) = ^{
        completedRequests++;
        if (completedRequests >= 3) {
            // Sort all trades by timestamp
            NSArray *sortedTrades = [allTrades sortedArrayUsingComparator:^NSComparisonResult(NSDictionary *trade1, NSDictionary *trade2) {
                NSString *time1 = trade1[@"timestamp"];
                NSString *time2 = trade2[@"timestamp"];
                return [time1 compare:time2];
            }];
            
            if (completion) {
                completion(sortedTrades, sortedTrades.count > 0 ? nil : lastError);
            }
        }
    };
    
    // 1. Pre-market trades
    [self fetchExtendedTradingForSymbol:symbol marketType:@"pre" completion:^(NSArray *trades, NSError *error) {
        if (trades) [allTrades addObjectsFromArray:trades];
        if (error) lastError = error;
        checkCompletion();
    }];
    
    // 2. Regular hours trades
    [self fetchRealtimeTradesForSymbol:symbol limit:0 fromTime:@"9:30" completion:^(NSArray *trades, NSError *error) {
        if (trades) [allTrades addObjectsFromArray:trades];
        if (error) lastError = error;
        checkCompletion();
    }];
    
    // 3. After-hours trades
    [self fetchExtendedTradingForSymbol:symbol marketType:@"post" completion:^(NSArray *trades, NSError *error) {
        if (trades) [allTrades addObjectsFromArray:trades];
        if (error) lastError = error;
        checkCompletion();
    }];
}

@end
