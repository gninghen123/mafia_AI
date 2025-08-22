//
//  ChartPatternModel.m
//  TradingApp
//
//  Runtime Model per Chart Patterns - Thread-safe, UI-ready
//

#import "ChartPatternModel.h"
#import "SavedChartData.h"
#import "ChartWidget+SaveData.h"

@interface ChartPatternModel ()
@property (nonatomic, strong, nullable) SavedChartData *cachedSavedData;
@property (nonatomic, assign) BOOL hasCachedData;
@end

@implementation ChartPatternModel

#pragma mark - Initialization

- (instancetype)initWithPatternType:(NSString *)patternType
                 savedDataReference:(NSString *)savedDataReference
                      patternStartDate:(NSDate *)startDate
                        patternEndDate:(NSDate *)endDate
                              notes:(nullable NSString *)notes {
    self = [super init];
    if (self) {
        _patternID = [[NSUUID UUID] UUIDString];
        _patternType = patternType;
        _savedDataReference = savedDataReference;
        _patternStartDate = startDate;
        _patternEndDate = endDate;
        _creationDate = [NSDate date];
        _additionalNotes = notes;
        _hasCachedData = NO;
        
        NSLog(@"📋 ChartPatternModel created: %@ [%@] Pattern Range: %@ to %@",
              _patternType, _patternID, _patternStartDate, _patternEndDate);
    }
    return self;
}

- (instancetype)initWithPatternType:(NSString *)patternType
                 savedDataReference:(NSString *)savedDataReference
                              notes:(nullable NSString *)notes {
    // Load SavedChartData to get full date range
    NSString *directory = [ChartWidget savedChartDataDirectory];
    NSString *filename = [NSString stringWithFormat:@"%@.chartdata", savedDataReference];
    NSString *filePath = [directory stringByAppendingPathComponent:filename];
    SavedChartData *savedData = [SavedChartData loadFromFile:filePath];
    
    NSDate *startDate = savedData.startDate ?: [NSDate date];
    NSDate *endDate = savedData.endDate ?: [NSDate date];
    
    return [self initWithPatternType:patternType
                  savedDataReference:savedDataReference
                       patternStartDate:startDate
                         patternEndDate:endDate
                               notes:notes];
}

- (instancetype)initWithDictionary:(NSDictionary *)dictionary {
    self = [super init];
    if (self) {
        _patternID = dictionary[@"patternID"] ?: [[NSUUID UUID] UUIDString];
        _patternType = dictionary[@"patternType"];
        _savedDataReference = dictionary[@"savedDataReference"];
        _creationDate = dictionary[@"creationDate"] ?: [NSDate date];
        _additionalNotes = dictionary[@"additionalNotes"];
        
        // ✅ NEW: Load pattern date range from dictionary
        _patternStartDate = dictionary[@"patternStartDate"];
        _patternEndDate = dictionary[@"patternEndDate"];
        
        // Migration: If no pattern dates, use SavedChartData dates
        if (!_patternStartDate || !_patternEndDate) {
            NSString *directory = [ChartWidget savedChartDataDirectory];
            NSString *filename = [NSString stringWithFormat:@"%@.chartdata", _savedDataReference];
            NSString *filePath = [directory stringByAppendingPathComponent:filename];
            SavedChartData *savedData = [SavedChartData loadFromFile:filePath];
            
            _patternStartDate = _patternStartDate ?: savedData.startDate ?: [NSDate date];
            _patternEndDate = _patternEndDate ?: savedData.endDate ?: [NSDate date];
            
            NSLog(@"📋 ChartPatternModel migrated dates: %@ [%@] from SavedChartData", _patternType, _patternID);
        }
        
        _hasCachedData = NO;
        
        NSLog(@"📋 ChartPatternModel loaded from dictionary: %@ [%@] Pattern Range: %@ to %@",
              _patternType, _patternID, _patternStartDate, _patternEndDate);
    }
    return self;
}

#pragma mark - Derived Properties

- (nullable NSString *)symbol {
    SavedChartData *savedData = [self getCachedSavedData];
    return savedData.symbol;
}

// DEPRECATED properties - keep for backward compatibility
- (nullable NSDate *)startDate {
    return self.patternStartDate;
}

- (nullable NSDate *)endDate {
    return self.patternEndDate;
}

- (BarTimeframe)timeframe {
    SavedChartData *savedData = [self getCachedSavedData];
    return savedData ? savedData.timeframe : BarTimeframe1Day;
}

- (NSInteger)patternBarCount {
    NSArray *patternBars = [self getPatternBars];
    return patternBars ? patternBars.count : 0;
}

- (NSInteger)totalBarCount {
    SavedChartData *savedData = [self getCachedSavedData];
    return savedData ? savedData.barCount : 0;
}

- (NSString *)displayInfo {
    SavedChartData *savedData = [self getCachedSavedData];
    if (!savedData) {
        return [NSString stringWithFormat:@"%@ (Data Missing)", self.patternType];
    }
    
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateStyle = NSDateFormatterShortStyle;
    
    return [NSString stringWithFormat:@"%@ - %@ [%@] (%ld bars) %@ to %@",
            self.patternType,
            savedData.symbol,
            savedData.timeframeDescription,
            (long)self.patternBarCount,  // ✅ Use pattern bar count instead of total
            [formatter stringFromDate:self.patternStartDate],
            [formatter stringFromDate:self.patternEndDate]];
}

- (BOOL)hasValidSavedData {
    return [self validateSavedDataReference];
}

- (BOOL)hasValidDateRange {
    return [self validatePatternDateRange];
}

#pragma mark - Business Logic Methods

- (nullable SavedChartData *)loadConnectedSavedData {
    if (!self.savedDataReference) {
        NSLog(@"⚠️ ChartPatternModel: No savedDataReference for pattern %@", self.patternID);
        return nil;
    }
    
    // Build file path from savedDataReference UUID
    NSString *directory = [ChartWidget savedChartDataDirectory];
    NSString *filename = [NSString stringWithFormat:@"%@.chartdata", self.savedDataReference];
    NSString *filePath = [directory stringByAppendingPathComponent:filename];
    
    SavedChartData *savedData = [SavedChartData loadFromFile:filePath];
    if (!savedData) {
        NSLog(@"❌ ChartPatternModel: SavedChartData not found for reference %@", self.savedDataReference);
        return nil;
    }
    
    // Cache the loaded data
    self.cachedSavedData = savedData;
    self.hasCachedData = YES;
    
    NSLog(@"✅ ChartPatternModel: Loaded SavedChartData for pattern %@", self.patternID);
    return savedData;
}

- (nullable NSArray *)getPatternBars {
    SavedChartData *savedData = [self loadConnectedSavedData];
    if (!savedData || !savedData.historicalBars) {
        NSLog(@"❌ ChartPatternModel: No historical bars in SavedChartData for pattern %@", self.patternID);
        return nil;
    }
    
    NSInteger startIndex, endIndex;
    if (![self getPatternIndicesWithStartIndex:&startIndex endIndex:&endIndex]) {
        NSLog(@"❌ ChartPatternModel: Invalid pattern date range for pattern %@", self.patternID);
        return nil;
    }
    
    // Extract bars in the pattern range
    NSRange patternRange = NSMakeRange(startIndex, endIndex - startIndex + 1);
    NSArray *patternBars = [savedData.historicalBars subarrayWithRange:patternRange];
    
    NSLog(@"📊 ChartPatternModel: Extracted %ld pattern bars from range [%ld-%ld]",
          (long)patternBars.count, (long)startIndex, (long)endIndex);
    
    return patternBars;
}

- (BOOL)getPatternIndicesWithStartIndex:(NSInteger *)startIndex endIndex:(NSInteger *)endIndex {
    SavedChartData *savedData = [self loadConnectedSavedData];
    if (!savedData || !savedData.historicalBars || savedData.historicalBars.count == 0) {
        return NO;
    }
    
    if (!self.patternStartDate || !self.patternEndDate) {
        NSLog(@"❌ ChartPatternModel: Missing pattern dates for pattern %@", self.patternID);
        return NO;
    }
    
    NSArray<HistoricalBarModel *> *bars = savedData.historicalBars;
    NSInteger foundStartIndex = NSNotFound;
    NSInteger foundEndIndex = NSNotFound;
    
    // Find start index (first bar >= patternStartDate)
    for (NSInteger i = 0; i < bars.count; i++) {
        HistoricalBarModel *bar = bars[i];
        if ([bar.date compare:self.patternStartDate] != NSOrderedAscending) {
            foundStartIndex = i;
            break;
        }
    }
    
    // Find end index (last bar <= patternEndDate)
    for (NSInteger i = bars.count - 1; i >= 0; i--) {
        HistoricalBarModel *bar = bars[i];
        if ([bar.date compare:self.patternEndDate] != NSOrderedDescending) {
            foundEndIndex = i;
            break;
        }
    }
    
    if (foundStartIndex == NSNotFound || foundEndIndex == NSNotFound || foundStartIndex > foundEndIndex) {
        NSLog(@"❌ ChartPatternModel: Pattern dates outside SavedChartData range for pattern %@", self.patternID);
        NSLog(@"   Pattern range: %@ to %@", self.patternStartDate, self.patternEndDate);
        NSLog(@"   Data range: %@ to %@", bars.firstObject.date, bars.lastObject.date);
        return NO;
    }
    
    *startIndex = foundStartIndex;
    *endIndex = foundEndIndex;
    
    NSLog(@"📍 ChartPatternModel: Found pattern indices [%ld-%ld] for pattern %@",
          (long)foundStartIndex, (long)foundEndIndex, self.patternID);
    
    return YES;
}

- (void)updatePatternType:(NSString *)patternType
           patternStartDate:(NSDate *)startDate
             patternEndDate:(NSDate *)endDate
                    notes:(nullable NSString *)notes {
    _patternType = patternType;
    _patternStartDate = startDate;
    _patternEndDate = endDate;
    _additionalNotes = notes;
    
    // Clear cached data since date range changed
    _hasCachedData = NO;
    _cachedSavedData = nil;
    
    NSLog(@"📝 ChartPatternModel: Updated pattern %@ - Type: %@, Range: %@ to %@",
          self.patternID, patternType, startDate, endDate);
}

- (void)updatePatternType:(NSString *)patternType notes:(nullable NSString *)notes {
    _patternType = patternType;
    _additionalNotes = notes;
    
    NSLog(@"📝 ChartPatternModel: Updated pattern %@ type to %@", self.patternID, patternType);
}

- (BOOL)validateSavedDataReference {
    if (!self.savedDataReference) {
        return NO;
    }
    
    // Build file path and check if file exists
    NSString *directory = [ChartWidget savedChartDataDirectory];
    NSString *filename = [NSString stringWithFormat:@"%@.chartdata", self.savedDataReference];
    NSString *filePath = [directory stringByAppendingPathComponent:filename];
    
    return [[NSFileManager defaultManager] fileExistsAtPath:filePath];
}

- (BOOL)validatePatternDateRange {
    if (!self.patternStartDate || !self.patternEndDate) {
        return NO;
    }
    
    // Check that start < end
    if ([self.patternStartDate compare:self.patternEndDate] != NSOrderedAscending) {
        return NO;
    }
    
    // Check that pattern dates are within SavedChartData range
    SavedChartData *savedData = [self loadConnectedSavedData];
    if (!savedData) {
        return NO;
    }
    
    BOOL startInRange = [self.patternStartDate compare:savedData.startDate] != NSOrderedAscending &&
                       [self.patternStartDate compare:savedData.endDate] != NSOrderedDescending;
    
    BOOL endInRange = [self.patternEndDate compare:savedData.startDate] != NSOrderedAscending &&
                     [self.patternEndDate compare:savedData.endDate] != NSOrderedDescending;
    
    return startInRange && endInRange;
}

#pragma mark - Private Helpers

- (nullable SavedChartData *)getCachedSavedData {
    if (!self.hasCachedData) {
        [self loadConnectedSavedData];
    }
    return self.cachedSavedData;
}

#pragma mark - Serialization

- (NSDictionary *)toDictionary {
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    
    dict[@"patternID"] = self.patternID;
    dict[@"patternType"] = self.patternType;
    dict[@"savedDataReference"] = self.savedDataReference;
    dict[@"creationDate"] = self.creationDate;
    
    // ✅ NEW: Include pattern date range in serialization
    if (self.patternStartDate) {
        dict[@"patternStartDate"] = self.patternStartDate;
    }
    if (self.patternEndDate) {
        dict[@"patternEndDate"] = self.patternEndDate;
    }
    
    if (self.additionalNotes) {
        dict[@"additionalNotes"] = self.additionalNotes;
    }
    
    return [dict copy];
}

- (NSString *)debugDescription {
    return [NSString stringWithFormat:@"ChartPatternModel{patternID=%@, type=%@, savedDataRef=%@, symbol=%@, patternBars=%ld, totalBars=%ld, range=%@ to %@}",
            self.patternID, self.patternType, self.savedDataReference, self.symbol,
            (long)self.patternBarCount, (long)self.totalBarCount, self.patternStartDate, self.patternEndDate];
}

- (NSString *)description {
    return self.displayInfo;
}

@end
