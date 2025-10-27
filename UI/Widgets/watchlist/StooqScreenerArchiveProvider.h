//
//  StooqScreenerArchiveProvider.h
//  TradingApp
//
//  Provider for Stooq Screener archived results
//  Shows ModelResult from the most recent ExecutionSession
//

#import <Foundation/Foundation.h>
#import "WatchlistProviderManager.h"

NS_ASSUME_NONNULL_BEGIN

@class ModelResult;

@interface StooqScreenerArchiveProvider : NSObject <WatchlistProvider>

#pragma mark - Properties

/// The ModelResult this provider wraps
@property (nonatomic, strong, readonly) ModelResult *modelResult;

/// Execution date from parent session
@property (nonatomic, strong, readonly) NSDate *executionDate;

#pragma mark - Initialization

/**
 * Create provider from ModelResult
 * @param modelResult The model result to wrap
 * @param executionDate When this model was executed
 * @return Initialized provider
 */
- (instancetype)initWithModelResult:(ModelResult *)modelResult
                     executionDate:(NSDate *)executionDate;

@end

NS_ASSUME_NONNULL_END
