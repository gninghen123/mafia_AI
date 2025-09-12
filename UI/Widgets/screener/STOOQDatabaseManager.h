//
//  STOOQDatabaseManager.h
//  mafia_AI
//
//  STOOQ Database Manager per gestione banca dati storica e aggiornamenti
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

#pragma mark - Stock Data Model

@interface STOOQStockData : NSObject

@property (nonatomic, strong) NSString *symbol;
@property (nonatomic, strong) NSString *category;        // es: "US", "nasdaq stocks"
@property (nonatomic, strong) NSDate *date;
@property (nonatomic, assign) double open;
@property (nonatomic, assign) double high;
@property (nonatomic, assign) double low;
@property (nonatomic, assign) double close;
@property (nonatomic, assign) double volume;
@property (nonatomic, assign) double openInt;

// Calculated fields
@property (nonatomic, readonly) double changePercent;    // vs previous close
@property (nonatomic, readonly) double dollarVolume;     // close * volume

+ (instancetype)stockDataWithCSVLine:(NSString *)csvLine;
- (NSString *)toCSVLine;

@end

#pragma mark - Database Manager

@interface STOOQDatabaseManager : NSObject

@property (nonatomic, readonly) NSString *databasePath;
@property (nonatomic, readonly) BOOL isDatabaseInitialized;
@property (nonatomic, readonly) NSUInteger totalStocksCount;
@property (nonatomic, readonly) NSDate *lastUpdateDate;

#pragma mark - Singleton

+ (instancetype)sharedManager;

#pragma mark - Database Management

/**
 * Initialize database from local Downloads folder
 * @return YES if successful
 */
- (BOOL)initializeDatabaseFromLocalDownloads;

/**
 * Check for and process daily update files in Downloads folder
 * @return Number of files processed
 */
- (NSInteger)processAvailableUpdates;

/**
 * Update database with daily file
 * @param filePath Path to daily update file
 * @return YES if successful
 */
- (BOOL)updateDatabaseWithFile:(NSString *)filePath;

/**
 * Get database status info
 * @return Dictionary with stats
 */
- (NSDictionary *)getDatabaseStatus;

#pragma mark - Data Access

/**
 * Get all stocks for screening (latest data only)
 * @return Array of STOOQStockData with latest prices
 */
- (NSArray<STOOQStockData *> *)getAllLatestStockData;

/**
 * Get historical data for specific symbol
 * @param symbol Stock symbol
 * @return Array of STOOQStockData ordered by date
 */
- (NSArray<STOOQStockData *> *)getHistoricalDataForSymbol:(NSString *)symbol;

/**
 * Search stocks by criteria
 * @param minChange Minimum change percentage (or nil)
 * @param minVolume Minimum volume (or nil)
 * @param categories Array of category filters (or nil for all)
 * @return Filtered array of STOOQStockData
 */
- (NSArray<STOOQStockData *> *)searchStocksWithMinChange:(nullable NSNumber *)minChange
                                               minVolume:(nullable NSNumber *)minVolume
                                              categories:(nullable NSArray<NSString *> *)categories;

#pragma mark - Utility Methods

/**
 * Get available categories
 * @return Array of category strings
 */
- (NSArray<NSString *> *)getAvailableCategories;

/**
 * Clear entire database
 */
- (void)clearDatabase;

/**
 * Get database file size
 * @return Size in MB
 */
- (double)getDatabaseSizeMB;

@end

NS_ASSUME_NONNULL_END
