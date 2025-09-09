

//
//  ChartWidget+SaveData.m
//  TradingApp
//
//  Implementation for saving/loading chart data
//

#import "ChartWidget+SaveData.h"
#import "SavedChartData+FilenameUpdate.h"

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
    SavedChartData *savedData = [[SavedChartData alloc] initSnapshotWithChartWidget:self notes:notes];
    if (!savedData.isDataValid) {
        NSError *validationError = [NSError errorWithDomain:@"ChartWidgetSave"
                                                        code:1001
                                                    userInfo:@{NSLocalizedDescriptionKey: @"Invalid chart data for snapshot"}];
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
    
    // Create popup button for file selection with detailed info
    NSPopUpButton *fileSelector = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(0, 0, 500, 25)];
    for (NSString *filePath in availableFiles) {
        // Load file to get metadata for display
        SavedChartData *savedData = [SavedChartData loadFromFile:filePath];
        if (savedData) {
            NSString *displayTitle = [NSString stringWithFormat:@"%@ %@ [%@] %ld bars - %@",
                                    savedData.symbol,
                                    savedData.timeframeDescription,
                                    savedData.dataType == SavedChartDataTypeSnapshot ? @"SNAPSHOT" : @"CONTINUOUS",
                                    (long)savedData.barCount,
                                    savedData.formattedDateRange];
            [fileSelector addItemWithTitle:displayTitle];
            fileSelector.lastItem.representedObject = filePath;
        } else {
            // Fallback to filename if loading fails
            NSString *filename = filePath.lastPathComponent;
            [fileSelector addItemWithTitle:filename];
            fileSelector.lastItem.representedObject = filePath;
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
        self.timeframeSegmented.selectedSegment = savedData.timeframe;
        
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
    NSString *directory = [self savedChartDataDirectory];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    NSError *error;
    NSArray *files = [fileManager contentsOfDirectoryAtPath:directory error:&error];
    if (!files) {
        NSLog(@"❌ Failed to list saved chart data files: %@", error.localizedDescription);
        return @[];
    }
    
    // Filter for .chartdata files and return full paths
    NSMutableArray *chartDataFiles = [NSMutableArray array];
    for (NSString *filename in files) {
        if ([filename.pathExtension.lowercaseString isEqualToString:@"chartdata"]) {
            NSString *fullPath = [directory stringByAppendingPathComponent:filename];
            [chartDataFiles addObject:fullPath];
        }
    }
    
    // Sort by modification date (newest first)
    [chartDataFiles sortUsingComparator:^NSComparisonResult(NSString *path1, NSString *path2) {
        NSDictionary *attrs1 = [[NSFileManager defaultManager] attributesOfItemAtPath:path1 error:nil];
        NSDictionary *attrs2 = [[NSFileManager defaultManager] attributesOfItemAtPath:path2 error:nil];
        NSDate *date1 = attrs1[NSFileModificationDate];
        NSDate *date2 = attrs2[NSFileModificationDate];
        return [date2 compare:date1]; // Newest first
    }];
    
    return [chartDataFiles copy];
}

+ (NSArray<NSString *> *)availableSavedChartDataFilesOfType:(SavedChartDataType)dataType {
    NSArray<NSString *> *allFiles = [self availableSavedChartDataFiles];
    NSMutableArray<NSString *> *filteredFiles = [NSMutableArray array];
    
    for (NSString *filePath in allFiles) {
        SavedChartData *savedData = [SavedChartData loadFromFile:filePath];
        if (savedData && savedData.dataType == dataType) {
            [filteredFiles addObject:filePath];
        }
    }
    
    return [filteredFiles copy];
}

+ (BOOL)deleteSavedChartDataFile:(NSString *)filePath error:(NSError **)error {
    return [[NSFileManager defaultManager] removeItemAtPath:filePath error:error];
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
    
    if (self.currentTimeframe <= ChartTimeframe1Hour) {
        formatter.dateFormat = @"MMM d, HH:mm";
    } else {
        formatter.dateFormat = @"MMM d, yyyy";
    }
    
    return [formatter stringFromDate:date];
}

- (NSString *)timeframeDisplayStringForTimeframe:(ChartTimeframe)timeframe {
    switch (timeframe) {
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

@end
