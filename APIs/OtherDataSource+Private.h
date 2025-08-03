//
//  OtherDataSource+Private.h
//  TradingApp
//
//  Private methods interface for OtherDataSource extensions
//

#import "OtherDataSource.h"

@interface OtherDataSource ()

// Private HTTP request methods
- (void)executeNasdaqRequest:(NSString *)urlString completion:(void (^)(id response, NSError *error))completion;
- (NSArray *)extractDataFromNasdaqResponse:(id)response;

// Rate limiting methods
- (BOOL)checkRateLimit:(NSString *)source;
- (void)incrementRequestCount:(NSString *)source;

// Utility methods
- (NSString *)todayDateString;

@end
