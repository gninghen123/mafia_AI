//
//  SavedChartData.m
//  TradingApp
//
//  Implementation for saving chart data to binary plist
//

#import "SavedChartData.h"
#import "ChartWidget.h"
#import <compression.h>
#import "ChartWidget+SaveData.h"
#import "SavedChartData+FilenameParsing.h"
#import "SavedChartData+FilenameUpdate.h"


// Forward declaration to access private properties
@interface ChartWidget (SaveDataPrivate)
- (NSArray<HistoricalBarModel *> *)chartData;

@end

@interface SavedChartData ()
@property (nonatomic, assign) BOOL isCompressed;
@end

@implementation SavedChartData

#pragma mark - Initialization

- (instancetype)initSnapshotWithChartWidget:(ChartWidget *)chartWidget notes:(NSString *)notes {
    self = [super init];
    if (self) {
        // Generate unique ID
        _chartID = [[NSUUID UUID] UUIDString];
        
        // Basic properties
        _symbol = chartWidget.currentSymbol;
        _timeframe = chartWidget.currentTimeframe;
        _dataType = SavedChartDataTypeSnapshot;
        _creationDate = [NSDate date];
        _notes = notes;
        _includesExtendedHours = (chartWidget.tradingHoursMode == ChartTradingHoursWithAfterHours);
        
        // Get chart data using private property access
        NSArray<HistoricalBarModel *> *chartData = [chartWidget chartData];
        
        // Extract visible range from chart widget
        NSInteger startIndex = chartWidget.visibleStartIndex;
        NSInteger endIndex = chartWidget.visibleEndIndex;
        
        if (chartData && startIndex >= 0 && endIndex < chartData.count && startIndex <= endIndex) {
            // Extract the visible bars
            NSRange visibleRange = NSMakeRange(startIndex, endIndex - startIndex + 1);
            _historicalBars = [chartData subarrayWithRange:visibleRange];
            
            // Set date range based on actual data
            if (_historicalBars.count > 0) {
                _startDate = _historicalBars.firstObject.date;
                _endDate = _historicalBars.lastObject.date;
            }
        }
        
        NSLog(@"📦 SavedChartData SNAPSHOT created: %@ [%@] %ld bars from %@ to %@ (extended: %@)",
              _symbol, [self timeframeDescription], (long)self.barCount, _startDate, _endDate,
              _includesExtendedHours ? @"YES" : @"NO");
    }
    return self;
}

- (instancetype)initContinuousWithChartWidget:(ChartWidget *)chartWidget notes:(NSString *)notes {
    self = [super init];
    if (self) {
        // Generate unique ID
        _chartID = [[NSUUID UUID] UUIDString];
        
        // Basic properties
        _symbol = chartWidget.currentSymbol;
        _timeframe = chartWidget.currentTimeframe;
        _dataType = SavedChartDataTypeContinuous;
        _creationDate = [NSDate date];
        _lastUpdateDate = [NSDate date];
        _lastSuccessfulUpdate = [NSDate date];
        _notes = notes;
        _includesExtendedHours = (chartWidget.tradingHoursMode == ChartTradingHoursWithAfterHours);
        
        // Get chart data using private property access
        NSArray<HistoricalBarModel *> *chartData = [chartWidget chartData];
        
        // For continuous: take ALL available data, not just visible range
        if (chartData && chartData.count > 0) {
            _historicalBars = [chartData copy];
            _startDate = _historicalBars.firstObject.date;
            _endDate = _historicalBars.lastObject.date;
        }
        
        // Calculate next scheduled update
        _nextScheduledUpdate = [self calculateNextScheduledUpdate];
        
        NSLog(@"📦 SavedChartData CONTINUOUS created: %@ [%@] %ld bars from %@ to %@ (extended: %@)",
              _symbol, [self timeframeDescription], (long)self.barCount, _startDate, _endDate,
              _includesExtendedHours ? @"YES" : @"NO");
        NSLog(@"⏰ Next scheduled update: %@", _nextScheduledUpdate);
    }
    return self;
}

- (instancetype)initWithDictionary:(NSDictionary *)dictionary {
    self = [super init];
    if (self) {
        _chartID = dictionary[@"chartID"] ?: [[NSUUID UUID] UUIDString];
        _symbol = dictionary[@"symbol"];
        _timeframe = [dictionary[@"timeframe"] integerValue];
        _dataType = [dictionary[@"dataType"] integerValue];
        _startDate = dictionary[@"startDate"];
        _endDate = dictionary[@"endDate"];
        _creationDate = dictionary[@"creationDate"] ?: [NSDate date];
        _lastUpdateDate = dictionary[@"lastUpdateDate"];
        _lastSuccessfulUpdate = dictionary[@"lastSuccessfulUpdate"];
        _nextScheduledUpdate = dictionary[@"nextScheduledUpdate"];
        _includesExtendedHours = [dictionary[@"includesExtendedHours"] boolValue];
        _hasGaps = [dictionary[@"hasGaps"] boolValue];
        _notes = dictionary[@"notes"];
        
        // Deserialize historical bars
        NSArray *barsData = dictionary[@"historicalBars"];
        if (barsData) {
            NSMutableArray<HistoricalBarModel *> *bars = [NSMutableArray array];
            for (NSDictionary *barDict in barsData) {
                HistoricalBarModel *bar = [[HistoricalBarModel alloc] init];
                bar.symbol = self.symbol;
                bar.date = barDict[@"date"];
                bar.open = [barDict[@"open"] doubleValue];
                bar.high = [barDict[@"high"] doubleValue];
                bar.low = [barDict[@"low"] doubleValue];
                bar.close = [barDict[@"close"] doubleValue];
                bar.volume = [barDict[@"volume"] longLongValue];
                bar.timeframe = (BarTimeframe)[barDict[@"timeframe"] integerValue];
                [bars addObject:bar];
            }
            _historicalBars = [bars copy];
        }
    }
    return self;
}

#pragma mark - Data Management

- (BOOL)mergeWithNewBars:(NSArray<HistoricalBarModel *> *)newBars overlapBarCount:(NSInteger)overlapBarCount {
    if (!newBars || newBars.count == 0) {
        NSLog(@"❌ Merge failed: No new bars provided");
        return NO;
    }
    
    /* validazione non serve perche timeframe delel barre e' un dato mock
     if (![self isCompatibleWithBars:newBars]) {
     NSLog(@"❌ Merge failed: Incompatible bar data");
     return NO;
     }*/
    
    if (self.dataType != SavedChartDataTypeContinuous) {
        NSLog(@"❌ Merge failed: Can only merge with continuous storage");
        return NO;
    }
    
    // Find overlap point
    NSDate *lastExistingDate = self.endDate;
    NSInteger overlapIndex = -1;
    
    for (NSInteger i = 0; i < newBars.count; i++) {
        if ([newBars[i].date isEqualToDate:lastExistingDate]) {
            overlapIndex = i;
            break;
        }
    }
    
    if (overlapIndex == -1) {
        NSLog(@"❌ Merge failed: No overlap found between existing data and new bars");
        return NO;
    }
    
    // Extract new bars (everything after overlap)
    if (overlapIndex + 1 < newBars.count) {
        NSRange newBarsRange = NSMakeRange(overlapIndex + 1, newBars.count - overlapIndex - 1);
        NSArray<HistoricalBarModel *> *barsToAdd = [newBars subarrayWithRange:newBarsRange];
        
        // Merge with existing data
        NSMutableArray<HistoricalBarModel *> *mergedBars = [self.historicalBars mutableCopy];
        [mergedBars addObjectsFromArray:barsToAdd];
        
        // Update properties
        _historicalBars = [mergedBars copy];
        _endDate = _historicalBars.lastObject.date;
        _lastUpdateDate = [NSDate date];
        _lastSuccessfulUpdate = [NSDate date];
        _nextScheduledUpdate = [self calculateNextScheduledUpdate];
        
        NSLog(@"✅ Merged %ld new bars. Total bars: %ld. New end date: %@",
              (long)barsToAdd.count, (long)self.barCount, _endDate);
        return YES;
    } else {
        NSLog(@"ℹ️ No new bars to add (all bars already exist)");
        // Still update timestamps to reflect successful check
        _lastUpdateDate = [NSDate date];
        _lastSuccessfulUpdate = [NSDate date];
        _nextScheduledUpdate = [self calculateNextScheduledUpdate];
        return YES;
    }
}

- (BOOL)canMergeWithSnapshot:(SavedChartData *)otherSnapshot {
    if (!otherSnapshot) return NO;
    
    // Check basic compatibility (symbol, timeframe, extended hours)
    if (![self matchesSymbol:otherSnapshot.symbol
                   timeframe:otherSnapshot.timeframe
       includesExtendedHours:otherSnapshot.includesExtendedHours]) {
        return NO;
    }
    
    // Both must be snapshots
    if (self.dataType != SavedChartDataTypeSnapshot ||
        otherSnapshot.dataType != SavedChartDataTypeSnapshot) {
        return NO;
    }
    
    // Check if ranges overlap or are contiguous
    // Case 1: Complete overlap (one range contains the other)
    if ([self.startDate compare:otherSnapshot.endDate] != NSOrderedDescending &&
        [self.endDate compare:otherSnapshot.startDate] != NSOrderedAscending) {
        return YES; // Ranges overlap
    }
    
    // Case 2: Adjacent ranges (with small tolerance for gaps)
    // Allow up to 1 day gap for intraday, 7 days for daily+
    NSTimeInterval maxGap = (self.timeframe <= BarTimeframe4Hour) ? 86400 : 604800; // 1 day or 7 days
    
    // Check if otherSnapshot comes right after self
    NSTimeInterval gapAfter = [otherSnapshot.startDate timeIntervalSinceDate:self.endDate];
    if (gapAfter >= 0 && gapAfter <= maxGap) {
        return YES;
    }
    
    // Check if otherSnapshot comes right before self
    NSTimeInterval gapBefore = [self.startDate timeIntervalSinceDate:otherSnapshot.endDate];
    if (gapBefore >= 0 && gapBefore <= maxGap) {
        return YES;
    }
    
    return NO;
}

- (BOOL)mergeWithSnapshot:(SavedChartData *)otherSnapshot error:(NSError **)error {
    if (![self canMergeWithSnapshot:otherSnapshot]) {
        if (error) {
            *error = [NSError errorWithDomain:@"SavedChartDataMerge"
                                         code:2001
                                     userInfo:@{NSLocalizedDescriptionKey: @"Snapshots are not compatible for merging"}];
        }
        NSLog(@"❌ Snapshot merge failed: Incompatible snapshots");
        return NO;
    }
    
    // Combine bars from both snapshots
    NSMutableArray<HistoricalBarModel *> *allBars = [NSMutableArray array];
    [allBars addObjectsFromArray:self.historicalBars];
    [allBars addObjectsFromArray:otherSnapshot.historicalBars];
    
    // Sort by date
    [allBars sortUsingComparator:^NSComparisonResult(HistoricalBarModel *bar1, HistoricalBarModel *bar2) {
        return [bar1.date compare:bar2.date];
    }];
    
    // Remove duplicates (keep first occurrence)
    NSMutableArray<HistoricalBarModel *> *uniqueBars = [NSMutableArray array];
    NSDate *lastDate = nil;
    
    for (HistoricalBarModel *bar in allBars) {
        if (!lastDate || ![bar.date isEqualToDate:lastDate]) {
            [uniqueBars addObject:bar];
            lastDate = bar.date;
        }
    }
    
    if (uniqueBars.count == 0) {
        if (error) {
            *error = [NSError errorWithDomain:@"SavedChartDataMerge"
                                         code:2002
                                     userInfo:@{NSLocalizedDescriptionKey: @"No bars after merge"}];
        }
        NSLog(@"❌ Snapshot merge failed: No bars after deduplication");
        return NO;
    }
    
    // Update properties with merged data
    _historicalBars = [uniqueBars copy];
    _startDate = uniqueBars.firstObject.date;
    _endDate = uniqueBars.lastObject.date;
    _lastUpdateDate = [NSDate date];
    
    // Merge notes if both have them
    if (otherSnapshot.notes && otherSnapshot.notes.length > 0) {
        if (self.notes && self.notes.length > 0) {
            _notes = [NSString stringWithFormat:@"%@\n[MERGED] %@", self.notes, otherSnapshot.notes];
        } else {
            _notes = [NSString stringWithFormat:@"[MERGED] %@", otherSnapshot.notes];
        }
    }
    
    NSLog(@"✅ Snapshot merge successful: %ld total bars (range: %@ to %@)",
          (long)self.barCount, self.startDate, self.endDate);
    
    return YES;
}

- (BOOL)matchesSymbol:(NSString *)symbol
            timeframe:(BarTimeframe)timeframe
includesExtendedHours:(BOOL)includesExtendedHours {
    
    return ([self.symbol.uppercaseString isEqualToString:symbol.uppercaseString] &&
            self.timeframe == timeframe &&
            self.includesExtendedHours == includesExtendedHours);
}

- (void)convertToSnapshot {
    if (self.dataType == SavedChartDataTypeSnapshot) {
        NSLog(@"⚠️ Already a snapshot, no conversion needed");
        return;
    }
    
    _dataType = SavedChartDataTypeSnapshot;
    _lastUpdateDate = [NSDate date];
    _nextScheduledUpdate = nil;
    
    NSLog(@"📸 Converted continuous storage to snapshot: %@ [%@] %ld bars",
          self.symbol, [self timeframeDescription], (long)self.barCount);
}

#pragma mark - Serialization

- (NSDictionary *)toDictionary {
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    
    dict[@"chartID"] = self.chartID;
    dict[@"symbol"] = self.symbol;
    dict[@"timeframe"] = @(self.timeframe);
    dict[@"dataType"] = @(self.dataType);
    dict[@"startDate"] = self.startDate;
    dict[@"endDate"] = self.endDate;
    dict[@"creationDate"] = self.creationDate;
    dict[@"includesExtendedHours"] = @(self.includesExtendedHours);
    dict[@"hasGaps"] = @(self.hasGaps);
    
    if (self.lastUpdateDate) dict[@"lastUpdateDate"] = self.lastUpdateDate;
    if (self.lastSuccessfulUpdate) dict[@"lastSuccessfulUpdate"] = self.lastSuccessfulUpdate;
    if (self.nextScheduledUpdate) dict[@"nextScheduledUpdate"] = self.nextScheduledUpdate;
    if (self.notes) dict[@"notes"] = self.notes;
    
    // Serialize historical bars
    if (self.historicalBars) {
        NSMutableArray *barsArray = [NSMutableArray array];
        for (HistoricalBarModel *bar in self.historicalBars) {
            NSDictionary *barDict = @{
                @"date": bar.date,
                @"open": @(bar.open),
                @"high": @(bar.high),
                @"low": @(bar.low),
                @"close": @(bar.close),
                @"volume": @(bar.volume),
                @"timeframe": @(bar.timeframe)
            };
            [barsArray addObject:barDict];
        }
        dict[@"historicalBars"] = barsArray;
    }
    
    // Add metadata
    dict[@"barCount"] = @(self.barCount);
    dict[@"version"] = @"2.0"; // 🎯 BUMP VERSION per indicare supporto compressione
    dict[@"compressionFormat"] = @"LZFSE"; // Metadata per tracking
    
    return [dict copy];
}


+ (instancetype)loadFromFile:(NSString *)filePath {
    NSData *fileData = [NSData dataWithContentsOfFile:filePath];
    if (!fileData) {
        NSLog(@"❌ Failed to load data from file: %@", filePath);
        return nil;
    }
    
    NSString *filename = [filePath lastPathComponent];
    NSLog(@"📂 Loading SavedChartData from: %@ (%.1f KB)", filename, fileData.length / 1024.0);
    
    // 🗜️ TRY TO DECOMPRESS (LZFSE format detection)
    NSData *plistData = [self decompressData:fileData];
    BOOL wasCompressed = (plistData != nil);
    
    if (!plistData) {
        // Fallback: try as uncompressed data (backward compatibility)
        NSLog(@"ℹ️ File not compressed, trying direct plist deserialization...");
        plistData = fileData;
    }
    
    // Deserialize plist
    NSError *error;
    NSDictionary *dictionary = [NSPropertyListSerialization propertyListWithData:plistData
                                                                         options:NSPropertyListImmutable
                                                                          format:NULL
                                                                           error:&error];
    if (!dictionary) {
        NSLog(@"❌ Failed to deserialize plist: %@", error.localizedDescription);
        return nil;
    }
    
    // ✅ STEP 1: Extract authoritative metadata from filename using existing parsing methods
    NSString *filenameSymbol = nil;
    BarTimeframe filenameTimeframe = BarTimeframeDaily;
    SavedChartDataType filenameDataType = SavedChartDataTypeSnapshot;
    BOOL filenameExtendedHours = NO;
    BOOL hasFilenameMetadata = NO;
    
    if ([self isNewFormatFilename:filename]) {
        filenameSymbol = [self symbolFromFilename:filename];
        filenameTimeframe = [self timeframeEnumFromFilename:filename];
        
        NSString *typeStr = [self typeFromFilename:filename];
        filenameDataType = [typeStr isEqualToString:@"Continuous"] ?
        SavedChartDataTypeContinuous : SavedChartDataTypeSnapshot;
        
        filenameExtendedHours = [self extendedHoursFromFilename:filename];
        hasFilenameMetadata = YES;
        
        NSLog(@"📋 Filename metadata: symbol=%@, timeframe=%ld, type=%@, extendedHours=%@",
              filenameSymbol, (long)filenameTimeframe, typeStr, filenameExtendedHours ? @"YES" : @"NO");
    }
    
    // ✅ STEP 2: Create corrected dictionary with filename metadata as priority
    NSMutableDictionary *correctedDictionary = [dictionary mutableCopy];
    BOOL hadInconsistencies = NO;
    
    if (hasFilenameMetadata) {
        
        // Correct symbol if inconsistent
        NSString *internalSymbol = dictionary[@"symbol"];
        if (filenameSymbol && ![internalSymbol isEqualToString:filenameSymbol]) {
            correctedDictionary[@"symbol"] = filenameSymbol;
            hadInconsistencies = YES;
            NSLog(@"🔧 FIXED: symbol %@ → %@ (from filename)", internalSymbol, filenameSymbol);
        }
        
        // Correct timeframe if inconsistent
        NSNumber *internalTimeframe = dictionary[@"timeframe"];
        if (internalTimeframe.integerValue != filenameTimeframe) {
            correctedDictionary[@"timeframe"] = @(filenameTimeframe);
            hadInconsistencies = YES;
            NSLog(@"🔧 FIXED: timeframe %@ → %ld (from filename)", internalTimeframe, (long)filenameTimeframe);
        }
        
        // Correct dataType if inconsistent
        NSNumber *internalDataType = dictionary[@"dataType"];
        if (internalDataType.integerValue != filenameDataType) {
            correctedDictionary[@"dataType"] = @(filenameDataType);
            hadInconsistencies = YES;
            NSLog(@"🔧 FIXED: dataType %@ → %d (from filename)", internalDataType, (int)filenameDataType);
        }
        
        // Correct extendedHours if inconsistent
        NSNumber *internalExtendedHours = dictionary[@"includesExtendedHours"];
        if (internalExtendedHours.boolValue != filenameExtendedHours) {
            correctedDictionary[@"includesExtendedHours"] = @(filenameExtendedHours);
            hadInconsistencies = YES;
            NSLog(@"🔧 FIXED: includesExtendedHours %@ → %@ (from filename)",
                  internalExtendedHours, filenameExtendedHours ? @"YES" : @"NO");
        }
        
        // ✅ STEP 3: Fix timeframe in ALL historical bars if timeframe was inconsistent
        NSArray *barsData = dictionary[@"historicalBars"];
        if (barsData && internalTimeframe.integerValue != filenameTimeframe) {
            NSMutableArray *correctedBarsData = [NSMutableArray array];
            NSInteger correctedBarCount = 0;
            
            for (NSDictionary *barDict in barsData) {
                NSMutableDictionary *correctedBarDict = [barDict mutableCopy];
                NSNumber *barTimeframe = barDict[@"timeframe"];
                
                if (barTimeframe.integerValue != filenameTimeframe) {
                    correctedBarDict[@"timeframe"] = @(filenameTimeframe);
                    correctedBarCount++;
                }
                
                [correctedBarsData addObject:[correctedBarDict copy]];
            }
            
            correctedDictionary[@"historicalBars"] = [correctedBarsData copy];
            
            if (correctedBarCount > 0) {
                NSLog(@"🔧 FIXED: timeframe in %ld historical bars", (long)correctedBarCount);
            }
        }
    }
    
    // ✅ STEP 4: Create SavedChartData with corrected metadata
    SavedChartData *savedData = [[self alloc] initWithDictionary:[correctedDictionary copy]];
    
    if (savedData) {
        savedData.isCompressed = wasCompressed;
        
        // ✅ STEP 5: Log results
        if (hadInconsistencies) {
            NSLog(@"✅ Loaded SavedChartData with CORRECTED metadata: %@ [%@] %ld bars",
                  savedData.symbol, savedData.timeframeDescription, (long)savedData.barCount);
            NSLog(@"   🔧 Fixed inconsistencies using filename as authoritative source");
        } else {
            NSLog(@"✅ Loaded SavedChartData: %@ [%@] %ld bars (no corrections needed)",
                  savedData.symbol, savedData.timeframeDescription, (long)savedData.barCount);
        }
        
        if (wasCompressed) {
            CGFloat compressionRatio = (CGFloat)fileData.length / (CGFloat)plistData.length;
            NSLog(@"   📦 Decompressed: %.1f KB → %.1f KB (%.1fx expansion)",
                  fileData.length / 1024.0,
                  plistData.length / 1024.0,
                  1.0 / compressionRatio);
        }
    }
    
    return savedData;
}


#pragma mark - Properties

- (NSInteger)barCount {
    return self.historicalBars.count;
}

- (NSInteger)rangeDurationMinutes {
    if (!self.startDate || !self.endDate) return 0;
    return (NSInteger)[self.endDate timeIntervalSinceDate:self.startDate] / 60;
}

- (NSString *)timeframeDescription {
    switch (self.timeframe) {
        case BarTimeframe1Min: return @"1min";
        case BarTimeframe5Min: return @"5min";
        case BarTimeframe15Min: return @"15min";
        case BarTimeframe30Min: return @"30min";
        case BarTimeframe1Hour: return @"1hour";
        case BarTimeframe4Hour: return @"4hour";
        case BarTimeframe12Hour: return @"12hour";
        case BarTimeframeDaily: return @"daily";
        case BarTimeframeWeekly: return @"weekly";
        case BarTimeframeMonthly: return @"monthly";
        default: return @"unknown";
    }
}

- (NSInteger)estimatedFileSize {
    // Base estimate: 80 bytes per bar + overhead
    NSInteger uncompressedSize = self.barCount * 80 + 1024;
    
    // LZFSE typically achieves 60-80% compression on financial data
    NSInteger compressedSize = uncompressedSize * 0.3; // Assume 70% compression
    
    return compressedSize;
}
#pragma mark - Helper Methods

- (NSString *)suggestedFilename {
    return [self generateCurrentFilename];
    
}

- (NSString *)formattedDateRange {
    if (!self.startDate || !self.endDate) return @"Unknown range";
    
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    
    // Choose format based on timeframe
    if (self.timeframe <= BarTimeframe1Hour) {
        // Intraday: show date and time
        formatter.dateFormat = @"MMM d, HH:mm";
    } else {
        // Daily+: show just date
        formatter.dateFormat = @"MMM d, yyyy";
    }
    
    NSString *startStr = [formatter stringFromDate:self.startDate];
    NSString *endStr = [formatter stringFromDate:self.endDate];
    
    return [NSString stringWithFormat:@"%@ - %@", startStr, endStr];
}

- (BOOL)isDataValid {
    return (self.symbol.length > 0 &&
            self.historicalBars.count > 0 &&
            self.startDate &&
            self.endDate &&
            [self.startDate compare:self.endDate] != NSOrderedDescending);
}

- (BOOL)isCompatibleWithBars:(NSArray<HistoricalBarModel *> *)newBars {
    //bar timeframe dato mock evita il check
    
    return YES;
    
    // todo le barre vengono standardizzate con timeframe mock a daily prima ora a zero... e' un check inutile
    if (!newBars || newBars.count == 0) return NO;
    
    HistoricalBarModel *firstNewBar = newBars.firstObject;
    
    // Check symbol match
    if (![firstNewBar.symbol isEqualToString:self.symbol]) {
        NSLog(@"❌ Incompatible: Symbol mismatch (%@ vs %@)", firstNewBar.symbol, self.symbol);
        return NO;
    }
    
    // Check timeframe compatibility
    BarTimeframe newBarTimeframe = firstNewBar.timeframe;
    BarTimeframe expectedTimeframe = self.timeframe;
    
    if (newBarTimeframe != expectedTimeframe) {
        NSLog(@"❌ Incompatible: Timeframe mismatch (%ld vs %ld)", (long)newBarTimeframe, (long)expectedTimeframe);
        return NO;
    }
    
    return YES;
}

- (NSInteger)daysUntilAPILimitExpiration {
    if (!self.endDate) return 0;
    
    NSInteger limitDays;
    switch (self.timeframe) {
        case BarTimeframe1Min:
            limitDays = 45; // ~1.5 months
            break;
        case BarTimeframe5Min:
        case BarTimeframe15Min:
        case BarTimeframe30Min:
        case BarTimeframe1Hour:
        case BarTimeframe4Hour:
        case BarTimeframe12Hour:
            limitDays = 255; // ~8.5 months
            break;
        default:
            return NSIntegerMax; // Daily+ has no practical limit
    }
    
    NSDate *expirationDate = [self.endDate dateByAddingTimeInterval:limitDays * 24 * 60 * 60];
    NSTimeInterval secondsUntilExpiration = [expirationDate timeIntervalSinceNow];
    
    return MAX(0, (NSInteger)(secondsUntilExpiration / (24 * 60 * 60)));
}

#pragma mark - Private Helper Methods

- (NSDate *)calculateNextScheduledUpdate {
    if (self.dataType != SavedChartDataTypeContinuous) return nil;
    
    NSInteger bufferDays;
    switch (self.timeframe) {
        case BarTimeframe1Min:
            bufferDays = 30; // Aggressive: 30 days (15 days safety buffer)
            break;
        case BarTimeframe5Min:
        case BarTimeframe15Min:
        case BarTimeframe30Min:
        case BarTimeframe1Hour:
        case BarTimeframe4Hour:
        case BarTimeframe12Hour:
            bufferDays = 241; // Conservative: 241 days (14 days safety buffer)
            break;
        default:
            return nil; // Daily+ doesn't need scheduled updates
    }
    
    return [self.lastSuccessfulUpdate dateByAddingTimeInterval:bufferDays * 24 * 60 * 60];
}


#pragma mark - Compression Helpers

- (NSData *)compressData:(NSData *)inputData error:(NSError **)error {
    if (!inputData || inputData.length == 0) {
        if (error) {
            *error = [NSError errorWithDomain:@"SavedChartData"
                                         code:1004
                                     userInfo:@{NSLocalizedDescriptionKey: @"No data to compress"}];
        }
        return nil;
    }
    
    // Calculate buffer size (Apple recommends source size + 64KB for LZFSE)
    size_t bufferSize = inputData.length + 65536;
    void *compressedBuffer = malloc(bufferSize);
    
    if (!compressedBuffer) {
        if (error) {
            *error = [NSError errorWithDomain:@"SavedChartData"
                                         code:1005
                                     userInfo:@{NSLocalizedDescriptionKey: @"Failed to allocate compression buffer"}];
        }
        return nil;
    }
    
    // Perform LZFSE compression
    size_t compressedSize = compression_encode_buffer(compressedBuffer, bufferSize,
                                                      inputData.bytes, inputData.length,
                                                      NULL, COMPRESSION_LZFSE);
    
    if (compressedSize == 0) {
        free(compressedBuffer);
        if (error) {
            *error = [NSError errorWithDomain:@"SavedChartData"
                                         code:1006
                                     userInfo:@{NSLocalizedDescriptionKey: @"LZFSE compression failed"}];
        }
        return nil;
    }
    
    // Create NSData with compressed result
    NSData *compressedData = [NSData dataWithBytes:compressedBuffer length:compressedSize];
    free(compressedBuffer);
    
    return compressedData;
}

+ (NSData *)decompressData:(NSData *)compressedData {
    if (!compressedData || compressedData.length == 0) {
        return nil;
    }
    
    // Try to detect LZFSE magic bytes
    const uint8_t *bytes = (const uint8_t *)compressedData.bytes;
    if (compressedData.length < 4) {
        return nil; // Too small to be LZFSE
    }
    
    // Check for LZFSE magic bytes
    BOOL isLZFSE = (bytes[0] == 'b' && bytes[1] == 'v' && bytes[2] == 'x' &&
                    (bytes[3] == '-' || bytes[3] == '2'));
    
    if (!isLZFSE) {
        return nil; // Not LZFSE compressed
    }
    
    // Estimate decompressed size (start with 4x compressed size)
    size_t estimatedSize = compressedData.length * 4;
    size_t maxAttempts = 3;
    
    for (size_t attempt = 0; attempt < maxAttempts; attempt++) {
        void *decompressedBuffer = malloc(estimatedSize);
        if (!decompressedBuffer) {
            return nil;
        }
        
        size_t decompressedSize = compression_decode_buffer(decompressedBuffer, estimatedSize,
                                                            compressedData.bytes, compressedData.length,
                                                            NULL, COMPRESSION_LZFSE);
        
        if (decompressedSize > 0) {
            // Success!
            NSData *decompressedData = [NSData dataWithBytes:decompressedBuffer length:decompressedSize];
            free(decompressedBuffer);
            return decompressedData;
        }
        
        free(decompressedBuffer);
        
        // If decompression failed, try with larger buffer
        estimatedSize *= 2;
        
        if (estimatedSize > 100 * 1024 * 1024) { // Cap at 100MB
            break;
        }
    }
    
    NSLog(@"❌ LZFSE decompression failed after %zu attempts", maxAttempts);
    return nil;
}


- (BOOL)saveToFile:(NSString *)filePath error:(NSError **)error {
    NSDictionary *dictionary = [self toDictionary];
    
    // Serialize to binary plist
    NSData *plistData = [NSPropertyListSerialization dataWithPropertyList:dictionary
                                                                   format:NSPropertyListBinaryFormat_v1_0
                                                                  options:0
                                                                    error:error];
    if (!plistData) {
        NSLog(@"❌ Failed to serialize SavedChartData to binary plist: %@", error ? (*error).localizedDescription : @"Unknown error");
        return NO;
    }
    
    // 🗜️ COMPRESS WITH LZFSE
    NSData *compressedData = [self compressData:plistData error:error];
    if (!compressedData) {
        NSLog(@"❌ Failed to compress SavedChartData: %@", error ? (*error).localizedDescription : @"Compression failed");
        return NO;
    }
    
    // Write compressed data to file
    BOOL success = [compressedData writeToFile:filePath atomically:YES];
    
    if (success) {
        CGFloat compressionRatio = (CGFloat)compressedData.length / (CGFloat)plistData.length;
        NSLog(@"✅ SavedChartData saved with LZFSE compression: %@", filePath);
        NSLog(@"   Symbol: %@, Type: %@, Bars: %ld",
              self.symbol,
              self.dataType == SavedChartDataTypeSnapshot ? @"SNAPSHOT" : @"CONTINUOUS",
              (long)self.barCount);
        NSLog(@"   📦 Size: %.1f KB → %.1f KB (%.1f%% compression, %.1fx smaller)",
              plistData.length / 1024.0,
              compressedData.length / 1024.0,
              (1.0 - compressionRatio) * 100.0,
              1.0 / compressionRatio);
    } else {
        NSLog(@"❌ Failed to write compressed SavedChartData to file: %@", filePath);
        if (error && !*error) {
            *error = [NSError errorWithDomain:@"SavedChartData"
                                         code:1003
                                     userInfo:@{NSLocalizedDescriptionKey: @"Failed to write compressed data to file"}];
        }
    }
    
    return success;
}

+ (NSString *)canonicalTimeframeString:(BarTimeframe)timeframe {
    // ✅ FORMATO UNICO E DEFINITIVO - da usare OVUNQUE
    switch (timeframe) {
        case BarTimeframe1Min: return @"1m";
        case BarTimeframe5Min: return @"5m";
        case BarTimeframe15Min: return @"15m";
        case BarTimeframe30Min: return @"30m";
        case BarTimeframe1Hour: return @"1h";
        case BarTimeframe4Hour: return @"4h";
        case BarTimeframe12Hour: return @"12h";
        case BarTimeframeDaily: return @"1d";
        case BarTimeframeWeekly: return @"1w";
        case BarTimeframeMonthly: return @"1M";
            // ✅ Aggiungi eventuali nuovi timeframe
            // case BarTimeframeQuarterly: return @"1q";
            // case BarTimeframeYearly: return @"1y";
        default: return @"1d";
    }
}

+ (BarTimeframe)timeframeFromCanonicalString:(NSString *)timeframeStr {
    // ✅ PARSING INVERSO dal formato canonico
    if ([timeframeStr isEqualToString:@"1m"]) return BarTimeframe1Min;
    if ([timeframeStr isEqualToString:@"5m"]) return BarTimeframe5Min;
    if ([timeframeStr isEqualToString:@"15m"]) return BarTimeframe15Min;
    if ([timeframeStr isEqualToString:@"30m"]) return BarTimeframe30Min;
    if ([timeframeStr isEqualToString:@"1h"]) return BarTimeframe1Hour;
    if ([timeframeStr isEqualToString:@"4h"]) return BarTimeframe4Hour;
    if ([timeframeStr isEqualToString:@"12h"]) return BarTimeframe12Hour;
    if ([timeframeStr isEqualToString:@"1d"]) return BarTimeframeDaily;
    if ([timeframeStr isEqualToString:@"1w"]) return BarTimeframeWeekly;
    if ([timeframeStr isEqualToString:@"1M"]) return BarTimeframeMonthly;
    // if ([timeframeStr isEqualToString:@"1q"]) return BarTimeframeQuarterly;
    // if ([timeframeStr isEqualToString:@"1y"]) return BarTimeframeYearly;
    
    return BarTimeframeDaily; // Default fallback
}

@end
