// ========================================================================
// StorageMetadataCache.m
// ========================================================================

#import "StorageMetadataCache.h"
#import "SavedChartData+FilenameParsing.h"

@implementation StorageMetadataItem

#pragma mark - Factory Methods

+ (instancetype)itemFromFilePath:(NSString *)filePath {
    StorageMetadataItem *item = [[StorageMetadataItem alloc] init];
    item.filePath = filePath;
    item.filename = [filePath lastPathComponent];
    
    // Get file attributes
    NSFileManager *fm = [NSFileManager defaultManager];
    NSDictionary *attrs = [fm attributesOfItemAtPath:filePath error:nil];
    if (attrs) {
        item.fileModificationTime = [attrs[NSFileModificationDate] timeIntervalSince1970];
        item.fileSizeBytes = [attrs[NSFileSize] integerValue];
    }
    
    // Parse metadata from filename
    [item parseMetadataFromFilename];
    
    item.cacheTime = [[NSDate date] timeIntervalSince1970];
    
    return item;
}

+ (instancetype)itemFromDictionary:(NSDictionary *)dict {
    StorageMetadataItem *item = [[StorageMetadataItem alloc] init];
    
    item.filePath = dict[@"filePath"];
    item.filename = dict[@"filename"];
    item.fileModificationTime = [dict[@"fileModificationTime"] doubleValue];
    item.fileSizeBytes = [dict[@"fileSizeBytes"] integerValue];
    
    item.symbol = dict[@"symbol"];
    item.timeframe = dict[@"timeframe"];
    item.dataType = [dict[@"dataType"] integerValue];
    item.barCount = [dict[@"barCount"] integerValue];
    item.startDate = [dict[@"startDate"] doubleValue] >0 ? [NSDate dateWithTimeIntervalSince1970:[dict[@"startDate"] doubleValue]] : nil;
    item.endDate = [dict[@"endDate"] doubleValue] >0 ? [NSDate dateWithTimeIntervalSince1970:[dict[@"endDate"] doubleValue]] : nil;
    item.creationDate = [dict[@"creationDate"] doubleValue] > 0 ? [NSDate dateWithTimeIntervalSince1970:[dict[@"creationDate"] doubleValue]] : nil;
    item.lastUpdate = [dict[@"lastUpdate"] doubleValue] > 0 ? [NSDate dateWithTimeIntervalSince1970:[dict[@"lastUpdate"] doubleValue]] : nil;
    item.includesExtendedHours = [dict[@"includesExtendedHours"] boolValue];
    item.hasGaps = [dict[@"hasGaps"] boolValue];
    item.isNewFormat = [dict[@"isNewFormat"] boolValue];
    item.cacheTime = [dict[@"cacheTime"] doubleValue];
    
    return item;
}

- (NSDictionary *)toDictionary {
    return @{
        @"filePath": self.filePath ?: @"",
        @"filename": self.filename ?: @"",
        @"fileModificationTime": @(self.fileModificationTime),
        @"fileSizeBytes": @(self.fileSizeBytes),
        @"symbol": self.symbol ?: @"",
        @"timeframe": self.timeframe ?: @"",
        @"dataType": @(self.dataType),
        @"barCount": @(self.barCount),
        @"startDate": self.startDate ? @([self.startDate timeIntervalSince1970]) : @0,
                @"endDate": self.endDate ? @([self.endDate timeIntervalSince1970]) : @0,
        @"creationDate": self.creationDate ? @([self.creationDate timeIntervalSince1970]) : @0,
        @"lastUpdate": self.lastUpdate ? @([self.lastUpdate timeIntervalSince1970]) : @0,
        @"includesExtendedHours": @(self.includesExtendedHours),
        @"hasGaps": @(self.hasGaps),
        @"isNewFormat": @(self.isNewFormat),
        @"cacheTime": @(self.cacheTime)
    };
}

#pragma mark - Metadata Parsing

- (void)parseMetadataFromFilename {
    self.isNewFormat = [SavedChartData isNewFormatFilename:self.filename];
    
    if (self.isNewFormat) {
        // Fast filename parsing
        self.symbol = [SavedChartData symbolFromFilename:self.filename] ?: @"Unknown";
        self.timeframe = [SavedChartData timeframeFromFilename:self.filename] ?: @"Unknown";
        
        NSString *typeStr = [SavedChartData typeFromFilename:self.filename];
        self.dataType = [typeStr isEqualToString:@"Continuous"] ? SavedChartDataTypeContinuous : SavedChartDataTypeSnapshot;
        
        self.barCount = [SavedChartData barCountFromFilename:self.filename];
        self.startDate = [SavedChartData startDateFromFilename:self.filename];
        self.endDate = [SavedChartData endDateFromFilename:self.filename];
        self.creationDate = [SavedChartData creationDateFromFilename:self.filename];
        self.lastUpdate = [SavedChartData lastUpdateFromFilename:self.filename];
        self.includesExtendedHours = [SavedChartData extendedHoursFromFilename:self.filename];
        self.hasGaps = [SavedChartData hasGapsFromFilename:self.filename];
    } else {
        // Old format - set defaults
        self.symbol = @"Unknown";
        self.timeframe = @"Unknown";
        self.dataType = SavedChartDataTypeSnapshot; // Assume old files are snapshots
        self.barCount = 0;
        self.includesExtendedHours = NO;
        self.hasGaps = NO;
    }
}

#pragma mark - Update Methods

- (BOOL)updateFromFilesystem {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSDictionary *attrs = [fm attributesOfItemAtPath:self.filePath error:nil];
    
    if (!attrs) {
        return NO; // File doesn't exist
    }
    
    NSTimeInterval newModTime = [attrs[NSFileModificationDate] timeIntervalSince1970];
    NSInteger newSize = [attrs[NSFileSize] integerValue];
    
    if (newModTime != self.fileModificationTime || newSize != self.fileSizeBytes) {
        self.fileModificationTime = newModTime;
        self.fileSizeBytes = newSize;
        
        // Re-parse metadata in case filename changed
        [self parseMetadataFromFilename];
        self.cacheTime = [[NSDate date] timeIntervalSince1970];
        
        return YES; // Updated
    }
    
    return NO; // No changes
}

- (BOOL)needsRefreshFromFilesystem {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSDictionary *attrs = [fm attributesOfItemAtPath:self.filePath error:nil];
    
    if (!attrs) return YES; // File missing
    
    NSTimeInterval fileModTime = [attrs[NSFileModificationDate] timeIntervalSince1970];
    return fileModTime != self.fileModificationTime;
}

#pragma mark - Convenience Properties

- (BOOL)isContinuous {
    return self.dataType == SavedChartDataTypeContinuous;
}

- (BOOL)isSnapshot {
    return self.dataType == SavedChartDataTypeSnapshot;
}

- (NSString *)displayName {
    return [NSString stringWithFormat:@"%@ [%@]", self.symbol, self.timeframe];
}

- (NSString *)dateRangeString {
    if (!self.startDate || !self.endDate) return @"Unknown range";
    
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateFormat = @"MMM d";
    
    return [NSString stringWithFormat:@"%@ - %@",
            [formatter stringFromDate:self.startDate],
            [formatter stringFromDate:self.endDate]];
}

@end

// ========================================================================

@interface StorageMetadataCache ()
@property (nonatomic, strong) NSMutableDictionary<NSString *, StorageMetadataItem *> *cache;
@property (nonatomic, strong) dispatch_queue_t cacheQueue;
@end

@implementation StorageMetadataCache

+ (instancetype)sharedCache {
    static StorageMetadataCache *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _cache = [NSMutableDictionary dictionary];
        _cacheQueue = dispatch_queue_create("StorageMetadataCache", DISPATCH_QUEUE_CONCURRENT);
    }
    return self;
}

#pragma mark - Cache Management

- (void)buildCacheFromDirectory:(NSString *)directory {
    NSLog(@"📦 Building storage metadata cache from: %@", directory);
    
    dispatch_barrier_async(self.cacheQueue, ^{
        NSFileManager *fm = [NSFileManager defaultManager];
        NSArray<NSString *> *files = [fm contentsOfDirectoryAtPath:directory error:nil];
        
        NSMutableDictionary *newCache = [NSMutableDictionary dictionary];
        NSInteger processed = 0;
        
        for (NSString *filename in files) {
            if ([filename hasSuffix:@".chartdata"]) {
                NSString *filePath = [directory stringByAppendingPathComponent:filename];
                StorageMetadataItem *item = [StorageMetadataItem itemFromFilePath:filePath];
                
                if (item) {
                    newCache[filePath] = item;
                    processed++;
                }
            }
        }
        
        self.cache = newCache;
        
        dispatch_async(dispatch_get_main_queue(), ^{
            NSLog(@"✅ Metadata cache built: %ld items processed", (long)processed);
        });
    });
}

- (void)addOrUpdateItem:(StorageMetadataItem *)item {
    if (!item || !item.filePath) return;
    
    dispatch_barrier_async(self.cacheQueue, ^{
        self.cache[item.filePath] = item;
    });
}

- (void)removeItemForPath:(NSString *)filePath {
    if (!filePath) return;
    
    dispatch_barrier_async(self.cacheQueue, ^{
        [self.cache removeObjectForKey:filePath];
    });
}

- (void)removeItemForFilename:(NSString *)filename {
    if (!filename) return;
    
    dispatch_barrier_async(self.cacheQueue, ^{
        NSString *keyToRemove = nil;
        for (NSString *path in self.cache) {
            if ([[path lastPathComponent] isEqualToString:filename]) {
                keyToRemove = path;
                break;
            }
        }
        if (keyToRemove) {
            [self.cache removeObjectForKey:keyToRemove];
        }
    });
}

#pragma mark - Query Methods

- (NSArray<StorageMetadataItem *> *)allItems {
    __block NSArray *result;
    dispatch_sync(self.cacheQueue, ^{
        result = [self.cache.allValues copy];
    });
    return result;
}

- (NSArray<StorageMetadataItem *> *)continuousItems {
    return [self.allItems filteredArrayUsingPredicate:
            [NSPredicate predicateWithFormat:@"dataType == %d", SavedChartDataTypeContinuous]];
}

- (NSArray<StorageMetadataItem *> *)snapshotItems {
    return [self.allItems filteredArrayUsingPredicate:
            [NSPredicate predicateWithFormat:@"dataType == %d", SavedChartDataTypeSnapshot]];
}

- (NSInteger)totalCount {
    __block NSInteger count;
    dispatch_sync(self.cacheQueue, ^{
        count = self.cache.count;
    });
    return count;
}

- (nullable StorageMetadataItem *)itemForPath:(NSString *)filePath {
    __block StorageMetadataItem *result;
    dispatch_sync(self.cacheQueue, ^{
        result = self.cache[filePath];
    });
    return result;
}

- (nullable StorageMetadataItem *)itemForFilename:(NSString *)filename {
    __block StorageMetadataItem *result;
    dispatch_sync(self.cacheQueue, ^{
        for (StorageMetadataItem *item in self.cache.allValues) {
            if ([item.filename isEqualToString:filename]) {
                result = item;
                break;
            }
        }
    });
    return result;
}

- (NSArray<StorageMetadataItem *> *)itemsForSymbol:(NSString *)symbol {
    return [self.allItems filteredArrayUsingPredicate:
            [NSPredicate predicateWithFormat:@"symbol LIKE[c] %@", symbol]];
}

#pragma mark - File Operations Callbacks

- (void)handleFileCreated:(NSString *)filePath {
    StorageMetadataItem *item = [StorageMetadataItem itemFromFilePath:filePath];
    if (item) {
        [self addOrUpdateItem:item];
        NSLog(@"📦 Cache: Added new item %@", item.displayName);
    }
}

- (void)handleFileUpdated:(NSString *)filePath {
    StorageMetadataItem *existingItem = [self itemForPath:filePath];
    if (existingItem) {
        if ([existingItem updateFromFilesystem]) {
            NSLog(@"📦 Cache: Updated item %@", existingItem.displayName);
        }
    } else {
        [self handleFileCreated:filePath]; // Fallback
    }
}

- (void)handleFileDeleted:(NSString *)filePath {
    [self removeItemForPath:filePath];
    NSLog(@"📦 Cache: Removed item for path %@", [filePath lastPathComponent]);
}

- (void)handleFileRenamed:(NSString *)oldPath newPath:(NSString *)newPath {
    [self removeItemForPath:oldPath];
    [self handleFileCreated:newPath];
    NSLog(@"📦 Cache: Renamed %@ -> %@", [oldPath lastPathComponent], [newPath lastPathComponent]);
}

#pragma mark - Consistency Check

- (void)performConsistencyCheck:(NSString *)directory completion:(void(^)(NSInteger inconsistencies))completion {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        NSLog(@"🔍 Starting consistency check...");
        
        NSInteger inconsistencies = 0;
        NSFileManager *fm = [NSFileManager defaultManager];
        NSArray<NSString *> *filesOnDisk = [fm contentsOfDirectoryAtPath:directory error:nil];
        
        // Check for missing files in cache
        for (NSString *filename in filesOnDisk) {
            if ([filename hasSuffix:@".chartdata"]) {
                NSString *filePath = [directory stringByAppendingPathComponent:filename];
                StorageMetadataItem *cachedItem = [self itemForPath:filePath];
                
                if (!cachedItem) {
                    // File exists but not in cache
                    [self handleFileCreated:filePath];
                    inconsistencies++;
                } else if ([cachedItem needsRefreshFromFilesystem]) {
                    // File modified since cache
                    [cachedItem updateFromFilesystem];
                    inconsistencies++;
                }
            }
        }
        
        // Check for stale items in cache
        NSArray *cachedItems = [self allItems];
        for (StorageMetadataItem *item in cachedItems) {
            if (![fm fileExistsAtPath:item.filePath]) {
                [self removeItemForPath:item.filePath];
                inconsistencies++;
            }
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            NSLog(@"✅ Consistency check complete: %ld inconsistencies found and fixed", (long)inconsistencies);
            if (completion) completion(inconsistencies);
        });
    });
}

#pragma mark - Persistence

- (void)saveToUserDefaults {
    NSArray *items = [self allItems];
    NSMutableArray *serialized = [NSMutableArray array];
    
    for (StorageMetadataItem *item in items) {
        [serialized addObject:[item toDictionary]];
    }
    
    [[NSUserDefaults standardUserDefaults] setObject:serialized forKey:@"StorageMetadataCache"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    NSLog(@"💾 Saved metadata cache: %ld items", (long)items.count);
}

- (void)loadFromUserDefaults {
    NSArray *serialized = [[NSUserDefaults standardUserDefaults] objectForKey:@"StorageMetadataCache"];
    
    if (!serialized) {
        NSLog(@"📦 No cached metadata found in UserDefaults");
        return;
    }
    
    dispatch_barrier_async(self.cacheQueue, ^{
        NSMutableDictionary *loadedCache = [NSMutableDictionary dictionary];
        
        for (NSDictionary *dict in serialized) {
            StorageMetadataItem *item = [StorageMetadataItem itemFromDictionary:dict];
            if (item && item.filePath) {
                loadedCache[item.filePath] = item;
            }
        }
        
        self.cache = loadedCache;
        
        dispatch_async(dispatch_get_main_queue(), ^{
            NSLog(@"📦 Loaded metadata cache: %ld items from UserDefaults", (long)loadedCache.count);
        });
    });
}

- (void)clearCache {
    dispatch_barrier_async(self.cacheQueue, ^{
        [self.cache removeAllObjects];
    });
    
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"StorageMetadataCache"];
    NSLog(@"🗑️ Cleared metadata cache");
}

#pragma mark - Statistics

- (NSDictionary *)cacheStatistics {
    NSArray *items = [self allItems];
    NSInteger continuous = [self continuousItems].count;
    NSInteger snapshots = [self snapshotItems].count;
    
    return @{
        @"totalItems": @(items.count),
        @"continuousStorage": @(continuous),
        @"snapshotStorage": @(snapshots),
        @"cacheMemoryEstimate": @(items.count * 500), // Rough estimate in bytes
    };
}

@end
