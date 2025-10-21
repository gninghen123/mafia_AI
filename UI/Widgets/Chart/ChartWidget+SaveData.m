

//
//  ChartWidget+SaveData.m
//  TradingApp
//
//  Implementation for saving/loading chart data
//

#import "ChartWidget+SaveData.h"
#import "SavedChartData+FilenameParsing.h"
#import "SavedChartData+FilenameUpdate.h"
#import "StorageMetadataCache.h"

@implementation ChartWidget (SaveData)

#pragma mark - Save Visible Range (Snapshot)

- (void)saveVisibleRangeAsSnapshotInteractive {
    // Validate current state
    if (![self validateChartDataForSaving]) return;
    
    NSArray<HistoricalBarModel *> *chartData = [self chartData];
    if (self.visibleStartIndex < 0 || self.visibleEndIndex >= chartData.count) {
        NSAlert *alert = [[NSAlert alloc] init];
        alert.messageText = @"Cannot Save Chart Data";
        alert.informativeText = @"Invalid visible range detected.";
        [alert addButtonWithTitle:@"OK"];
        [alert runModal];
        return;
    }
    
    // Show input dialog for notes
    NSAlert *inputAlert = [[NSAlert alloc] init];
    inputAlert.messageText = @"Save Visible Range as Snapshot";
    inputAlert.informativeText = [NSString stringWithFormat:
        @"Save %ld visible bars for %@ (%@)\nRange: %@ - %@\nExtended Hours: %@\n\nOptional notes:",
        (long)(self.visibleEndIndex - self.visibleStartIndex + 1),
        self.currentSymbol,
        [self timeframeDisplayStringForTimeframe:self.currentTimeframe],
        [self formatDateForDisplay:chartData[self.visibleStartIndex].date],
        [self formatDateForDisplay:chartData[self.visibleEndIndex].date],
        (self.tradingHoursMode == ChartTradingHoursWithAfterHours) ? @"YES" : @"NO"
    ];
    
    [inputAlert addButtonWithTitle:@"Save Snapshot"];
    [inputAlert addButtonWithTitle:@"Cancel"];
    
    NSTextField *notesField = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 300, 60)];
    notesField.placeholderString = @"Enter optional notes about this snapshot...";
    notesField.maximumNumberOfLines = 3;
    inputAlert.accessoryView = notesField;
    
    NSModalResponse response = [inputAlert runModal];
    if (response == NSAlertFirstButtonReturn) {
        NSString *notes = notesField.stringValue.length > 0 ? notesField.stringValue : nil;
        
        [self saveVisibleRangeAsSnapshot:notes completion:^(BOOL success, NSString *filePath, NSError *error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self showSaveResult:success filePath:filePath error:error];
            });
        }];
    }
}

- (void)saveVisibleRangeAsSnapshot:(NSString *)notes completion:(void(^)(BOOL success, NSString * _Nullable filePath, NSError * _Nullable error))completion {
    // Ensure directory exists
    NSError *error;
    if (![ChartWidget ensureSavedChartDataDirectoryExists:&error]) {
        if (completion) completion(NO, nil, error);
        return;
    }
    
    // Create SavedChartData object as snapshot
    SavedChartData *newSnapshot = [[SavedChartData alloc] initSnapshotWithChartWidget:self notes:notes];
    if (!newSnapshot.isDataValid) {
        NSError *validationError = [NSError errorWithDomain:@"ChartWidgetSave"
                                                        code:1001
                                                    userInfo:@{NSLocalizedDescriptionKey: @"Invalid chart data for snapshot"}];
        if (completion) completion(NO, nil, validationError);
        return;
    }
    
    // ✅ NEW: Check for existing compatible snapshots
    [self checkForMergeableSnapshot:newSnapshot completion:^(SavedChartData * _Nullable existingSnapshot, NSString * _Nullable existingFilePath) {
        
        if (existingSnapshot && existingFilePath) {
            // Found compatible snapshot - ask user what to do
            [self showMergeDialog:newSnapshot
                 existingSnapshot:existingSnapshot
                 existingFilePath:existingFilePath
                         userNotes:notes
                        completion:completion];
        } else {
            // No compatible snapshot found - save as new file
            [self saveSnapshotAsNewFile:newSnapshot completion:completion];
        }
    }];
}

#pragma mark - Helper Methods for Snapshot Merge

/// Check if there's an existing snapshot that can be merged with the new one
- (void)checkForMergeableSnapshot:(SavedChartData *)newSnapshot
                       completion:(void(^)(SavedChartData * _Nullable existingSnapshot, NSString * _Nullable existingFilePath))completion {
    
    // Get all snapshot metadata for this symbol
    NSArray<StorageMetadataItem *> *allItems = [ChartWidget availableStorageMetadataForSymbol:newSnapshot.symbol];
    
    // Filter for snapshots only with matching timeframe and extended hours
    NSMutableArray<StorageMetadataItem *> *candidateSnapshots = [NSMutableArray array];
    
    for (StorageMetadataItem *item in allItems) {
        if (item.dataType == SavedChartDataTypeSnapshot &&
            item.timeframe == newSnapshot.timeframe &&
            item.includesExtendedHours == newSnapshot.includesExtendedHours) {
            [candidateSnapshots addObject:item];
        }
    }
    
    if (candidateSnapshots.count == 0) {
        NSLog(@"📸 No existing compatible snapshots found for %@ [%@]",
              newSnapshot.symbol, [newSnapshot timeframeDescription]);
        completion(nil, nil);
        return;
    }
    
    NSLog(@"🔍 Found %lu candidate snapshot(s) for potential merge", (unsigned long)candidateSnapshots.count);
    
    // Check each candidate to see if it can be merged
    for (StorageMetadataItem *item in candidateSnapshots) {
        SavedChartData *existingSnapshot = [SavedChartData loadFromFile:item.filePath];
        
        if (existingSnapshot && [newSnapshot canMergeWithSnapshot:existingSnapshot]) {
            NSLog(@"✅ Found mergeable snapshot: %@", [item.filePath lastPathComponent]);
            completion(existingSnapshot, item.filePath);
            return;
        }
    }
    
    NSLog(@"📸 No mergeable snapshots found (incompatible date ranges)");
    completion(nil, nil);
}

/// Show dialog asking user whether to merge or create new file
- (void)showMergeDialog:(SavedChartData *)newSnapshot
       existingSnapshot:(SavedChartData *)existingSnapshot
       existingFilePath:(NSString *)existingFilePath
              userNotes:(NSString *)userNotes
             completion:(void(^)(BOOL success, NSString * _Nullable filePath, NSError * _Nullable error))completion {
    
    dispatch_async(dispatch_get_main_queue(), ^{
        NSAlert *alert = [[NSAlert alloc] init];
        alert.messageText = @"Compatible Snapshot Found";
        
        NSString *infoText = [NSString stringWithFormat:
            @"Found an existing snapshot that can be merged:\n\n"
            @"EXISTING SNAPSHOT:\n"
            @"  Range: %@ to %@\n"
            @"  Bars: %ld\n"
            @"  Created: %@\n\n"
            @"NEW SNAPSHOT:\n"
            @"  Range: %@ to %@\n"
            @"  Bars: %ld\n\n"
            @"What would you like to do?",
            [self formatDateForDisplay:existingSnapshot.startDate],
            [self formatDateForDisplay:existingSnapshot.endDate],
            (long)existingSnapshot.barCount,
            [self formatDateForDisplay:existingSnapshot.creationDate],
            [self formatDateForDisplay:newSnapshot.startDate],
            [self formatDateForDisplay:newSnapshot.endDate],
            (long)newSnapshot.barCount
        ];
        
        alert.informativeText = infoText;
        
        [alert addButtonWithTitle:@"Merge Snapshots"];
        [alert addButtonWithTitle:@"Save as New File"];
        [alert addButtonWithTitle:@"Cancel"];
        
        NSModalResponse response = [alert runModal];
        
        if (response == NSAlertFirstButtonReturn) {
            // User chose to MERGE
            [self performSnapshotMerge:newSnapshot
                      existingSnapshot:existingSnapshot
                      existingFilePath:existingFilePath
                             userNotes:userNotes
                            completion:completion];
            
        } else if (response == NSAlertSecondButtonReturn) {
            // User chose to save as NEW FILE
            [self saveSnapshotAsNewFile:newSnapshot completion:completion];
            
        } else {
            // User cancelled
            NSError *cancelError = [NSError errorWithDomain:@"ChartWidgetSave"
                                                       code:1003
                                                   userInfo:@{NSLocalizedDescriptionKey: @"User cancelled save"}];
            if (completion) completion(NO, nil, cancelError);
        }
    });
}

/// Perform the actual merge and save
- (void)performSnapshotMerge:(SavedChartData *)newSnapshot
            existingSnapshot:(SavedChartData *)existingSnapshot
            existingFilePath:(NSString *)existingFilePath
                   userNotes:(NSString *)userNotes
                  completion:(void(^)(BOOL success, NSString * _Nullable filePath, NSError * _Nullable error))completion {
    
    NSLog(@"🔄 Merging snapshots...");
    
    // Add user notes to new snapshot before merge
    if (userNotes && userNotes.length > 0) {
        newSnapshot.notes = userNotes;
    }
    
    // Perform merge
    NSError *mergeError;
    BOOL mergeSuccess = [existingSnapshot mergeWithSnapshot:newSnapshot error:&mergeError];
    
    if (!mergeSuccess) {
        NSLog(@"❌ Merge failed: %@", mergeError.localizedDescription);
        if (completion) completion(NO, nil, mergeError);
        return;
    }
    
    // Save merged snapshot (with filename update to reflect new range)
    NSError *saveError;
    NSString *newFilePath = [existingSnapshot saveToFileWithFilenameUpdate:existingFilePath error:&saveError];
    
    if (newFilePath) {
        NSLog(@"✅ Merged snapshot saved successfully: %@", [newFilePath lastPathComponent]);
        
        // Update cache
        StorageMetadataCache *cache = [StorageMetadataCache sharedCache];
        
        // If filename changed, delete old file and update cache
        if (![newFilePath isEqualToString:existingFilePath]) {
            [[NSFileManager defaultManager] removeItemAtPath:existingFilePath error:nil];
            [cache handleFileDeleted:existingFilePath];
        }
        
        [cache handleFileUpdated:newFilePath];
        [cache saveToUserDefaults];
        
        if (completion) completion(YES, newFilePath, nil);
    } else {
        NSLog(@"❌ Failed to save merged snapshot: %@", saveError.localizedDescription);
        if (completion) completion(NO, nil, saveError);
    }
}

/// Save snapshot as new file (no merge)
- (void)saveSnapshotAsNewFile:(SavedChartData *)snapshot
                   completion:(void(^)(BOOL success, NSString * _Nullable filePath, NSError * _Nullable error))completion {
    
    NSString *directory = [ChartWidget savedChartDataDirectory];
    NSString *filename = [snapshot generateCurrentFilename];
    NSString *filePath = [directory stringByAppendingPathComponent:filename];
    
    NSError *saveError;
    BOOL success = [snapshot saveToFile:filePath error:&saveError];
    
    if (success) {
        NSLog(@"✅ Saved new snapshot: %@", filename);
        
        // Update cache
        StorageMetadataCache *cache = [StorageMetadataCache sharedCache];
        [cache handleFileUpdated:filePath];
        [cache saveToUserDefaults];
    }
    
    if (completion) {
        completion(success, success ? filePath : nil, saveError);
    }
}

#pragma mark - Save Full Data (Continuous)

- (void)saveFullDataAsContinuousInteractive {
    // Validate current state
    if (![self validateChartDataForSaving]) return;
    
    NSArray<HistoricalBarModel *> *chartData = [self chartData];
    
    // Show input dialog for notes
    NSAlert *inputAlert = [[NSAlert alloc] init];
    inputAlert.messageText = @"Save Full Data as Continuous Storage";
    inputAlert.informativeText = [NSString stringWithFormat:
        @"Save %ld total bars for %@ (%@)\nRange: %@ - %@\nExtended Hours: %@\n\nThis will create a continuous storage that can be automatically updated.\n\nOptional notes:",
        (long)chartData.count,
        self.currentSymbol,
        [self timeframeDisplayStringForTimeframe:self.currentTimeframe],
        [self formatDateForDisplay:chartData.firstObject.date],
        [self formatDateForDisplay:chartData.lastObject.date],
        (self.tradingHoursMode == ChartTradingHoursWithAfterHours) ? @"YES" : @"NO"
    ];
    
    [inputAlert addButtonWithTitle:@"Save Continuous"];
    [inputAlert addButtonWithTitle:@"Cancel"];
    
    NSTextField *notesField = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 300, 60)];
    notesField.placeholderString = @"Enter optional notes about this continuous storage...";
    notesField.maximumNumberOfLines = 3;
    inputAlert.accessoryView = notesField;
    
    NSModalResponse response = [inputAlert runModal];
    if (response == NSAlertFirstButtonReturn) {
        NSString *notes = notesField.stringValue.length > 0 ? notesField.stringValue : nil;
        
        [self saveFullDataAsContinuous:notes completion:^(BOOL success, NSString *filePath, NSError *error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self showSaveResult:success filePath:filePath error:error];
                
                // If successful, notify StorageManager to start tracking this continuous storage
                if (success) {
                    [[NSNotificationCenter defaultCenter] postNotificationName:@"NewContinuousStorageCreated"
                                                                        object:self
                                                                      userInfo:@{@"filePath": filePath}];
                }
            });
        }];
    }
}

- (void)saveFullDataAsContinuous:(NSString *)notes completion:(void(^)(BOOL success, NSString * _Nullable filePath, NSError * _Nullable error))completion {
    // Ensure directory exists
    NSError *error;
    if (![ChartWidget ensureSavedChartDataDirectoryExists:&error]) {
        if (completion) completion(NO, nil, error);
        return;
    }
    
    // Create SavedChartData object as continuous
    SavedChartData *savedData = [[SavedChartData alloc] initContinuousWithChartWidget:self notes:notes];
    if (!savedData.isDataValid) {
        NSError *validationError = [NSError errorWithDomain:@"ChartWidgetSave"
                                                        code:1002
                                                    userInfo:@{NSLocalizedDescriptionKey: @"Invalid chart data for continuous storage"}];
        if (completion) completion(NO, nil, validationError);
        return;
    }
    
    // Generate file path
    NSString *directory = [ChartWidget savedChartDataDirectory];
    NSString *filename = [savedData generateCurrentFilename];
    NSString *filePath = [directory stringByAppendingPathComponent:filename];
    
    // Save to file
    BOOL success = [savedData saveToFile:filePath error:&error];
    
    if (completion) {
        completion(success, success ? filePath : nil, error);
    }
}

#pragma mark - Load Saved Data

- (void)loadSavedDataInteractive {
    NSArray<NSString *> *availableFiles = [ChartWidget availableSavedChartDataFiles];
    
    if (availableFiles.count == 0) {
        NSAlert *alert = [[NSAlert alloc] init];
        alert.messageText = @"No Saved Chart Data";
        alert.informativeText = @"No saved chart data files found.";
        [alert addButtonWithTitle:@"OK"];
        [alert runModal];
        return;
    }
    
    // Create selection dialog
    NSAlert *selectionAlert = [[NSAlert alloc] init];
    selectionAlert.messageText = @"Load Saved Chart Data";
    selectionAlert.informativeText = @"Select a saved chart data file to load:";
    [selectionAlert addButtonWithTitle:@"Load"];
    [selectionAlert addButtonWithTitle:@"Cancel"];
    
    // ✅ FAST: Create popup button using MetadataCache
    NSPopUpButton *fileSelector = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(0, 0, 500, 25)];
    
    for (NSString *filePath in availableFiles) {
        NSString *filename = [filePath lastPathComponent];
        
        // ✅ FAST: Get metadata from cache instead of filename parsing
        StorageMetadataCache *cache = [StorageMetadataCache sharedCache];
        StorageMetadataItem *cacheItem = [cache itemForPath:filePath];
        
        if (cacheItem) {
            // ✅ FASTEST: Use cached metadata
            NSString *typeStr = cacheItem.isContinuous ? @"CONTINUOUS" : @"SNAPSHOT";
            NSString *displayTitle = [NSString stringWithFormat:@"%@ %@ [%@] %ld bars - %@",
                                    cacheItem.symbol,
                                    cacheItem.timeframe,
                                    typeStr,
                                    (long)cacheItem.barCount,
                                    cacheItem.dateRangeString];
            
            [fileSelector addItemWithTitle:displayTitle];
            fileSelector.lastItem.representedObject = filePath;
            
        } else if ([SavedChartData isNewFormatFilename:filename]) {
            // ✅ FALLBACK: Parse from filename if not in cache
            NSString *symbol = [SavedChartData symbolFromFilename:filename];
            NSString *timeframeStr = [SavedChartData timeframeFromFilename:filename];
            NSString *typeStr = [SavedChartData typeFromFilename:filename];
            NSInteger barCount = [SavedChartData barCountFromFilename:filename];
            NSString *dateRangeStr = [SavedChartData dateRangeStringFromFilename:filename];
            
            if (symbol && timeframeStr && typeStr) {
                NSString *displayTitle = [NSString stringWithFormat:@"%@ %@ [%@] %ld bars - %@",
                                        symbol,
                                        timeframeStr,
                                        typeStr,
                                        (long)barCount,
                                        dateRangeStr ?: @"Unknown"];
                
                [fileSelector addItemWithTitle:displayTitle];
                fileSelector.lastItem.representedObject = filePath;
            } else {
                // Incomplete metadata
                NSString *displayTitle = [NSString stringWithFormat:@"%@ (Incomplete metadata)", symbol ?: filename];
                [fileSelector addItemWithTitle:displayTitle];
                fileSelector.lastItem.representedObject = filePath;
            }
            
        } else {
            // ❌ OLD FORMAT: Still need to load file (should be rare after migration)
            NSLog(@"⚠️ Old format file detected, loading to get metadata: %@", filename);
            SavedChartData *savedData = [SavedChartData loadFromFile:filePath];
            if (savedData) {
                NSString *displayTitle = [NSString stringWithFormat:@"%@ %@ [%@] %ld bars - %@ (OLD FORMAT)",
                                        savedData.symbol,
                                        [self timeframeDisplayStringForTimeframe:savedData.timeframe],
                                        savedData.dataType == SavedChartDataTypeSnapshot ? @"SNAPSHOT" : @"CONTINUOUS",
                                        (long)savedData.barCount,
                                        savedData.formattedDateRange];
                [fileSelector addItemWithTitle:displayTitle];
                fileSelector.lastItem.representedObject = filePath;
            } else {
                // Ultimate fallback to filename
                [fileSelector addItemWithTitle:filename];
                fileSelector.lastItem.representedObject = filePath;
            }
        }
    }
    
    selectionAlert.accessoryView = fileSelector;
    
    NSModalResponse response = [selectionAlert runModal];
    if (response == NSAlertFirstButtonReturn) {
        NSString *selectedFile = fileSelector.selectedItem.representedObject;
        if (selectedFile) {
            [self loadSavedDataFromFile:selectedFile completion:^(BOOL success, NSError *error) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (success) {
                        NSAlert *successAlert = [[NSAlert alloc] init];
                        successAlert.messageText = @"Chart Data Loaded";
                        successAlert.informativeText = @"Saved chart data has been successfully loaded.";
                        [successAlert addButtonWithTitle:@"OK"];
                        [successAlert runModal];
                    } else {
                        NSAlert *errorAlert = [[NSAlert alloc] init];
                        errorAlert.messageText = @"Load Failed";
                        errorAlert.informativeText = error.localizedDescription ?: @"Failed to load saved data";
                        [errorAlert addButtonWithTitle:@"OK"];
                        [errorAlert runModal];
                    }
                });
            }];
        }
    }
}

- (void)logLoadDialogPerformanceStats:(NSTimeInterval)duration fileCount:(NSInteger)fileCount {
    NSLog(@"📊 Load Dialog Performance Stats:");
    NSLog(@"   Dialog creation duration: %.3f ms", duration * 1000);
    NSLog(@"   Files processed: %ld", (long)fileCount);
    NSLog(@"   Files per second: %.0f", fileCount / duration);
    NSLog(@"   Method: FILENAME PARSING ONLY (no file loading for new format)");
}

- (NSString *)createDisplayInfoFromFilename:(NSString *)filename {
    if (![SavedChartData isNewFormatFilename:filename]) {
        return filename; // Fallback for old format
    }
    
    NSString *symbol = [SavedChartData symbolFromFilename:filename];
    NSString *timeframeStr = [SavedChartData timeframeFromFilename:filename];
    NSString *typeStr = [SavedChartData typeFromFilename:filename];
    NSInteger barCount = [SavedChartData barCountFromFilename:filename];
    NSString *dateRangeStr = [SavedChartData dateRangeStringFromFilename:filename];
    
    if (!symbol || !timeframeStr || !typeStr) {
        return [NSString stringWithFormat:@"%@ (Incomplete metadata)", symbol ?: filename];
    }
    
    return [NSString stringWithFormat:@"%@ %@ [%@] %ld bars - %@",
            symbol,
            timeframeStr,
            typeStr,
            (long)barCount,
            dateRangeStr ?: @"Unknown"];
}

- (void)loadSavedDataFromFile:(NSString *)filePath completion:(void(^)(BOOL success, NSError * _Nullable error))completion {
    SavedChartData *savedData = [SavedChartData loadFromFile:filePath];
    
    if (!savedData || !savedData.isDataValid) {
        NSError *error = [NSError errorWithDomain:@"ChartWidgetLoad"
                                             code:1002
                                         userInfo:@{NSLocalizedDescriptionKey: @"Invalid or corrupted saved data"}];
        if (completion) completion(NO, error);
        return;
    }
    
    // Apply loaded data to chart widget
    dispatch_async(dispatch_get_main_queue(), ^{
        // Switch to static mode to prevent data reloading
        self.isStaticMode = YES;
        [self updateStaticModeUI];
        
        // Update symbol and timeframe
        self.currentSymbol = savedData.symbol;
        self.currentTimeframe = savedData.timeframe;
        self.symbolTextField.stringValue = savedData.symbol;
        
        // Update timeframe segmented control
        NSInteger segmentIndex = [self barTimeframeToSegmentIndex:savedData.timeframe];
            self.timeframeSegmented.selectedSegment = segmentIndex;
        
        
        // Apply data using the public method (it handles viewport setup internally)
        [self updateWithHistoricalBars:savedData.historicalBars];
        
        NSLog(@"✅ Loaded saved chart data: %@ (%@, %ld bars, %@)",
              savedData.symbol, savedData.timeframeDescription,
              (long)savedData.barCount, savedData.formattedDateRange);
        
        if (completion) completion(YES, nil);
    });
}

#pragma mark - File Management

+ (NSString *)savedChartDataDirectory {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);
    NSString *appSupportDir = paths.firstObject;
    NSString *appName = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleName"];
    return [[appSupportDir stringByAppendingPathComponent:appName] stringByAppendingPathComponent:@"SavedChartData"];
}


+ (BOOL)ensureSavedChartDataDirectoryExists:(NSError **)error {
    NSString *directory = [self savedChartDataDirectory];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    if (![fileManager fileExistsAtPath:directory]) {
        return [fileManager createDirectoryAtPath:directory
                      withIntermediateDirectories:YES
                                       attributes:nil
                                            error:error];
    }
    return YES;
}


+ (NSArray<NSString *> *)availableSavedChartDataFiles {
    NSLog(@"📦 Getting available chart data files from MetadataCache...");
    
    StorageMetadataCache *cache = [StorageMetadataCache sharedCache];
    NSArray<StorageMetadataItem *> *allItems = [cache allItems];
    
    if (allItems.count == 0) {
        NSLog(@"📦 No items in cache - building from filesystem...");
        NSString *directory = [self savedChartDataDirectory];
        [cache buildCacheFromDirectory:directory];
        allItems = [cache allItems];
    }
    
    // Sort by file modification time (newest first)
    NSArray<StorageMetadataItem *> *sortedItems = [allItems sortedArrayUsingComparator:^NSComparisonResult(StorageMetadataItem *obj1, StorageMetadataItem *obj2) {
        if (obj1.fileModificationTime > obj2.fileModificationTime) return NSOrderedAscending;
        if (obj1.fileModificationTime < obj2.fileModificationTime) return NSOrderedDescending;
        return NSOrderedSame;
    }];
    
    // Extract file paths
    NSMutableArray<NSString *> *filePaths = [NSMutableArray array];
    for (StorageMetadataItem *item in sortedItems) {
        [filePaths addObject:item.filePath];
    }
    
    NSLog(@"✅ Retrieved %ld chart data files from cache (no filesystem scanning)", (long)filePaths.count);
    return [filePaths copy];
}

+ (NSArray<NSString *> *)availableSavedChartDataFilesOfType:(SavedChartDataType)dataType {
    NSLog(@"📦 Getting chart data files of type %@ from MetadataCache...",
          dataType == SavedChartDataTypeContinuous ? @"Continuous" : @"Snapshot");
    
    StorageMetadataCache *cache = [StorageMetadataCache sharedCache];
    NSArray<StorageMetadataItem *> *filteredItems;
    
    if (dataType == SavedChartDataTypeContinuous) {
        filteredItems = [cache continuousItems];
    } else {
        filteredItems = [cache snapshotItems];
    }
    
    // Sort by file modification time (newest first)
    NSArray<StorageMetadataItem *> *sortedItems = [filteredItems sortedArrayUsingComparator:^NSComparisonResult(StorageMetadataItem *obj1, StorageMetadataItem *obj2) {
        if (obj1.fileModificationTime > obj2.fileModificationTime) return NSOrderedAscending;
        if (obj1.fileModificationTime < obj2.fileModificationTime) return NSOrderedDescending;
        return NSOrderedSame;
    }];
    
    // Extract file paths
    NSMutableArray<NSString *> *filePaths = [NSMutableArray array];
    for (StorageMetadataItem *item in sortedItems) {
        [filePaths addObject:item.filePath];
    }
    
    NSLog(@"✅ Retrieved %ld %@ files from cache",
          (long)filePaths.count,
          dataType == SavedChartDataTypeContinuous ? @"continuous" : @"snapshot");
    
    return [filePaths copy];
}

+ (NSArray<StorageMetadataItem *> *)availableStorageMetadataForSymbol:(NSString *)symbol {
    StorageMetadataCache *cache = [StorageMetadataCache sharedCache];
    NSArray<StorageMetadataItem *> *symbolItems = [cache itemsForSymbol:symbol];
    
    // Sort by file modification time (newest first)
    return [symbolItems sortedArrayUsingComparator:^NSComparisonResult(StorageMetadataItem *obj1, StorageMetadataItem *obj2) {
        if (obj1.fileModificationTime > obj2.fileModificationTime) return NSOrderedAscending;
        if (obj1.fileModificationTime < obj2.fileModificationTime) return NSOrderedDescending;
        return NSOrderedSame;
    }];
}

+ (NSArray<StorageMetadataItem *> *)availableStorageMetadataItems {
    StorageMetadataCache *cache = [StorageMetadataCache sharedCache];
    NSArray<StorageMetadataItem *> *allItems = [cache allItems];
    
    if (allItems.count == 0) {
        NSString *directory = [self savedChartDataDirectory];
        [cache buildCacheFromDirectory:directory];
        allItems = [cache allItems];
    }
    
    // Sort by file modification time (newest first)
    return [allItems sortedArrayUsingComparator:^NSComparisonResult(StorageMetadataItem *obj1, StorageMetadataItem *obj2) {
        if (obj1.fileModificationTime > obj2.fileModificationTime) return NSOrderedAscending;
        if (obj1.fileModificationTime < obj2.fileModificationTime) return NSOrderedDescending;
        return NSOrderedSame;
    }];
}

+ (BOOL)deleteSavedChartDataFile:(NSString *)filePath error:(NSError **)error {
    BOOL success = [[NSFileManager defaultManager] removeItemAtPath:filePath error:error];
    
    if (success) {
        // ✅ UPDATE CACHE AFTER DELETION
        StorageMetadataCache *cache = [StorageMetadataCache sharedCache];
        [cache handleFileDeleted:filePath];
        [cache saveToUserDefaults];
        
        NSLog(@"✅ Deleted file and updated cache: %@", [filePath lastPathComponent]);
    }
    
    return success;
}

#pragma mark - Context Menu Integration

- (void)addSaveDataMenuItemsToMenu:(NSMenu *)menu {
    // Add separator
    [menu addItem:[NSMenuItem separatorItem]];
    
    // Save visible range as snapshot
    NSMenuItem *saveSnapshotItem = [[NSMenuItem alloc] initWithTitle:@"📸 Save Visible Range as Snapshot..."
                                                              action:@selector(contextMenuSaveVisibleSnapshot:)
                                                       keyEquivalent:@""];
    saveSnapshotItem.target = self;
    [menu addItem:saveSnapshotItem];
    
    // Save full data as continuous
    NSMenuItem *saveContinuousItem = [[NSMenuItem alloc] initWithTitle:@"🔄 Save Full Data as Continuous..."
                                                                action:@selector(contextMenuSaveFullContinuous:)
                                                         keyEquivalent:@""];
    saveContinuousItem.target = self;
    [menu addItem:saveContinuousItem];
    
    // Separator
    [menu addItem:[NSMenuItem separatorItem]];
    
    // Load saved data
    NSMenuItem *loadDataItem = [[NSMenuItem alloc] initWithTitle:@"📂 Load Saved Data..."
                                                          action:@selector(contextMenuLoadSavedData:)
                                                   keyEquivalent:@""];
    loadDataItem.target = self;
    [menu addItem:loadDataItem];
}

#pragma mark - Context Menu Actions

- (IBAction)contextMenuSaveVisibleSnapshot:(id)sender {
    [self saveVisibleRangeAsSnapshotInteractive];
}

- (IBAction)contextMenuSaveFullContinuous:(id)sender {
    [self saveFullDataAsContinuousInteractive];
}

- (IBAction)contextMenuLoadSavedData:(id)sender {
    [self loadSavedDataInteractive];
}

#pragma mark - Helper Methods

- (BOOL)validateChartDataForSaving {
    NSArray<HistoricalBarModel *> *chartData = [self chartData];
    if (!self.currentSymbol || !chartData || chartData.count == 0) {
        NSAlert *alert = [[NSAlert alloc] init];
        alert.messageText = @"Cannot Save Chart Data";
        alert.informativeText = @"No chart data is currently loaded.";
        [alert addButtonWithTitle:@"OK"];
        [alert runModal];
        return NO;
    }
    return YES;
}

- (void)showSaveResult:(BOOL)success filePath:(NSString *)filePath error:(NSError *)error {
    if (success) {
        NSAlert *successAlert = [[NSAlert alloc] init];
        successAlert.messageText = @"Chart Data Saved";
        successAlert.informativeText = [NSString stringWithFormat:
            @"Successfully saved to:\n%@", filePath.lastPathComponent];
        [successAlert addButtonWithTitle:@"OK"];
        [successAlert runModal];
    } else {
        NSAlert *errorAlert = [[NSAlert alloc] init];
        errorAlert.messageText = @"Save Failed";
        errorAlert.informativeText = error.localizedDescription ?: @"Unknown error occurred";
        [errorAlert addButtonWithTitle:@"OK"];
        [errorAlert runModal];
    }
}

- (NSString *)formatDateForDisplay:(NSDate *)date {
    if (!date) return @"Unknown";
    
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    
    if (self.currentTimeframe <= BarTimeframe1Hour) {
        formatter.dateFormat = @"MMM d, HH:mm";
    } else {
        formatter.dateFormat = @"MMM d, yyyy";
    }
    
    return [formatter stringFromDate:date];
}

- (NSString *)timeframeDisplayStringForTimeframe:(BarTimeframe)timeframe {
    switch (timeframe) {
        case BarTimeframe1Min: return @"1min";
        case BarTimeframe5Min: return @"5min";
        case BarTimeframe15Min: return @"15min";
        case BarTimeframe30Min: return @"30min";
        case BarTimeframe1Hour: return @"1hour";
        case BarTimeframe4Hour: return @"4hour";
        case BarTimeframeDaily: return @"daily";
        case BarTimeframeWeekly: return @"weekly";
        case BarTimeframeMonthly: return @"monthly";
        default: return @"unknown";
    }
}

+ (NSArray<NSString *> *)availableSavedChartDataFilesOptimized {
    // ✅ REDIRECT TO NEW CACHE-BASED METHOD
    return [self availableSavedChartDataFiles];
}

// ✅ NUOVO METODO: Get file info senza caricare il file completo
+ (NSDictionary *)getFileInfoFromPath:(NSString *)filePath {
    // ✅ USE CACHE FIRST
    StorageMetadataCache *cache = [StorageMetadataCache sharedCache];
    StorageMetadataItem *cacheItem = [cache itemForPath:filePath];
    
    if (cacheItem) {
        // Return metadata from cache
        return @{
            @"symbol": cacheItem.symbol ?: @"Unknown",
            @"timeframe": cacheItem.timeframe ?: @"Unknown",
            @"type": cacheItem.isContinuous ? @"Continuous" : @"Snapshot",
            @"barCount": @(cacheItem.barCount),
            @"dateRange": cacheItem.dateRangeString ?: @"Unknown",
            @"fileSize": @(cacheItem.fileSizeBytes),
            @"hasGaps": @(cacheItem.hasGaps),
            @"extendedHours": @(cacheItem.includesExtendedHours),
            @"source": @"cache"
        };
    }
    
    // ✅ FALLBACK: Parse from filename
    NSString *filename = [filePath lastPathComponent];
    if ([SavedChartData isNewFormatFilename:filename]) {
        return @{
            @"symbol": [SavedChartData symbolFromFilename:filename] ?: @"Unknown",
            @"timeframe": [SavedChartData timeframeFromFilename:filename] ?: @"Unknown",
            @"type": [SavedChartData typeFromFilename:filename] ?: @"Unknown",
            @"barCount": @([SavedChartData barCountFromFilename:filename]),
            @"dateRange": [SavedChartData dateRangeStringFromFilename:filename] ?: @"Unknown",
            @"source": @"filename_parsing"
        };
    }
    
    // ❌ ULTIMATE FALLBACK: Load file (slow)
    NSLog(@"⚠️ Falling back to file loading for info: %@", filename);
    SavedChartData *savedData = [SavedChartData loadFromFile:filePath];
    if (savedData) {
        return @{
            @"symbol": savedData.symbol ?: @"Unknown",
            @"timeframe": [ChartWidget displayStringForTimeframe:savedData.timeframe],
            @"type": savedData.dataType == SavedChartDataTypeContinuous ? @"Continuous" : @"Snapshot",
            @"barCount": @(savedData.barCount),
            @"dateRange": savedData.formattedDateRange ?: @"Unknown",
            @"source": @"file_loading"
        };
    }
    
    return @{@"symbol": @"Unknown", @"source": @"failed"};
}

// ✅ NUOVO METODO: Get display summary per file senza caricarlo
+ (NSString *)getDisplaySummaryForFile:(NSString *)filePath {
    NSDictionary *info = [self getFileInfoFromPath:filePath];
    return [NSString stringWithFormat:@"%@ %@ [%@] %@ bars - %@",
            info[@"symbol"], info[@"timeframe"], info[@"type"], info[@"barCount"], info[@"dateRange"]];
}

+ (NSString *)displayStringForTimeframe:(BarTimeframe)timeframe {
    switch (timeframe) {
        case BarTimeframe1Min: return @"1min";
        case BarTimeframe5Min: return @"5min";
        case BarTimeframe15Min: return @"15min";
        case BarTimeframe30Min: return @"30min";
        case BarTimeframe1Hour: return @"1hour";
        case BarTimeframe4Hour: return @"4hour";
        case BarTimeframeDaily: return @"daily";
        case BarTimeframeWeekly: return @"weekly";
        case BarTimeframeMonthly: return @"monthly";
        default: return @"unknown";
    }
}



@end
