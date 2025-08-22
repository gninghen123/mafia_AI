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
    
    // 🆕 NUOVO: Calcola le date del pattern dal range visibile
    NSDate *patternStartDate = nil;
    NSDate *patternEndDate = nil;
    
    NSInteger visibleStartIndex = chartWidget.visibleStartIndex;
    NSInteger visibleEndIndex = chartWidget.visibleEndIndex;
    
    if (visibleStartIndex >= 0 && visibleStartIndex < chartData.count &&
        visibleEndIndex >= 0 && visibleEndIndex < chartData.count &&
        visibleStartIndex <= visibleEndIndex) {
        
        patternStartDate = chartData[visibleStartIndex].date;
        patternEndDate = chartData[visibleEndIndex].date;
    } else {
        NSLog(@"❌ ChartPatternManager: Invalid visible range for pattern creation");
        return nil;
    }
    
    // 🆕 NUOVO: Cerca SavedChartData esistente compatibile
    BOOL includesExtendedHours = (chartWidget.tradingHoursMode == ChartTradingHoursWithAfterHours);
    NSString *existingDataReference = [self findExistingSavedChartDataReferenceForSymbol:chartWidget.currentSymbol
                                                                               timeframe:chartWidget.currentTimeframe
                                                                     includesExtendedHours:includesExtendedHours
                                                                        patternStartDate:patternStartDate
                                                                          patternEndDate:patternEndDate];
    
    NSString *savedDataReference = nil;
    
    if (existingDataReference) {
        // ✅ RIUSA SavedChartData esistente
        savedDataReference = existingDataReference;
        NSLog(@"♻️ ChartPatternManager: Reusing existing SavedChartData %@", savedDataReference);
        
    } else {
        // ❌ CREA nuovo SavedChartData
        SavedChartData *savedData = [[SavedChartData alloc] initSnapshotWithChartWidget:chartWidget notes:notes];
        if (!savedData.isDataValid) {
            NSLog(@"❌ ChartPatternManager: Failed to create valid SavedChartData");
            return nil;
        }
        
        // Save to file with chartID as filename
        NSString *directory = [ChartWidget savedChartDataDirectory];
        NSError *error;
        if (![ChartWidget ensureSavedChartDataDirectoryExists:&error]) {
            NSLog(@"❌ ChartPatternManager: Failed to ensure directory exists: %@", error);
            return nil;
        }
        
        NSString *filename = [NSString stringWithFormat:@"%@.chartdata", savedData.chartID];
        NSString *filePath = [directory stringByAppendingPathComponent:filename];
        
        if (![savedData saveToFile:filePath error:&error]) {
            NSLog(@"❌ ChartPatternManager: Failed to save SavedChartData: %@", error);
            return nil;
        }
        
        savedDataReference = savedData.chartID;
        NSLog(@"🆕 ChartPatternManager: Created new SavedChartData %@", savedDataReference);
    }
    
    // Create pattern in DataHub con date specifiche del pattern
    DataHub *dataHub = [DataHub shared];
    ChartPatternModel *pattern = [dataHub createPatternWithType:patternType
                                             savedDataReference:savedDataReference
                                                 patternStartDate:patternStartDate
                                                   patternEndDate:patternEndDate
                                                          notes:notes];
    
    if (pattern) {
        NSLog(@"✅ ChartPatternManager: Created pattern '%@' for %@ with range %@ to %@",
              patternType, chartWidget.currentSymbol, patternStartDate, patternEndDate);
        NSLog(@"   Using SavedChartData: %@ (%@)",
              savedDataReference, existingDataReference ? @"REUSED" : @"NEW");
    }
    
    return pattern;
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
#pragma mark - SavedChartData Optimization (NUOVO)

/// Cerca un SavedChartData esistente compatibile per il pattern
/// @param symbol Simbolo del pattern
/// @param timeframe Timeframe del pattern
/// @param includesExtendedHours Trading hours mode
/// @param patternStartDate Data di inizio del pattern
/// @param patternEndDate Data di fine del pattern
/// @return Riferimento UUID del SavedChartData esistente o nil se non trovato
- (nullable NSString *)findExistingSavedChartDataReferenceForSymbol:(NSString *)symbol
                                                         timeframe:(BarTimeframe)timeframe
                                               includesExtendedHours:(BOOL)includesExtendedHours
                                                    patternStartDate:(NSDate *)patternStartDate
                                                      patternEndDate:(NSDate *)patternEndDate {
    
    if (!symbol || !patternStartDate || !patternEndDate) {
        NSLog(@"❌ ChartPatternManager: Invalid parameters for SavedChartData search");
        return nil;
    }
    
    // Ottieni directory dei SavedChartData
    NSString *directory = [ChartWidget savedChartDataDirectory];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    NSError *error;
    NSArray<NSString *> *files = [fileManager contentsOfDirectoryAtPath:directory error:&error];
    if (!files) {
        NSLog(@"⚠️ ChartPatternManager: Cannot read SavedChartData directory: %@", error.localizedDescription);
        return nil;
    }
    
    // Filtra solo i file .chartdata
    NSArray<NSString *> *chartDataFiles = [files filteredArrayUsingPredicate:
        [NSPredicate predicateWithFormat:@"self ENDSWITH '.chartdata'"]];
    
    NSLog(@"🔍 ChartPatternManager: Searching for compatible SavedChartData among %ld files", (long)chartDataFiles.count);
    
    // Cerca match in ordine di preferenza
    for (NSString *filename in chartDataFiles) {
        NSString *filePath = [directory stringByAppendingPathComponent:filename];
        SavedChartData *candidateData = [SavedChartData loadFromFile:filePath];
        
        if (!candidateData || !candidateData.isDataValid) {
            continue; // Skip file corrotti
        }
        
        // Verifica match dei parametri base
        if (![self doesSavedChartData:candidateData
                            matchSymbol:symbol
                              timeframe:timeframe
                    includesExtendedHours:includesExtendedHours]) {
            continue;
        }
        
        // Verifica copertura date range
        SavedChartDataCoverage coverage = [self checkDateCoverage:candidateData
                                                    patternStartDate:patternStartDate
                                                      patternEndDate:patternEndDate];
        
        switch (coverage) {
            case SavedChartDataCoverageFullMatch:
                NSLog(@"✅ ChartPatternManager: PERFECT MATCH found - %@", candidateData.chartID);
                return candidateData.chartID;
                
            case SavedChartDataCoverageCanExtend:
                NSLog(@"🔄 ChartPatternManager: EXTENDABLE MATCH found - %@", candidateData.chartID);
                // Prova ad estendere il SavedChartData esistente
                if ([self extendSavedChartData:candidateData
                                toPatternStartDate:patternStartDate
                                    patternEndDate:patternEndDate]) {
                    return candidateData.chartID;
                }
                break;
                
            case SavedChartDataCoverageNoMatch:
                // Continua a cercare
                break;
        }
    }
    
    NSLog(@"❌ ChartPatternManager: No compatible SavedChartData found - will create new one");
    return nil;
}

typedef NS_ENUM(NSInteger, SavedChartDataCoverage) {
    SavedChartDataCoverageFullMatch,    // Le date del pattern sono completamente coperte
    SavedChartDataCoverageCanExtend,    // Il range può essere esteso per coprire il pattern
    SavedChartDataCoverageNoMatch       // Incompatibile
};

/// Verifica se SavedChartData copre il range di date del pattern
- (SavedChartDataCoverage)checkDateCoverage:(SavedChartData *)savedData
                           patternStartDate:(NSDate *)patternStartDate
                             patternEndDate:(NSDate *)patternEndDate {
    
    // FULL MATCH: SavedChartData contiene completamente il pattern
    if ([savedData.startDate compare:patternStartDate] != NSOrderedDescending &&
        [savedData.endDate compare:patternEndDate] != NSOrderedAscending) {
        return SavedChartDataCoverageFullMatch;
    }
    
    // CAN EXTEND: C'è overlap e possiamo estendere
    BOOL hasOverlap = ([savedData.startDate compare:patternEndDate] != NSOrderedDescending &&
                      [savedData.endDate compare:patternStartDate] != NSOrderedAscending);
    
    if (hasOverlap) {
        // Controlla se l'estensione è ragionevole (massimo 2x il range originale)
        NSTimeInterval originalRange = [savedData.endDate timeIntervalSinceDate:savedData.startDate];
        NSTimeInterval newStartGap = [savedData.startDate timeIntervalSinceDate:patternStartDate];
        NSTimeInterval newEndGap = [patternEndDate timeIntervalSinceDate:savedData.endDate];
        NSTimeInterval totalExtension = MAX(0, newStartGap) + MAX(0, newEndGap);
        
        if (totalExtension <= originalRange) { // Estensione ragionevole
            return SavedChartDataCoverageCanExtend;
        }
    }
    
    return SavedChartDataCoverageNoMatch;
}

/// Verifica match dei parametri base (symbol, timeframe, extended hours)
- (BOOL)doesSavedChartData:(SavedChartData *)savedData
               matchSymbol:(NSString *)symbol
                 timeframe:(BarTimeframe)timeframe
       includesExtendedHours:(BOOL)includesExtendedHours {
    
    return ([savedData.symbol.uppercaseString isEqualToString:symbol.uppercaseString] &&
            savedData.timeframe == timeframe &&
            savedData.includesExtendedHours == includesExtendedHours);
}

/// Estende un SavedChartData esistente per coprire le date del pattern
- (BOOL)extendSavedChartData:(SavedChartData *)savedData
           toPatternStartDate:(NSDate *)patternStartDate
               patternEndDate:(NSDate *)patternEndDate {
    
    NSLog(@"🔄 ChartPatternManager: Attempting to extend SavedChartData %@", savedData.chartID);
    NSLog(@"   Current range: %@ to %@", savedData.startDate, savedData.endDate);
    NSLog(@"   Needed range: %@ to %@", patternStartDate, patternEndDate);
    
    // TODO: IMPLEMENTAZIONE ESTENSIONE
    // Questa è una funzionalità complessa che richiede:
    // 1. Download di dati aggiuntivi dal DataHub
    // 2. Merge con dati esistenti
    // 3. Aggiornamento del file SavedChartData
    // 4. Validazione della consistenza
    
    // PER ORA: Return NO per forzare creazione di nuovo SavedChartData
    NSLog(@"⚠️ ChartPatternManager: SavedChartData extension not yet implemented - will create new");
    return NO;
}

#pragma mark - Statistics and Monitoring (NUOVO)

/// Ottieni statistiche di utilizzo SavedChartData
- (NSDictionary<NSString *, NSNumber *> *)getSavedChartDataUsageStatistics {
    NSMutableDictionary *stats = [NSMutableDictionary dictionary];
    
    // Conta SavedChartData files
    NSString *directory = [ChartWidget savedChartDataDirectory];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSArray<NSString *> *files = [fileManager contentsOfDirectoryAtPath:directory error:nil];
    NSArray<NSString *> *chartDataFiles = [files filteredArrayUsingPredicate:
        [NSPredicate predicateWithFormat:@"self ENDSWITH '.chartdata'"]];
    
    stats[@"totalSavedChartDataFiles"] = @(chartDataFiles.count);
    
    // Conta patterns totali
    DataHub *dataHub = [DataHub shared];
    NSArray<ChartPatternModel *> *allPatterns = [dataHub getAllPatterns];
    stats[@"totalPatterns"] = @(allPatterns.count);
    
    // Calcola ratio efficienza
    if (chartDataFiles.count > 0) {
        double efficiency = (double)allPatterns.count / (double)chartDataFiles.count;
        stats[@"patternsPerSavedChartData"] = @(efficiency);
    } else {
        stats[@"patternsPerSavedChartData"] = @(0);
    }
    
    // Trova SavedChartData riutilizzati (più pattern che fanno riferimento allo stesso file)
    NSMutableDictionary<NSString *, NSNumber *> *referenceCount = [NSMutableDictionary dictionary];
    for (ChartPatternModel *pattern in allPatterns) {
        NSString *ref = pattern.savedDataReference;
        referenceCount[ref] = @([referenceCount[ref] integerValue] + 1);
    }
    
    NSInteger reusedFiles = 0;
    NSInteger totalReuses = 0;
    for (NSString *ref in referenceCount) {
        NSInteger count = [referenceCount[ref] integerValue];
        if (count > 1) {
            reusedFiles++;
            totalReuses += count;
        }
    }
    
    stats[@"reusedSavedChartDataFiles"] = @(reusedFiles);
    stats[@"totalReuseInstances"] = @(totalReuses);
    
    return [stats copy];
}


@end
