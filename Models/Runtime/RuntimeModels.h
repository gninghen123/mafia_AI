//
//  RuntimeModels.h
//  mafia_AI
//
//  Runtime models for UI - NOT Core Data
//  Thread-safe, performance-optimized, easy to test
//  Using "Model" suffix to avoid conflicts with Core Data entities
//

#import <Foundation/Foundation.h>
#import "CommonTypes.h"
#import "MarketData.h"

NS_ASSUME_NONNULL_BEGIN

// =======================================
// HISTORICAL BAR MODEL - RUNTIME
// =======================================

@interface HistoricalBarModel : NSObject

@property (nonatomic, strong) NSString *symbol;
@property (nonatomic, strong) NSDate *date;
@property (nonatomic, assign) double open;
@property (nonatomic, assign) double high;
@property (nonatomic, assign) double low;
@property (nonatomic, assign) double close;
@property (nonatomic, assign) double adjustedClose;
@property (nonatomic, assign) long long volume;
@property (nonatomic, assign) BarTimeframe timeframe;
@property (nonatomic, assign) BOOL isPaddingBar;  // YES if this is a future padding bar with no real data

// Convenience methods
- (double)typicalPrice;    // (high + low + close) / 3
- (double)range;          // high - low
- (double)midPoint;       // (high + low) / 2
- (BOOL)isGreen;          // close > open
- (BOOL)isRed;            // close < open
- (double)bodySize;       // abs(close - open)
- (double)upperShadow;    // high - max(open, close)
- (double)lowerShadow;    // min(open, close) - low

// Factory methods
+ (instancetype)barFromDictionary:(NSDictionary *)dict;
+ (NSArray<HistoricalBarModel *> *)barsFromDictionaries:(NSArray<NSDictionary *> *)dictionaries;

// Conversion
- (NSDictionary *)toDictionary;

// Comparison
- (NSComparisonResult)compareByDate:(HistoricalBarModel *)otherBar;
// Conversion

@end

// =======================================
// MARKET QUOTE MODEL - RUNTIME
// =======================================

@interface MarketQuoteModel : NSObject

@property (nonatomic, strong) NSString *symbol;
@property (nonatomic, strong) NSString * _Nullable name;
@property (nonatomic, strong) NSString * _Nullable exchange;

// Prices
@property (nonatomic, strong) NSNumber *last;
@property (nonatomic, strong) NSNumber * _Nullable bid;
@property (nonatomic, strong) NSNumber * _Nullable ask;
@property (nonatomic, strong) NSNumber * _Nullable open;
@property (nonatomic, strong) NSNumber * _Nullable high;
@property (nonatomic, strong) NSNumber * _Nullable low;
@property (nonatomic, strong) NSNumber * _Nullable close;
@property (nonatomic, strong) NSNumber * _Nullable previousClose;

// Changes
@property (nonatomic, strong) NSNumber * _Nullable change;
@property (nonatomic, strong) NSNumber * _Nullable changePercent;

// Volume
@property (nonatomic, strong) NSNumber * _Nullable volume;
@property (nonatomic, strong) NSNumber * _Nullable avgVolume;

// Market data
@property (nonatomic, strong) NSNumber * _Nullable marketCap;
@property (nonatomic, strong) NSNumber * _Nullable pe;
@property (nonatomic, strong) NSNumber * _Nullable eps;
@property (nonatomic, strong) NSNumber * _Nullable beta;

// Status
@property (nonatomic, strong) NSDate *timestamp;
@property (nonatomic, assign) BOOL isMarketOpen;

// Convenience methods
- (BOOL)isGainer;         // change > 0
- (BOOL)isLoser;          // change < 0
- (double)spread;         // ask - bid
- (double)midPrice;       // (bid + ask) / 2

// Factory methods
+ (instancetype)quoteFromDictionary:(NSDictionary *)dict;
+ (instancetype)quoteFromMarketData:(MarketData *)marketData;

// Conversion
- (NSDictionary *)toDictionary;

@end

// =======================================
// COMPANY INFO MODEL - RUNTIME
// =======================================

@interface CompanyInfoModel : NSObject

@property (nonatomic, strong) NSString *symbol;
@property (nonatomic, strong) NSString * _Nullable name;
@property (nonatomic, strong) NSString * _Nullable sector;
@property (nonatomic, strong) NSString * _Nullable industry;
@property (nonatomic, strong) NSString * _Nullable companyDescription;
@property (nonatomic, strong) NSString * _Nullable website;
@property (nonatomic, strong) NSString * _Nullable ceo;
@property (nonatomic, assign) NSInteger employees;
@property (nonatomic, strong) NSString * _Nullable headquarters;
@property (nonatomic, strong) NSDate * _Nullable lastUpdate;

// Factory methods
+ (instancetype)infoFromDictionary:(NSDictionary *)dict;

// Conversion
- (NSDictionary *)toDictionary;

@end

// =======================================
// WATCHLIST MODEL - RUNTIME
// =======================================

@interface WatchlistModel : NSObject

@property (nonatomic, strong) NSString *name;
@property (nonatomic, strong) NSString * _Nullable colorHex;
@property (nonatomic, strong) NSDate * _Nullable creationDate;
@property (nonatomic, strong) NSDate * _Nullable lastModified;
@property (nonatomic, assign) NSInteger sortOrder;
@property (nonatomic, strong) NSArray<NSString *> *symbols;

// Factory methods
+ (instancetype)watchlistFromDictionary:(NSDictionary *)dict;

// Conversion
- (NSDictionary *)toDictionary;

@end

// =======================================
// MARKET PERFORMER MODEL - RUNTIME
// =======================================

@interface MarketPerformerModel : NSObject

// Basic info
@property (nonatomic, strong) NSString *symbol;
@property (nonatomic, strong, nullable) NSString *name;
@property (nonatomic, strong, nullable) NSString *exchange;
@property (nonatomic, strong, nullable) NSString *sector;

// Price data
@property (nonatomic, strong, nullable) NSNumber *price;
@property (nonatomic, strong, nullable) NSNumber *change;
@property (nonatomic, strong, nullable) NSNumber *changePercent;
@property (nonatomic, strong, nullable) NSNumber *volume;

// Market data
@property (nonatomic, strong, nullable) NSNumber *marketCap;
@property (nonatomic, strong, nullable) NSNumber *avgVolume;

// List metadata
@property (nonatomic, strong) NSString *listType;  // "gainers", "losers", "etf"
@property (nonatomic, strong) NSString *timeframe; // "1d", "52w", etc.
@property (nonatomic, assign) NSInteger rank;      // Position in the list

// Timestamp
@property (nonatomic, strong) NSDate *timestamp;

// Factory methods
+ (instancetype)performerFromDictionary:(NSDictionary *)dict;
+ (NSArray<MarketPerformerModel *> *)performersFromDictionaries:(NSArray<NSDictionary *> *)dictionaries;

// Conversion
- (NSDictionary *)toDictionary;

// Convenience methods
- (BOOL)isGainer;
- (BOOL)isLoser;
- (NSString *)formattedPrice;
- (NSString *)formattedChange;
- (NSString *)formattedChangePercent;
- (NSString *)formattedVolume;
- (NSString *)formattedMarketCap;

@end

// =======================================
// ALERT MODEL - RUNTIME
// =======================================

@interface AlertModel : NSObject

// Basic properties
@property (nonatomic, strong) NSString *symbol;
@property (nonatomic, assign) double triggerValue;
@property (nonatomic, strong) NSString *conditionString; // "above", "below", "crosses_above", "crosses_below"
@property (nonatomic, assign) BOOL isActive;
@property (nonatomic, assign) BOOL isTriggered;
@property (nonatomic, assign) BOOL notificationEnabled;

// Metadata
@property (nonatomic, strong) NSString * _Nullable notes;
@property (nonatomic, strong) NSDate *creationDate;
@property (nonatomic, strong) NSDate * _Nullable triggerDate;

// Factory methods
+ (instancetype)alertFromDictionary:(NSDictionary *)dict;

// Conversion
- (NSDictionary *)toDictionary;

// Convenience methods
- (NSString *)formattedTriggerValue;
- (NSString *)statusString;
- (BOOL)shouldTriggerWithCurrentPrice:(double)currentPrice previousPrice:(double)previousPrice;

@end

NS_ASSUME_NONNULL_END

