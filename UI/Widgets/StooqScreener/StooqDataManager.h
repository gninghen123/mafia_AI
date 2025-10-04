//
//  StooqDataManager.h
//  TradingApp
//
//  Manages loading data from Stooq CSV database
//

#import <Foundation/Foundation.h>
#import "RuntimeModels.h"

NS_ASSUME_NONNULL_BEGIN

@interface StooqDataManager : NSObject

#pragma mark - Configuration

/// Root directory of Stooq data (e.g., "/path/to/data/")
@property (nonatomic, strong) NSString *dataDirectory;

/// Exchanges to include (e.g., @[@"nasdaq", @"nyse"])
@property (nonatomic, strong) NSArray<NSString *> *selectedExchanges;

@property (nonatomic, strong, nullable) NSDate *targetDate;  // Data target per lo screening


#pragma mark - Initialization

- (instancetype)initWithDataDirectory:(NSString *)dataDirectory;

#pragma mark - Database Scanning

/**
 * Scan database and build symbol index
 * @param completion Called when scan is complete with list of symbols
 */
- (void)scanDatabaseWithCompletion:(void (^)(NSArray<NSString *> *symbols, NSError *_Nullable error))completion;

/**
 * Get all available symbols (must call scanDatabase first)
 */
- (NSArray<NSString *> *)availableSymbols;

/**
 * Get symbol count
 */
- (NSInteger)symbolCount;

- (NSDate *)expectedLastCloseDate;

#pragma mark - Data Loading

/**
 * Load data for specific symbols with minimum bars required
 * @param symbols Array of symbol strings
 * @param minBars Minimum number of bars to load (from end of file)
 * @param completion Called when loading is complete
 * @return Dictionary: symbol → array of HistoricalBarModel
 */
- (void)loadDataForSymbols:(NSArray<NSString *> *)symbols
                   minBars:(NSInteger)minBars
                completion:(void (^)(NSDictionary<NSString *, NSArray<HistoricalBarModel *> *> *cache, NSError *_Nullable error))completion;

/**
 * Load data for single symbol
 * @param symbol Symbol to load
 * @param minBars Minimum bars required
 * @return Array of HistoricalBarModel or nil if error
 */
- (nullable NSArray<HistoricalBarModel *> *)loadBarsForSymbol:(NSString *)symbol
                                                       minBars:(NSInteger)minBars;

#pragma mark - CSV Parsing

/**
 * Parse Stooq CSV file
 * Format: <TICKER>,<PER>,<DATE>,<TIME>,<OPEN>,<HIGH>,<LOW>,<CLOSE>,<VOL>,<OPENINT>
 * @param filePath Path to CSV file
 * @param symbol Symbol name
 * @param maxBars Maximum bars to load (from end, 0 = all)
 * @return Array of HistoricalBarModel
 */
- (nullable NSArray<HistoricalBarModel *> *)parseCSVFile:(NSString *)filePath
                                                  symbol:(NSString *)symbol
                                                 maxBars:(NSInteger)maxBars;

#pragma mark - File Path Resolution

/**
 * Get file path for symbol
 * @param symbol Symbol (e.g., "AAPL.US")
 * @return Full path to CSV file or nil if not found
 */
- (nullable NSString *)filePathForSymbol:(NSString *)symbol;

/**
 * Extract exchange from symbol
 * @param symbol Symbol (e.g., "AAPL.US" → "us")
 * @return Exchange name in lowercase
 */
- (NSString *)exchangeFromSymbol:(NSString *)symbol;

/**
 * Get symbols for specific exchange
 * @param exchange Exchange name (e.g., "nasdaq", "nyse")
 * @return Array of symbols
 */
- (NSArray<NSString *> *)symbolsForExchange:(NSString *)exchange;

@end

NS_ASSUME_NONNULL_END
