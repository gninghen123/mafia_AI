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

NS_ASSUME_NONNULL_END

