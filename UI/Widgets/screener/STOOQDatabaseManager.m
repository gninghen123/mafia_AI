//
//  STOOQDatabaseManager.m
//  mafia_AI
//
//  Implementation of STOOQ Database Manager
//

#import "STOOQDatabaseManager.h"

#pragma mark - Stock Data Model Implementation

@implementation STOOQStockData

+ (instancetype)stockDataWithCSVLine:(NSString *)csvLine {
    NSArray *components = [csvLine componentsSeparatedByString:@","];
    if (components.count < 10) return nil;
    
    STOOQStockData *data = [[STOOQStockData alloc] init];
    
    // Parse symbol and category
    NSString *fullSymbol = components[0];
    NSArray *symbolParts = [fullSymbol componentsSeparatedByString:@"."];
    data.symbol = symbolParts[0];
    data.category = symbolParts.count > 1 ? symbolParts[1] : @"UNKNOWN";
    
    // Parse date (format: YYYYMMDD)
    NSString *dateStr = components[2];
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateFormat = @"yyyyMMdd";
    data.date = [formatter dateFromString:dateStr];
    
    // Parse OHLCV data
    data.open = [components[4] doubleValue];
    data.high = [components[5] doubleValue];
    data.low = [components[6] doubleValue];
    data.close = [components[7] doubleValue];
    data.volume = [components[8] doubleValue];
    data.openInt = [components[9] doubleValue];
    
    return data;
}

- (NSString *)toCSVLine {
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateFormat = @"yyyyMMdd";
    NSString *dateStr = [formatter stringFromDate:self.date];
    
    return [NSString stringWithFormat:@"%@.%@,D,%@,000000,%.6f,%.6f,%.6f,%.6f,%.0f,%.0f",
            self.symbol, self.category, dateStr,
            self.open, self.high, self.low, self.close, self.volume, self.openInt];
}

- (double)changePercent {
    // This would need previous day's close to calculate properly
    // For now, simple intraday change
    if (self.open == 0) return 0;
    return ((self.close - self.open) / self.open) * 100.0;
}

- (double)dollarVolume {
    return self.close * self.volume;
}

@end

#pragma mark - Database Manager Implementation

@interface STOOQDatabaseManager ()

@property (nonatomic, strong) NSString *databasePath;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSMutableArray<STOOQStockData *> *> *stockData;
@property (nonatomic, strong) NSMutableDictionary<NSString *, STOOQStockData *> *latestData;
@property (nonatomic, strong) NSMutableSet<NSString *> *availableCategories;

@end

@implementation STOOQDatabaseManager

#pragma mark - Singleton

+ (instancetype)sharedManager {
    static STOOQDatabaseManager *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[STOOQDatabaseManager alloc] init];
    });
    return sharedInstance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        // Setup database path
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);
        NSString *appSupportPath = paths.firstObject;
        NSString *appFolder = [appSupportPath stringByAppendingPathComponent:@"mafia_AI"];
        _databasePath = [appFolder stringByAppendingPathComponent:@"STOOQ_Database"];
        
        // Create directory if needed
        [[NSFileManager defaultManager] createDirectoryAtPath:_databasePath
                                  withIntermediateDirectories:YES
                                                   attributes:nil
                                                        error:nil];
        
        // Initialize data structures
        _stockData = [NSMutableDictionary dictionary];
        _latestData = [NSMutableDictionary dictionary];
        _availableCategories = [NSMutableSet set];
        
        NSLog(@"📊 STOOQDatabaseManager initialized at: %@", _databasePath);
    }
    return self;
}

#pragma mark - Database Management

- (BOOL)initializeDatabaseFromDownloads {
    NSLog(@"🔄 Starting database initialization from Downloads...");
    
    // Clear existing data
    [self.stockData removeAllObjects];
    [self.latestData removeAllObjects];
    [self.availableCategories removeAllObjects];
    
    // Get Downloads/data path
    NSString *downloadsPath = [NSHomeDirectory() stringByAppendingPathComponent:@"Downloads/data"];
    
    if (![[NSFileManager defaultManager] fileExistsAtPath:downloadsPath]) {
        NSLog(@"❌ Downloads/data folder not found: %@", downloadsPath);
        return NO;
    }
    
    NSError *error;
    NSUInteger totalFiles = 0;
    NSUInteger processedFiles = 0;
    
    // Recursively process all .txt files
    NSDirectoryEnumerator *enumerator = [[NSFileManager defaultManager] enumeratorAtPath:downloadsPath];
    NSString *relativePath;
    
    while ((relativePath = [enumerator nextObject])) {
        if (![relativePath.pathExtension.lowercaseString isEqualToString:@"txt"]) continue;
        
        totalFiles++;
        NSString *fullPath = [downloadsPath stringByAppendingPathComponent:relativePath];
        
        if ([self processHistoricalFile:fullPath]) {
            processedFiles++;
        }
        
        // Progress logging every 100 files
        if (totalFiles % 100 == 0) {
            NSLog(@"📈 Processed %lu/%lu files...", (unsigned long)processedFiles, (unsigned long)totalFiles);
        }
    }
    
    NSLog(@"✅ Database initialization complete: %lu/%lu files processed", (unsigned long)processedFiles, (unsigned long)totalFiles);
    NSLog(@"📊 Database contains %lu symbols, %lu categories", (unsigned long)self.stockData.count, (unsigned long)self.availableCategories.count);
    
    return processedFiles > 0;
}

- (BOOL)updateDatabaseWithFile:(NSString *)filePath {
    NSLog(@"🔄 Updating database with file: %@", filePath.lastPathComponent);
    
    if (![[NSFileManager defaultManager] fileExistsAtPath:filePath]) {
        NSLog(@"❌ Update file not found: %@", filePath);
        return NO;
    }
    
    NSError *error;
    NSString *content = [NSString stringWithContentsOfFile:filePath encoding:NSUTF8StringEncoding error:&error];
    
    if (error) {
        NSLog(@"❌ Error reading update file: %@", error.localizedDescription);
        return NO;
    }
    
    NSArray *lines = [content componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
    NSUInteger updatedCount = 0;
    
    for (NSString *line in lines) {
        if (line.length == 0 || [line hasPrefix:@"<"]) continue;
        
        STOOQStockData *stockData = [STOOQStockData stockDataWithCSVLine:line];
        if (!stockData) continue;
        
        // Add to historical data
        NSString *key = [NSString stringWithFormat:@"%@.%@", stockData.symbol, stockData.category];
        
        if (!self.stockData[key]) {
            self.stockData[key] = [NSMutableArray array];
        }
        
        // Check if this date already exists
        BOOL dateExists = NO;
        for (STOOQStockData *existing in self.stockData[key]) {
            if ([existing.date isEqualToDate:stockData.date]) {
                dateExists = YES;
                break;
            }
        }
        
        if (!dateExists) {
            [self.stockData[key] addObject:stockData];
            
            // Update latest data if this is more recent
            STOOQStockData *currentLatest = self.latestData[key];
            if (!currentLatest || [stockData.date compare:currentLatest.date] == NSOrderedDescending) {
                self.latestData[key] = stockData;
            }
            
            [self.availableCategories addObject:stockData.category];
            updatedCount++;
        }
    }
    
    NSLog(@"✅ Update complete: %lu new records added", (unsigned long)updatedCount);
    return updatedCount > 0;
}

- (NSDictionary *)getDatabaseStatus {
    return @{
        @"totalSymbols": @(self.stockData.count),
        @"totalCategories": @(self.availableCategories.count),
        @"databasePath": self.databasePath,
        @"lastUpdate": self.lastUpdateDate ?: [NSNull null],
        @"databaseSizeMB": @([self getDatabaseSizeMB]),
        @"isInitialized": @(self.isDatabaseInitialized)
    };
}

#pragma mark - Data Access

- (NSArray<STOOQStockData *> *)getAllLatestStockData {
    return [self.latestData.allValues copy];
}

- (NSArray<STOOQStockData *> *)getHistoricalDataForSymbol:(NSString *)symbol {
    NSMutableArray *results = [NSMutableArray array];
    
    // Search all categories for this symbol
    for (NSString *key in self.stockData.allKeys) {
        if ([key hasPrefix:[symbol stringByAppendingString:@"."]]) {
            [results addObjectsFromArray:self.stockData[key]];
        }
    }
    
    // Sort by date
    [results sortUsingComparator:^NSComparisonResult(STOOQStockData *obj1, STOOQStockData *obj2) {
        return [obj1.date compare:obj2.date];
    }];
    
    return [results copy];
}

- (NSArray<STOOQStockData *> *)searchStocksWithMinChange:(nullable NSNumber *)minChange
                                               minVolume:(nullable NSNumber *)minVolume
                                              categories:(nullable NSArray<NSString *> *)categories {
    NSMutableArray *results = [NSMutableArray array];
    
    for (STOOQStockData *stockData in [self getAllLatestStockData]) {
        // Category filter
        if (categories && categories.count > 0 && ![categories containsObject:stockData.category]) {
            continue;
        }
        
        // Change filter
        if (minChange && stockData.changePercent < minChange.doubleValue) {
            continue;
        }
        
        // Volume filter
        if (minVolume && stockData.volume < minVolume.doubleValue) {
            continue;
        }
        
        [results addObject:stockData];
    }
    
    return [results copy];
}

#pragma mark - Utility Methods

- (NSArray<NSString *> *)getAvailableCategories {
    return [self.availableCategories.allObjects sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
}

- (void)clearDatabase {
    NSLog(@"🗑️ Clearing STOOQ database...");
    [self.stockData removeAllObjects];
    [self.latestData removeAllObjects];
    [self.availableCategories removeAllObjects];
}

- (double)getDatabaseSizeMB {
    NSUInteger totalRecords = 0;
    for (NSArray *records in self.stockData.allValues) {
        totalRecords += records.count;
    }
    // Rough estimate: ~100 bytes per record
    return (totalRecords * 100.0) / (1024.0 * 1024.0);
}

- (BOOL)isDatabaseInitialized {
    return self.stockData.count > 0;
}

- (NSUInteger)totalStocksCount {
    return self.stockData.count;
}

- (NSDate *)lastUpdateDate {
    NSDate *latestDate = nil;
    
    for (STOOQStockData *data in self.latestData.allValues) {
        if (!latestDate || [data.date compare:latestDate] == NSOrderedDescending) {
            latestDate = data.date;
        }
    }
    
    return latestDate;
}

#pragma mark - Private Methods

- (BOOL)processHistoricalFile:(NSString *)filePath {
    NSError *error;
    NSString *content = [NSString stringWithContentsOfFile:filePath encoding:NSUTF8StringEncoding error:&error];
    
    if (error) {
        NSLog(@"⚠️ Could not read file %@: %@", filePath.lastPathComponent, error.localizedDescription);
        return NO;
    }
    
    NSArray *lines = [content componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
    NSString *key = nil;
    NSMutableArray *fileData = [NSMutableArray array];
    
    for (NSString *line in lines) {
        if (line.length == 0 || [line hasPrefix:@"<"]) continue;
        
        STOOQStockData *stockData = [STOOQStockData stockDataWithCSVLine:line];
        if (!stockData) continue;
        
        if (!key) {
            key = [NSString stringWithFormat:@"%@.%@", stockData.symbol, stockData.category];
        }
        
        [fileData addObject:stockData];
        [self.availableCategories addObject:stockData.category];
    }
    
    if (key && fileData.count > 0) {
        self.stockData[key] = fileData;
        
        // Update latest data with the most recent date
        STOOQStockData *latestInFile = [fileData lastObject]; // Assuming files are date-sorted
        self.latestData[key] = latestInFile;
        
        return YES;
    }
    
    return NO;
}

@end
