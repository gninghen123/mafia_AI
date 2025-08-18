//
//  SavedChartData.m
//  TradingApp
//
//  Implementation for saving chart data to binary plist
//

#import "SavedChartData.h"
#import "ChartWidget.h"

// Forward declaration to access private properties
@interface ChartWidget (SaveDataPrivate)
- (NSArray<HistoricalBarModel *> *)chartData;
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
    
    if (![self isCompatibleWithBars:newBars]) {
        NSLog(@"❌ Merge failed: Incompatible bar data");
        return NO;
    }
    
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
    dict[@"version"] = @"1.0";
    
    return [dict copy];
}

+ (instancetype)loadFromFile:(NSString *)filePath {
    NSData *data = [NSData dataWithContentsOfFile:filePath];
    if (!data) {
        NSLog(@"❌ Failed to load data from file: %@", filePath);
        return nil;
    }
    
    NSError *error;
    NSDictionary *dictionary = [NSPropertyListSerialization propertyListWithData:data
                                                                         options:NSPropertyListImmutable
                                                                          format:NULL
                                                                           error:&error];
    if (!dictionary) {
        NSLog(@"❌ Failed to deserialize plist: %@", error.localizedDescription);
        return nil;
    }
    
    return [[self alloc] initWithDictionary:dictionary];
}

- (BOOL)saveToFile:(NSString *)filePath error:(NSError **)error {
    NSDictionary *dictionary = [self toDictionary];
    
    NSData *plistData = [NSPropertyListSerialization dataWithPropertyList:dictionary
                                                                    format:NSPropertyListBinaryFormat_v1_0
                                                                   options:0
                                                                     error:error];
    if (!plistData) {
        NSLog(@"❌ Failed to serialize SavedChartData to binary plist: %@", error ? (*error).localizedDescription : @"Unknown error");
        return NO;
    }
    
    BOOL success = [plistData writeToFile:filePath atomically:YES];
    if (success) {
        NSLog(@"✅ SavedChartData saved to: %@", filePath);
        NSLog(@"   Symbol: %@, Type: %@, Bars: %ld, Size: %.1f KB",
              self.symbol, self.dataType == SavedChartDataTypeSnapshot ? @"SNAPSHOT" : @"CONTINUOUS",
              (long)self.barCount, plistData.length / 1024.0);
    } else {
        NSLog(@"❌ Failed to write SavedChartData to file: %@", filePath);
    }
    
    return success;
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
        case ChartTimeframe1Min: return @"1min";
        case ChartTimeframe5Min: return @"5min";
        case ChartTimeframe15Min: return @"15min";
        case ChartTimeframe30Min: return @"30min";
        case ChartTimeframe1Hour: return @"1hour";
        case ChartTimeframe4Hour: return @"4hour";
        case ChartTimeframeDaily: return @"daily";
        case ChartTimeframeWeekly: return @"weekly";
        case ChartTimeframeMonthly: return @"monthly";
        default: return @"unknown";
    }
}

- (NSInteger)estimatedFileSize {
    // Rough estimate: 80 bytes per bar + overhead
    return self.barCount * 80 + 1024;
}

#pragma mark - Helper Methods

- (NSString *)suggestedFilename {
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateFormat = @"yyyyMMdd_HHmm";
    NSString *timestamp = [formatter stringFromDate:self.creationDate];
    
    NSString *typePrefix = (self.dataType == SavedChartDataTypeSnapshot) ? @"snapshot" : @"continuous";
    NSString *extendedSuffix = self.includesExtendedHours ? @"_extended" : @"";
    
    return [NSString stringWithFormat:@"%@_%@_%@_%@_%ldbars%@.chartdata",
            self.symbol, [self timeframeDescription], typePrefix, timestamp,
            (long)self.barCount, extendedSuffix];
}

- (NSString *)formattedDateRange {
    if (!self.startDate || !self.endDate) return @"Unknown range";
    
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    
    // Choose format based on timeframe
    if (self.timeframe <= ChartTimeframe1Hour) {
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
    if (!newBars || newBars.count == 0) return NO;
    
    HistoricalBarModel *firstNewBar = newBars.firstObject;
    
    // Check symbol match
    if (![firstNewBar.symbol isEqualToString:self.symbol]) {
        NSLog(@"❌ Incompatible: Symbol mismatch (%@ vs %@)", firstNewBar.symbol, self.symbol);
        return NO;
    }
    
    // Check timeframe compatibility
    BarTimeframe newBarTimeframe = firstNewBar.timeframe;
    BarTimeframe expectedTimeframe = [self chartTimeframeToBarTimeframe:self.timeframe];
    
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
        case ChartTimeframe1Min:
            limitDays = 45; // ~1.5 months
            break;
        case ChartTimeframe5Min:
        case ChartTimeframe15Min:
        case ChartTimeframe30Min:
        case ChartTimeframe1Hour:
        case ChartTimeframe4Hour:
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
        case ChartTimeframe1Min:
            bufferDays = 30; // Aggressive: 30 days (15 days safety buffer)
            break;
        case ChartTimeframe5Min:
        case ChartTimeframe15Min:
        case ChartTimeframe30Min:
        case ChartTimeframe1Hour:
        case ChartTimeframe4Hour:
            bufferDays = 241; // Conservative: 241 days (14 days safety buffer)
            break;
        default:
            return nil; // Daily+ doesn't need scheduled updates
    }
    
    return [self.lastSuccessfulUpdate dateByAddingTimeInterval:bufferDays * 24 * 60 * 60];
}

- (BarTimeframe)chartTimeframeToBarTimeframe:(ChartTimeframe)chartTimeframe {
    switch (chartTimeframe) {
        case ChartTimeframe1Min: return BarTimeframe1Min;
        case ChartTimeframe5Min: return BarTimeframe5Min;
        case ChartTimeframe15Min: return BarTimeframe15Min;
        case ChartTimeframe30Min: return BarTimeframe30Min;
        case ChartTimeframe1Hour: return BarTimeframe1Hour;
        case ChartTimeframe4Hour: return BarTimeframe4Hour;
        case ChartTimeframeDaily: return BarTimeframe1Day;
        case ChartTimeframeWeekly: return BarTimeframe1Week;
        case ChartTimeframeMonthly: return BarTimeframe1Month;
        default: return BarTimeframe1Day;
    }
}

@end
