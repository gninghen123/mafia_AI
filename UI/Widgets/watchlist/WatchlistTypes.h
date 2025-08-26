//
//  WatchlistTypes.h
//  TradingApp
//
//  Common type definitions for the watchlist provider system
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

#pragma mark - Provider Category Types

typedef NS_ENUM(NSInteger, WatchlistProviderCategory) {
    WatchlistProviderCategoryManual,        // 📝 MY LISTS
    WatchlistProviderCategoryMarketLists,   // 📊 MARKET LISTS
    WatchlistProviderCategoryBaskets,       // 📅 BASKETS
    WatchlistProviderCategoryTagLists,      // 🏷️ TAG LISTS
    WatchlistProviderCategoryArchives       // 📦 ARCHIVES
};

#pragma mark - Market List Types

// Market list types for API calls
typedef NS_ENUM(NSInteger, MarketListType) {
    MarketListTypeTopGainers,
    MarketListTypeTopLosers,
    MarketListTypeEarnings,
    MarketListTypeETF,
    MarketListTypeIndustry
};

#pragma mark - Basket Types

// Basket types for interaction tracking
typedef NS_ENUM(NSInteger, BasketType) {
    BasketTypeToday,        // Symbols interacted with today
    BasketTypeWeek,         // Last 7 days (rolling)
    BasketTypeMonth         // Last 30 days (rolling)
};

NS_ASSUME_NONNULL_END
