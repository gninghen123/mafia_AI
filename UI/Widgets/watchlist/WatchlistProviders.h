//
//  WatchlistProviders.h
//  Concrete implementations of watchlist provider protocol
//

#import <Foundation/Foundation.h>
#import "RuntimeModels.h"
#import "CommonTypes.h"
#import "WatchlistProviderManager.h"  // Per avere il WatchlistProvider protocol

NS_ASSUME_NONNULL_BEGIN

@class TagManager;

#pragma mark - Manual Watchlist Provider

@interface ManualWatchlistProvider : NSObject <WatchlistProvider>
@property (nonatomic, strong) WatchlistModel *watchlistModel;
- (instancetype)initWithWatchlistModel:(WatchlistModel *)model;
@end

#pragma mark - Market List Provider

@interface MarketListProvider : NSObject <WatchlistProvider>
@property (nonatomic, assign) MarketListType marketType;
@property (nonatomic, assign) MarketTimeframe timeframe;
- (instancetype)initWithMarketType:(MarketListType)type timeframe:(MarketTimeframe)timeframe;
@end

#pragma mark - Basket Provider

@interface BasketProvider : NSObject <WatchlistProvider>
@property (nonatomic, assign) BasketType basketType;
- (instancetype)initWithBasketType:(BasketType)type;
@end

#pragma mark - Tag List Provider

@interface TagListProvider : NSObject <WatchlistProvider>
@property (nonatomic, strong) NSString *tag;
- (instancetype)initWithTag:(NSString *)tag;
@end

#pragma mark - Archive Provider

@interface ArchiveProvider : NSObject <WatchlistProvider>
@property (nonatomic, strong) NSString *archiveKey;
- (instancetype)initWithArchiveKey:(NSString *)archiveKey;
@end

NS_ASSUME_NONNULL_END
