//
//  StooqDataManager.m
//  TradingApp
//

#import "StooqDataManager.h"

@interface StooqDataManager ()
@property (nonatomic, strong) NSMutableArray<NSString *> *symbolIndex;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSString *> *symbolToFilePath;
@end

@implementation StooqDataManager

#pragma mark - Initialization

- (instancetype)initWithDataDirectory:(NSString *)dataDirectory {
    self = [super init];
    if (self) {
        _dataDirectory = dataDirectory;
        _selectedExchanges = @[@"nasdaq", @"nyse"];  // Default US exchanges
        _symbolIndex = [NSMutableArray array];
        _symbolToFilePath = [NSMutableDictionary dictionary];
    }
    return self;
}

#pragma mark - Database Scanning

- (void)scanDatabaseWithCompletion:(void (^)(NSArray<NSString *> *, NSError *))completion {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSLog(@"🔍 Scanning Stooq database at: %@", self.dataDirectory);
        
        [self.symbolIndex removeAllObjects];
        [self.symbolToFilePath removeAllObjects];
        
        NSFileManager *fm = [NSFileManager defaultManager];
        
        // Check if data directory exists
        BOOL isDir;
        if (![fm fileExistsAtPath:self.dataDirectory isDirectory:&isDir] || !isDir) {
            NSError *error = [NSError errorWithDomain:@"StooqDataManager"
                                                 code:1001
                                             userInfo:@{NSLocalizedDescriptionKey: @"Data directory does not exist"}];
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(@[], error);
            });
            return;
        }
        
        // Check for "daily" subdirectory (new Stooq structure)
        NSString *dailyDir = [self.dataDirectory stringByAppendingPathComponent:@"daily"];
        BOOL hasDailyDir = [fm fileExistsAtPath:dailyDir isDirectory:&isDir] && isDir;
        
        if (hasDailyDir) {
            NSLog(@"📁 Found 'daily' directory, using new structure");
            
            // New structure: data/daily/us/nasdaq stocks/...
            NSString *usDir = [dailyDir stringByAppendingPathComponent:@"us"];
            
            NSLog(@"🔍 Checking US directory: %@", usDir);
            
            if ([fm fileExistsAtPath:usDir isDirectory:&isDir] && isDir) {
                NSLog(@"✅ US directory exists");
                
                // Scan all subdirectories in us/
                NSError *error;
                NSArray *subdirs = [fm contentsOfDirectoryAtPath:usDir error:&error];
                
                if (!subdirs) {
                    NSLog(@"❌ Could not read US directory: %@", error.localizedDescription);
                } else {
                    NSLog(@"📂 Found %lu subdirectories in US", (unsigned long)subdirs.count);
                    
                    for (NSString *subdir in subdirs) {
                        NSLog(@"  📁 Checking: %@", subdir);
                        
                        NSString *subdirPath = [usDir stringByAppendingPathComponent:subdir];
                        
                        if ([fm fileExistsAtPath:subdirPath isDirectory:&isDir] && isDir) {
                            // Extract exchange type (nasdaq stocks, nyse stocks, etc.)
                            NSString *exchangeType = [subdir lowercaseString];
                            
                            // Only process if it matches selected exchanges
                            BOOL shouldProcess = NO;
                            for (NSString *exchange in self.selectedExchanges) {
                                if ([exchangeType containsString:exchange]) {
                                    shouldProcess = YES;
                                    break;
                                }
                            }
                            
                            NSLog(@"  %@ Should process '%@': %@",
                                  shouldProcess ? @"✅" : @"⏭️",
                                  subdir,
                                  shouldProcess ? @"YES" : @"NO");
                            
                            if (shouldProcess) {
                                NSLog(@"📊 Scanning: %@", subdir);
                                [self scanExchangeDirectory:subdirPath exchange:subdir];
                            }
                        } else {
                            NSLog(@"  ⚠️ Not a directory: %@", subdir);
                        }
                    }
                }
            } else {
                NSLog(@"❌ US directory not found or not accessible: %@", usDir);
            }
        } else {
            // Old structure: data/nasdaq/...
            NSLog(@"📁 Using old directory structure");
            
            for (NSString *exchange in self.selectedExchanges) {
                NSString *exchangeDir = [self.dataDirectory stringByAppendingPathComponent:exchange];
                
                if (![fm fileExistsAtPath:exchangeDir isDirectory:&isDir] || !isDir) {
                    NSLog(@"⚠️ Exchange directory not found: %@", exchange);
                    continue;
                }
                
                [self scanExchangeDirectory:exchangeDir exchange:exchange];
            }
        }
        
        NSLog(@"✅ Scan complete. Found %lu symbols", (unsigned long)self.symbolIndex.count);
        
        dispatch_async(dispatch_get_main_queue(), ^{
            completion([self.symbolIndex copy], nil);
        });
    });
}

- (void)scanExchangeDirectory:(NSString *)exchangeDir exchange:(NSString *)exchange {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSError *error;
    
    NSLog(@"  🔎 scanExchangeDirectory: %@", exchangeDir);
    
    // First check if there are .txt files directly in this directory
    NSArray *filesInRoot = [fm contentsOfDirectoryAtPath:exchangeDir error:&error];
    if (!filesInRoot) {
        NSLog(@"  ❌ Could not read directory %@: %@", exchangeDir, error.localizedDescription);
        return;
    }
    
    NSLog(@"  📄 Found %lu items in directory", (unsigned long)filesInRoot.count);
    
    BOOL hasSubdirectories = NO;
    NSInteger dirCount = 0;
    NSInteger fileCount = 0;
    
    // Check if this directory has subdirectories (numbered folders like 1, 2, 3)
    for (NSString *item in filesInRoot) {
        NSString *itemPath = [exchangeDir stringByAppendingPathComponent:item];
        BOOL isDir;
        if ([fm fileExistsAtPath:itemPath isDirectory:&isDir]) {
            if (isDir) {
                hasSubdirectories = YES;
                dirCount++;
            } else {
                fileCount++;
            }
        }
    }
    
    NSLog(@"  📊 Items breakdown: %ld directories, %ld files", (long)dirCount, (long)fileCount);
    
    if (hasSubdirectories) {
        NSLog(@"  ↪️  Scanning subdirectories...");
        // Scan subdirectories (numbered folders)
        for (NSString *subdir in filesInRoot) {
            NSString *subdirPath = [exchangeDir stringByAppendingPathComponent:subdir];
            
            BOOL isDir;
            if (![fm fileExistsAtPath:subdirPath isDirectory:&isDir] || !isDir) {
                continue;
            }
            
            NSLog(@"    📁 Subdirectory: %@", subdir);
            
            // Scan files in this subdirectory
            [self scanFilesInDirectory:subdirPath exchange:exchange];
        }
    } else {
        NSLog(@"  ↪️  No subdirectories, scanning files directly");
        // No subdirectories, scan files directly
        [self scanFilesInDirectory:exchangeDir exchange:exchange];
    }
    
    NSLog(@"  ✅ Exchange %@: %lu symbols total", exchange, (unsigned long)self.symbolIndex.count);
}

- (void)scanFilesInDirectory:(NSString *)directory exchange:(NSString *)exchange {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSError *error;
    
    NSArray *files = [fm contentsOfDirectoryAtPath:directory error:&error];
    if (!files) {
        NSLog(@"      ❌ Could not read directory %@: %@", directory, error.localizedDescription);
        return;
    }
    
    NSLog(@"      📄 Found %lu items to check", (unsigned long)files.count);
    
    NSInteger txtCount = 0;
    NSInteger csvCount = 0;
    NSInteger otherCount = 0;
    NSInteger symbolsAdded = 0;
    
    for (NSString *filename in files) {
        // Stooq files can be .txt or .csv
        BOOL isTxt = [filename hasSuffix:@".txt"];
        BOOL isCsv = [filename hasSuffix:@".csv"];
        
        if (isTxt) txtCount++;
        else if (isCsv) csvCount++;
        else otherCount++;
        
        if (!isTxt && !isCsv) {
            continue;
        }
        
        // Extract symbol from filename (e.g., "aapl.us.txt" → "AAPL.US")
        NSString *symbol = [[filename stringByDeletingPathExtension] uppercaseString];
        NSString *filePath = [directory stringByAppendingPathComponent:filename];
        
        [self.symbolIndex addObject:symbol];
        self.symbolToFilePath[symbol] = filePath;
        symbolsAdded++;
    }
    
    NSLog(@"      📊 Files: %ld .txt, %ld .csv, %ld other", (long)txtCount, (long)csvCount, (long)otherCount);
    NSLog(@"      ✅ Added %ld symbols", (long)symbolsAdded);
}

- (NSArray<NSString *> *)availableSymbols {
    return [self.symbolIndex copy];
}

- (NSInteger)symbolCount {
    return self.symbolIndex.count;
}

#pragma mark - Data Loading

- (void)loadDataForSymbols:(NSArray<NSString *> *)symbols
                   minBars:(NSInteger)minBars
                completion:(void (^)(NSDictionary<NSString *, NSArray<HistoricalBarModel *> *> *, NSError *))completion {
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSLog(@"📥 Loading data for %lu symbols (minBars: %ld)", (unsigned long)symbols.count, (long)minBars);
        
        NSMutableDictionary *cache = [NSMutableDictionary dictionary];
        NSInteger loadedCount = 0;
        NSInteger skippedCount = 0;
        
        for (NSString *symbol in symbols) {
            @autoreleasepool {
                NSArray<HistoricalBarModel *> *bars = [self loadBarsForSymbol:symbol minBars:minBars];
                
                if (bars && bars.count >= minBars) {
                    cache[symbol] = bars;
                    loadedCount++;
                } else {
                    skippedCount++;
                }
            }
        }
        
        NSLog(@"✅ Data loading complete: %ld loaded, %ld skipped (insufficient data)",
              (long)loadedCount, (long)skippedCount);
        
        dispatch_async(dispatch_get_main_queue(), ^{
            completion([cache copy], nil);
        });
    });
}

- (nullable NSArray<HistoricalBarModel *> *)loadBarsForSymbol:(NSString *)symbol
                                                       minBars:(NSInteger)minBars {
    NSString *filePath = [self filePathForSymbol:symbol];
    if (!filePath) {
        return nil;
    }
    
    return [self parseCSVFile:filePath symbol:symbol maxBars:minBars];
}

#pragma mark - CSV Parsing

- (nullable NSArray<HistoricalBarModel *> *)parseCSVFile:(NSString *)filePath
                                                  symbol:(NSString *)symbol
                                                 maxBars:(NSInteger)maxBars {
    
    NSError *error;
    NSString *csvContent = [NSString stringWithContentsOfFile:filePath
                                                      encoding:NSUTF8StringEncoding
                                                         error:&error];
    if (!csvContent) {
        NSLog(@"⚠️ Could not read file %@: %@", filePath, error.localizedDescription);
        return nil;
    }
    
    NSArray<NSString *> *lines = [csvContent componentsSeparatedByString:@"\n"];
    
    // Parse lines in reverse order (most recent first) and collect up to maxBars
    NSMutableArray<HistoricalBarModel *> *bars = [NSMutableArray array];
    
    // Start from end and work backwards
    NSInteger startIdx = (maxBars > 0 && maxBars < lines.count) ? (lines.count - maxBars) : 0;
    
    for (NSInteger i = startIdx; i < lines.count; i++) {
        NSString *line = [lines[i] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        
        if (line.length == 0) continue;
        if ([line hasPrefix:@"<TICKER>"]) continue;  // Skip header
        
        NSArray *components = [line componentsSeparatedByString:@","];
        if (components.count < 9) continue;
        
        @try {
            // Format: <TICKER>,<PER>,<DATE>,<TIME>,<OPEN>,<HIGH>,<LOW>,<CLOSE>,<VOL>,<OPENINT>
            // Example: AAPL.US,D,20161220,000000,10,10.15,8.3954,10,9648,0
            
            NSString *dateStr = components[2];      // YYYYMMDD
            double open = [components[4] doubleValue];
            double high = [components[5] doubleValue];
            double low = [components[6] doubleValue];
            double close = [components[7] doubleValue];
            long long volume = [components[8] longLongValue];
            
            // Parse date (YYYYMMDD format)
            if (dateStr.length != 8) continue;
            
            NSString *year = [dateStr substringWithRange:NSMakeRange(0, 4)];
            NSString *month = [dateStr substringWithRange:NSMakeRange(4, 2)];
            NSString *day = [dateStr substringWithRange:NSMakeRange(6, 2)];
            
            NSDateComponents *dateComponents = [[NSDateComponents alloc] init];
            dateComponents.year = [year integerValue];
            dateComponents.month = [month integerValue];
            dateComponents.day = [day integerValue];
            
            NSCalendar *calendar = [NSCalendar currentCalendar];
            NSDate *date = [calendar dateFromComponents:dateComponents];
            
            if (!date) continue;
            
            // Validate OHLC
            if (high < low || high < open || high < close || low > open || low > close) {
                continue;  // Invalid bar
            }
            
            // Create bar
            HistoricalBarModel *bar = [[HistoricalBarModel alloc] init];
            bar.symbol = symbol;
            bar.date = date;
            bar.open = open;
            bar.high = high;
            bar.low = low;
            bar.close = close;
            bar.adjustedClose = close;
            bar.volume = volume;
            bar.timeframe = BarTimeframeDaily;
            bar.isPaddingBar = NO;
            
            [bars addObject:bar];
            
        } @catch (NSException *exception) {
            NSLog(@"⚠️ Parse error in %@: %@", filePath, exception.reason);
            continue;
        }
    }
    
    // Bars are already in chronological order (oldest to newest)
    return [bars copy];
}

#pragma mark - File Path Resolution

- (nullable NSString *)filePathForSymbol:(NSString *)symbol {
    return self.symbolToFilePath[symbol];
}

- (NSString *)exchangeFromSymbol:(NSString *)symbol {
    // Extract exchange suffix (e.g., "AAPL.US" → "us")
    NSArray *components = [symbol componentsSeparatedByString:@"."];
    if (components.count >= 2) {
        return [[components lastObject] lowercaseString];
    }
    return @"";
}

- (NSArray<NSString *> *)symbolsForExchange:(NSString *)exchange {
    NSString *exchangeUpper = [exchange uppercaseString];
    NSString *suffix = [NSString stringWithFormat:@".%@", exchangeUpper];
    
    NSMutableArray *filtered = [NSMutableArray array];
    for (NSString *symbol in self.symbolIndex) {
        if ([symbol hasSuffix:suffix]) {
            [filtered addObject:symbol];
        }
    }
    
    return [filtered copy];
}

@end
