//
//  ChartPatternManager.m
//  TradingApp
//
//  Manager class for Chart Patterns - High-level business logic
//

#import "ChartPatternManager.h"
#import "ChartWidget.h"
#import "ChartWidget+SaveData.h"
#import "SavedChartData.h"
#import "DataHub.h"
#import "DataHub+ChartPatterns.h"

@implementation ChartPatternManager

#pragma mark - Singleton

+ (instancetype)shared {
    static ChartPatternManager *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        NSLog(@"📋 ChartPatternManager: Initialized");
    }
    return self;
}

#pragma mark - High-level Operations

- (nullable ChartPatternModel *)createPatternFromChartWidget:(ChartWidget *)chartWidget
                                                 patternType:(NSString *)patternType
                                                       notes:(nullable NSString *)notes {
    
    if (!chartWidget || !patternType) {
        NSLog(@"❌ ChartPatternManager: Invalid parameters for pattern creation");
        return nil;
    }
    
    // Validate chart widget has data
    NSArray<HistoricalBarModel *> *chartData = [chartWidget currentChartData];
    if (!chartWidget.currentSymbol || !chartData || chartData.count == 0) {
        NSLog(@"❌ ChartPatternManager: No chart data available");
        return nil;
    }
    
    // Create SavedChartData as snapshot
    SavedChartData *savedData = [[SavedChartData alloc] initSnapshotWithChartWidget:chartWidget notes:notes];
    if (!savedData.isDataValid) {
        NSLog(@"❌ ChartPatternManager: Failed to create valid SavedChartData");
        return nil;
    }
    
    // Save to file with chartID as filename (for pattern linking)
    NSString *directory = [ChartWidget savedChartDataDirectory];
    NSError *error;
    if (![ChartWidget ensureSavedChartDataDirectoryExists:&error]) {
        NSLog(@"❌ ChartPatternManager: Failed to ensure directory exists: %@", error);
        return nil;
    }
    
    // Use chartID as filename for pattern linking
    NSString *filename = [NSString stringWithFormat:@"%@.chartdata", savedData.chartID];
    NSString *filePath = [directory stringByAppendingPathComponent:filename];
    
    if (![savedData saveToFile:filePath error:&error]) {
        NSLog(@"❌ ChartPatternManager: Failed to save SavedChartData: %@", error);
        return nil;
    }
    
    // Create pattern in DataHub
    DataHub *dataHub = [DataHub shared];
    ChartPatternModel *pattern = [dataHub createPatternWithType:patternType
                                             savedDataReference:savedData.chartID
                                                          notes:notes];
    
    if (pattern) {
        NSLog(@"✅ ChartPatternManager: Created pattern '%@' for %@ with %ld bars",
              patternType, chartWidget.currentSymbol, (long)savedData.barCount);
    }
    
    return pattern;
}

- (BOOL)loadPatternIntoChartWidget:(ChartPatternModel *)pattern
                       chartWidget:(ChartWidget *)chartWidget {
    
    if (!pattern || !chartWidget) {
        NSLog(@"❌ ChartPatternManager: Invalid parameters for pattern loading");
        return NO;
    }
    
    // Load SavedChartData
    SavedChartData *savedData = [self loadSavedDataForPattern:pattern];
    if (!savedData) {
        NSLog(@"❌ ChartPatternManager: Failed to load SavedChartData for pattern %@", pattern.patternID);
        return NO;
    }
    
    // Load into chart widget using existing method
    NSString *directory = [ChartWidget savedChartDataDirectory];
    NSString *filename = [NSString stringWithFormat:@"%@.chartdata", pattern.savedDataReference];
    NSString *filePath = [directory stringByAppendingPathComponent:filename];
    
    __block BOOL success = NO;
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    
    [chartWidget loadSavedDataFromFile:filePath completion:^(BOOL loadSuccess, NSError *error) {
        success = loadSuccess;
        if (!success) {
            NSLog(@"❌ ChartPatternManager: Failed to load pattern into chart: %@", error);
        }
        dispatch_semaphore_signal(semaphore);
    }];
    
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
    
    if (success) {
        NSLog(@"✅ ChartPatternManager: Loaded pattern '%@' into chart", pattern.patternType);
    }
    
    return success;
}

#pragma mark - File Operations

- (nullable SavedChartData *)loadSavedDataForPattern:(ChartPatternModel *)pattern {
    if (!pattern || !pattern.savedDataReference) {
        return nil;
    }
    
    return [pattern loadConnectedSavedData];
}

- (NSString *)getPatternDisplayInfo:(ChartPatternModel *)pattern {
    if (!pattern) {
        return @"Invalid Pattern";
    }
    
    return pattern.displayInfo;
}

- (BOOL)validatePattern:(ChartPatternModel *)pattern {
    if (!pattern) {
        return NO;
    }
    
    return pattern.hasValidSavedData;
}

#pragma mark - Cleanup Operations

- (NSArray<ChartPatternModel *> *)findOrphanedPatterns {
    DataHub *dataHub = [DataHub shared];
    return [dataHub findOrphanedPatterns];
}

- (NSArray<NSString *> *)findOrphanedSavedData {
    DataHub *dataHub = [DataHub shared];
    return [dataHub findOrphanedSavedData];
}

- (void)cleanupOrphanedPatternsWithCompletion:(void(^)(NSInteger deletedCount, NSError * _Nullable error))completion {
    DataHub *dataHub = [DataHub shared];
    NSArray<ChartPatternModel *> *orphanedPatterns = [dataHub findOrphanedPatterns];
    
    [dataHub cleanupOrphanedPatterns:orphanedPatterns completion:completion];
}

#pragma mark - Pattern Types

- (NSArray<NSString *> *)getAllKnownPatternTypes {
    DataHub *dataHub = [DataHub shared];
    return [dataHub getAllKnownPatternTypes];
}

- (void)addPatternType:(NSString *)patternType {
    DataHub *dataHub = [DataHub shared];
    [dataHub addPatternType:patternType];
}

- (BOOL)isValidPatternType:(NSString *)patternType {
    DataHub *dataHub = [DataHub shared];
    return [dataHub isValidPatternType:patternType];
}

#pragma mark - Statistics and Info

- (NSDictionary<NSString *, NSNumber *> *)getPatternStatistics {
    DataHub *dataHub = [DataHub shared];
    return [dataHub getPatternStatistics];
}

- (NSInteger)getTotalPatternCount {
    DataHub *dataHub = [DataHub shared];
    return [dataHub getTotalPatternCount];
}

- (NSArray<ChartPatternModel *> *)getPatternsForSymbol:(NSString *)symbol {
    DataHub *dataHub = [DataHub shared];
    return [dataHub getPatternsForSymbol:symbol];
}

- (NSArray<ChartPatternModel *> *)getAllPatterns {
    DataHub *dataHub = [DataHub shared];
    return [dataHub getAllPatterns];
}

#pragma mark - Interactive Creation

- (void)showPatternCreationDialogForChartWidget:(ChartWidget *)chartWidget
                                     completion:(void(^)(ChartPatternModel * _Nullable pattern, BOOL cancelled))completion {
    
    if (!chartWidget) {
        if (completion) completion(nil, YES);
        return;
    }
    
    // Validate chart has data
    NSArray<HistoricalBarModel *> *chartData = [chartWidget currentChartData];
    if (!chartWidget.currentSymbol || !chartData || chartData.count == 0) {
        NSAlert *alert = [[NSAlert alloc] init];
        alert.messageText = @"Cannot Create Pattern";
        alert.informativeText = @"No chart data is currently loaded.";
        [alert addButtonWithTitle:@"OK"];
        [alert runModal];
        
        if (completion) completion(nil, YES);
        return;
    }
    
    // Show pattern creation dialog
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"Create Chart Pattern";
    alert.informativeText = [NSString stringWithFormat:
        @"Create pattern label for %@ (%@)\nVisible range: %ld bars",
        chartWidget.currentSymbol,
        [chartWidget timeframeDisplayStringForTimeframe:chartWidget.currentTimeframe],
        (long)chartData.count];
    [alert addButtonWithTitle:@"Create"];
    [alert addButtonWithTitle:@"Cancel"];
    
    // Create main container with FIXED FRAME
    NSView *containerView = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 400, 120)];
    
    // Pattern type label
    NSTextField *patternLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(10, 90, 380, 20)];
    patternLabel.stringValue = @"Pattern Type:";
    patternLabel.editable = NO;
    patternLabel.bordered = NO;
    patternLabel.backgroundColor = [NSColor clearColor];
    patternLabel.font = [NSFont boldSystemFontOfSize:13];
    [containerView addSubview:patternLabel];
    
    // Pattern type combo box
    NSComboBox *patternTypeCombo = [[NSComboBox alloc] initWithFrame:NSMakeRect(10, 60, 380, 25)];
    patternTypeCombo.placeholderString = @"Enter or select pattern type...";
    patternTypeCombo.font = [NSFont systemFontOfSize:13];
    
    NSArray<NSString *> *knownTypes = [self getAllKnownPatternTypes];
    [patternTypeCombo addItemsWithObjectValues:knownTypes];
    patternTypeCombo.completes = YES;
    [containerView addSubview:patternTypeCombo];
    
    // Notes label
    NSTextField *notesLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(10, 35, 380, 20)];
    notesLabel.stringValue = @"Notes (optional):";
    notesLabel.editable = NO;
    notesLabel.bordered = NO;
    notesLabel.backgroundColor = [NSColor clearColor];
    notesLabel.font = [NSFont boldSystemFontOfSize:13];
    [containerView addSubview:notesLabel];
    
    // Notes field
    NSTextField *notesField = [[NSTextField alloc] initWithFrame:NSMakeRect(10, 5, 380, 25)];
    notesField.placeholderString = @"Optional notes...";
    notesField.font = [NSFont systemFontOfSize:13];
    [containerView addSubview:notesField];
    
    alert.accessoryView = containerView;
    
    NSModalResponse response = [alert runModal];
    
    if (response == NSAlertFirstButtonReturn) {
        NSString *patternType = patternTypeCombo.stringValue.length > 0 ? patternTypeCombo.stringValue : nil;
        NSString *notes = notesField.stringValue.length > 0 ? notesField.stringValue : nil;
        
        if (!patternType || ![self isValidPatternType:patternType]) {
            NSAlert *errorAlert = [[NSAlert alloc] init];
            errorAlert.messageText = @"Invalid Pattern Type";
            errorAlert.informativeText = @"Please enter a valid pattern type.";
            [errorAlert addButtonWithTitle:@"OK"];
            [errorAlert runModal];
            
            if (completion) completion(nil, YES);
            return;
        }
        
        // Create pattern
        ChartPatternModel *pattern = [self createPatternFromChartWidget:chartWidget
                                                            patternType:patternType
                                                                  notes:notes];
        
        if (pattern) {
            NSAlert *successAlert = [[NSAlert alloc] init];
            successAlert.messageText = @"Pattern Created";
            successAlert.informativeText = [NSString stringWithFormat:@"Pattern '%@' created successfully.", patternType];
            [successAlert addButtonWithTitle:@"OK"];
            [successAlert runModal];
        }
        
        if (completion) completion(pattern, NO);
    } else {
        if (completion) completion(nil, YES);
    }
}

@end
