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
                              notes:(nullable NSString *)notes {
    self = [super init];
    if (self) {
        _patternID = [[NSUUID UUID] UUIDString];
        _patternType = patternType;
        _savedDataReference = savedDataReference;
        _creationDate = [NSDate date];
        _additionalNotes = notes;
        _hasCachedData = NO;
        
        NSLog(@"📋 ChartPatternModel created: %@ [%@]", _patternType, _patternID);
    }
    return self;
}

- (instancetype)initWithDictionary:(NSDictionary *)dictionary {
    self = [super init];
    if (self) {
        _patternID = dictionary[@"patternID"] ?: [[NSUUID UUID] UUIDString];
        _patternType = dictionary[@"patternType"];
        _savedDataReference = dictionary[@"savedDataReference"];
        _creationDate = dictionary[@"creationDate"] ?: [NSDate date];
        _additionalNotes = dictionary[@"additionalNotes"];
        _hasCachedData = NO;
        
        NSLog(@"📋 ChartPatternModel loaded from dictionary: %@ [%@]", _patternType, _patternID);
    }
    return self;
}

#pragma mark - Derived Properties

- (nullable NSString *)symbol {
    SavedChartData *savedData = [self getCachedSavedData];
    return savedData.symbol;
}

- (nullable NSDate *)startDate {
    SavedChartData *savedData = [self getCachedSavedData];
    return savedData.startDate;
}

- (nullable NSDate *)endDate {
    SavedChartData *savedData = [self getCachedSavedData];
    return savedData.endDate;
}

- (BarTimeframe)timeframe {
    SavedChartData *savedData = [self getCachedSavedData];
    return savedData ? savedData.timeframe : BarTimeframe1Day; // Default fallback usando valore esistente
}

- (NSInteger)barCount {
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
            (long)savedData.barCount,
            [formatter stringFromDate:savedData.startDate],
            [formatter stringFromDate:savedData.endDate]];
}

- (BOOL)hasValidSavedData {
    return [self validateSavedDataReference];
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
    
    if (self.additionalNotes) {
        dict[@"additionalNotes"] = self.additionalNotes;
    }
    
    return [dict copy];
}

- (NSString *)debugDescription {
    return [NSString stringWithFormat:@"ChartPatternModel{patternID=%@, type=%@, savedDataRef=%@, symbol=%@, barCount=%ld}",
            self.patternID, self.patternType, self.savedDataReference, self.symbol, (long)self.barCount];
}

- (NSString *)description {
    return self.displayInfo;
}

@end
