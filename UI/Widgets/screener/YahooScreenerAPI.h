//
//  YahooScreenerAPI.h
//  TradingApp
//
//  Yahoo Finance Screener API Manager
//  Gestisce tutte le chiamate specifiche per lo screener widget
//

#import <Foundation/Foundation.h>


typedef NS_ENUM(NSInteger, YahooFilterComparison) {
    YahooFilterEqual,
    YahooFilterGreaterThan,
    YahooFilterLessThan,
    YahooFilterBetween
};
@class YahooScreenerResult, YahooScreenerFilter;

NS_ASSUME_NONNULL_BEGIN

// ============================================================================
// SCREENER PRESET TYPES
// ============================================================================

typedef NS_ENUM(NSInteger, YahooScreenerPreset) {
    YahooScreenerPresetMostActive,
    YahooScreenerPresetGainers,
    YahooScreenerPresetLosers,
    YahooScreenerPresetUndervalued,
    YahooScreenerPresetGrowthTech,
    YahooScreenerPresetHighDividend,
    YahooScreenerPresetSmallCapGrowth,
    YahooScreenerPresetMostShorted,
    YahooScreenerPresetCustom
};
// ============================================================================
// YAHOO SCREENER FILTER CLASS
// ============================================================================

@interface YahooScreenerFilter : NSObject
@property (nonatomic, strong) NSString *field;
@property (nonatomic, assign) YahooFilterComparison comparison;
@property (nonatomic, strong) NSArray *values;
@end
// ============================================================================
// SCREENER API MANAGER
// ============================================================================

@interface YahooScreenerAPI : NSObject

#pragma mark - Singleton

+ (instancetype)sharedManager;

#pragma mark - Configuration

@property (nonatomic, strong) NSString *baseURL;           // Default: your backend URL
@property (nonatomic, assign) NSTimeInterval timeout;      // Default: 30s
@property (nonatomic, assign) BOOL enableLogging;          // Default: YES

#pragma mark - Main Screener Methods

/**
 * Fetch results using predefined screener presets
 */
- (void)fetchScreenerResults:(YahooScreenerPreset)preset
                  maxResults:(NSInteger)maxResults
                  completion:(void (^)(NSArray<YahooScreenerResult *> *results, NSError *_Nullable error))completion;

/**
 * Fetch results with custom filters
 */
- (void)fetchCustomScreenerWithFilters:(NSArray<YahooScreenerFilter *> *)filters
                            maxResults:(NSInteger)maxResults
                            completion:(void (^)(NSArray<YahooScreenerResult *> *results, NSError *_Nullable error))completion;

/**
 * Quick screener with basic parameters
 */
- (void)fetchQuickScreener:(YahooScreenerPreset)preset
                 minVolume:(nullable NSNumber *)minVolume
              minMarketCap:(nullable NSNumber *)minMarketCap
                    sector:(nullable NSString *)sector
                maxResults:(NSInteger)maxResults
                completion:(void (^)(NSArray<YahooScreenerResult *> *results, NSError *_Nullable error))completion;



- (void)fetchAdvancedScreenerWithFilters:(NSArray<YahooScreenerFilter *> *)filters
                          combineWithBasic:(BOOL)combineWithBasic
                                maxResults:(NSInteger)maxResults
                              completion:(void (^)(NSArray<YahooScreenerResult *> *results, NSError *_Nullable error))completion;


#pragma mark - Utility Methods

/**
 * Get available sectors for filtering
 */
- (NSArray<NSString *> *)availableSectors;

/**
 * Get preset name for display
 */
- (NSString *)nameForPreset:(YahooScreenerPreset)preset;

/**
 * Check if backend service is available
 */
- (void)checkServiceAvailability:(void (^)(BOOL available, NSString *_Nullable version))completion;

#pragma mark - Cache Management

/**
 * Enable/disable result caching (default: 60 seconds)
 */
@property (nonatomic, assign) BOOL enableCaching;
@property (nonatomic, assign) NSTimeInterval cacheTimeout;

/**
 * Clear cached results
 */
- (void)clearCache;

@end

NS_ASSUME_NONNULL_END
