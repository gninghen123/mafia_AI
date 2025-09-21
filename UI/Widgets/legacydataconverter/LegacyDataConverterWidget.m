//
//  LegacyDataConverterWidget.m
//  TradingApp
//
//  Implementation del widget convertitore dati legacy
//

#import "LegacyDataConverterWidget.h"
#import "SavedChartData.h"
#import "RuntimeModels.h"
#import "ChartWidget+SaveData.h"
#import <objc/runtime.h>
#import "StorageManager.h"
#import "SavedChartData+FilenameParsing.h"


@implementation LegacyFileInfo
@end

@implementation LegacyDataConverterWidget

- (instancetype)initWithType:(NSString *)type panelType:(PanelType)panelType {
    self = [super initWithType:type panelType:panelType];
    if (self) {
        self.legacyFiles = @[];
        self.selectedDirectory = nil;
    }
    return self;
}

- (void)setupContentView {
    [super setupContentView];
    
    // Remove placeholder from BaseWidget
    for (NSView *subview in self.contentView.subviews) {
        [subview removeFromSuperview];
    }
    
    [self setupUI];
    [self setupConstraints];
    [self setupTableColumns];
}

#pragma mark - UI Setup

- (void)setupUI {
    NSView *container = self.contentView;
    
    // Directory selection section
    NSView *directorySection = [[NSView alloc] init];
    directorySection.translatesAutoresizingMaskIntoConstraints = NO;
    [container addSubview:directorySection];
    
    self.directoryLabel = [[NSTextField alloc] init];
    self.directoryLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.directoryLabel.stringValue = @"No directory selected";
    self.directoryLabel.editable = NO;
    self.directoryLabel.bordered = YES;
    self.directoryLabel.backgroundColor = [NSColor controlBackgroundColor];
    [directorySection addSubview:self.directoryLabel];
    
    self.selectDirectoryButton = [[NSButton alloc] init];
    self.selectDirectoryButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.selectDirectoryButton setTitle:@"Select DATA Directory"];
    self.selectDirectoryButton.target = self;
    self.selectDirectoryButton.action = @selector(selectDirectory:);
    [directorySection addSubview:self.selectDirectoryButton];
    
    // Action buttons section
    NSView *buttonSection = [[NSView alloc] init];
    buttonSection.translatesAutoresizingMaskIntoConstraints = NO;
    [container addSubview:buttonSection];
    
    self.scanButton = [[NSButton alloc] init];
    self.scanButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.scanButton setTitle:@"Scan Directory"];
    self.scanButton.target = self;
    self.scanButton.action = @selector(scanDirectory:);
    self.scanButton.enabled = NO;
    [buttonSection addSubview:self.scanButton];
    
    self.convertSelectedButton = [[NSButton alloc] init];
    self.convertSelectedButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.convertSelectedButton setTitle:@"Convert Selected"];
    self.convertSelectedButton.target = self;
    self.convertSelectedButton.action = @selector(convertSelectedFiles:);
    self.convertSelectedButton.enabled = NO;
    [buttonSection addSubview:self.convertSelectedButton];
    
    self.convertAllSnapshotButton = [[NSButton alloc] init];
    self.convertAllSnapshotButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.convertAllSnapshotButton setTitle:@"Convert All as Snapshot"];
    self.convertAllSnapshotButton.target = self;
    self.convertAllSnapshotButton.action = @selector(convertAllAsSnapshot:);
    self.convertAllSnapshotButton.enabled = NO;
    [buttonSection addSubview:self.convertAllSnapshotButton];
    
    self.refreshButton = [[NSButton alloc] init];
    self.refreshButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.refreshButton setTitle:@"Refresh"];
    self.refreshButton.target = self;
    self.refreshButton.action = @selector(refreshTable:);
    self.refreshButton.enabled = NO;
    [buttonSection addSubview:self.refreshButton];
    
    // Table view
    self.tableView = [[NSTableView alloc] init];
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    self.tableView.allowsMultipleSelection = YES;
    self.tableView.usesAlternatingRowBackgroundColors = YES;
    
    self.scrollView = [[NSScrollView alloc] init];
    self.scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    self.scrollView.documentView = self.tableView;
    self.scrollView.hasVerticalScroller = YES;
    self.scrollView.hasHorizontalScroller = YES;
    [container addSubview:self.scrollView];
    
    // Status section
    NSView *statusSection = [[NSView alloc] init];
    statusSection.translatesAutoresizingMaskIntoConstraints = NO;
    [container addSubview:statusSection];
    
    self.progressIndicator = [[NSProgressIndicator alloc] init];
    self.progressIndicator.translatesAutoresizingMaskIntoConstraints = NO;
    self.progressIndicator.style = NSProgressIndicatorStyleSpinning;
    self.progressIndicator.controlSize = NSControlSizeSmall;
    [statusSection addSubview:self.progressIndicator];
    
    self.statusLabel = [[NSTextField alloc] init];
    self.statusLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.statusLabel.stringValue = @"Select DATA directory to begin";
    self.statusLabel.editable = NO;
    self.statusLabel.bordered = NO;
    self.statusLabel.backgroundColor = [NSColor clearColor];
    [statusSection addSubview:self.statusLabel];
    
    // Store sections as properties for constraints - using objc_setAssociatedObject
    objc_setAssociatedObject(self, "directorySection", directorySection, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(self, "buttonSection", buttonSection, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(self, "statusSection", statusSection, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

// Update constraints to allow full horizontal stretching and remove minimum width restriction
- (void)setupConstraints {
    NSView *container = self.contentView;

    // Retrieve sections using objc_getAssociatedObject
    NSView *directorySection = objc_getAssociatedObject(self, "directorySection");
    NSView *buttonSection = objc_getAssociatedObject(self, "buttonSection");
    NSView *statusSection = objc_getAssociatedObject(self, "statusSection");

    [NSLayoutConstraint activateConstraints:@[
        // Directory section (top)
        [directorySection.topAnchor constraintEqualToAnchor:container.topAnchor constant:8],
        [directorySection.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:8],
        [directorySection.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-8],
        [directorySection.heightAnchor constraintEqualToConstant:32],

        // Directory label and button - FIXED LAYOUT
        [self.directoryLabel.leadingAnchor constraintEqualToAnchor:directorySection.leadingAnchor],
        [self.directoryLabel.trailingAnchor constraintEqualToAnchor:self.selectDirectoryButton.leadingAnchor constant:-8],
        [self.directoryLabel.centerYAnchor constraintEqualToAnchor:directorySection.centerYAnchor],
        [self.directoryLabel.heightAnchor constraintEqualToConstant:24],

        [self.selectDirectoryButton.trailingAnchor constraintEqualToAnchor:directorySection.trailingAnchor],
        [self.selectDirectoryButton.centerYAnchor constraintEqualToAnchor:directorySection.centerYAnchor],
        [self.selectDirectoryButton.widthAnchor constraintEqualToConstant:150],
        [self.selectDirectoryButton.heightAnchor constraintEqualToConstant:24],

        // Button section
        [buttonSection.topAnchor constraintEqualToAnchor:directorySection.bottomAnchor constant:8],
        [buttonSection.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:8],
        [buttonSection.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-8],
        [buttonSection.heightAnchor constraintEqualToConstant:32],

        // Action buttons - IMPROVED LAYOUT
        [self.scanButton.leadingAnchor constraintEqualToAnchor:buttonSection.leadingAnchor],
        [self.scanButton.centerYAnchor constraintEqualToAnchor:buttonSection.centerYAnchor],
        [self.scanButton.widthAnchor constraintGreaterThanOrEqualToConstant:100],
        [self.scanButton.heightAnchor constraintEqualToConstant:24],

        [self.convertSelectedButton.leadingAnchor constraintEqualToAnchor:self.scanButton.trailingAnchor constant:8],
        [self.convertSelectedButton.centerYAnchor constraintEqualToAnchor:buttonSection.centerYAnchor],
        [self.convertSelectedButton.widthAnchor constraintGreaterThanOrEqualToConstant:120],
        [self.convertSelectedButton.heightAnchor constraintEqualToConstant:24],

        [self.convertAllSnapshotButton.leadingAnchor constraintEqualToAnchor:self.convertSelectedButton.trailingAnchor constant:8],
        [self.convertAllSnapshotButton.centerYAnchor constraintEqualToAnchor:buttonSection.centerYAnchor],
        [self.convertAllSnapshotButton.widthAnchor constraintGreaterThanOrEqualToConstant:150],
        [self.convertAllSnapshotButton.heightAnchor constraintEqualToConstant:24],

        // Refresh button on the right with flexible space
        [self.refreshButton.trailingAnchor constraintEqualToAnchor:buttonSection.trailingAnchor],
        [self.refreshButton.centerYAnchor constraintEqualToAnchor:buttonSection.centerYAnchor],
        [self.refreshButton.widthAnchor constraintGreaterThanOrEqualToConstant:80],
        [self.refreshButton.heightAnchor constraintEqualToConstant:24],

        // Ensure space between convertAllSnapshot and refresh
        [self.refreshButton.leadingAnchor constraintGreaterThanOrEqualToAnchor:self.convertAllSnapshotButton.trailingAnchor constant:8],

        // Table view (main area) - ENSURED MINIMUM SIZE
        [self.scrollView.topAnchor constraintEqualToAnchor:buttonSection.bottomAnchor constant:8],
        [self.scrollView.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:8],
        [self.scrollView.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-8],
        [self.scrollView.bottomAnchor constraintEqualToAnchor:statusSection.topAnchor constant:-8],
        [self.scrollView.heightAnchor constraintGreaterThanOrEqualToConstant:200], // MINIMUM HEIGHT

        // Status section (bottom)
        [statusSection.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:8],
        [statusSection.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-8],
        [statusSection.bottomAnchor constraintEqualToAnchor:container.bottomAnchor constant:-8],
        [statusSection.heightAnchor constraintEqualToConstant:24],

        // Status components
        [self.progressIndicator.leadingAnchor constraintEqualToAnchor:statusSection.leadingAnchor],
        [self.progressIndicator.centerYAnchor constraintEqualToAnchor:statusSection.centerYAnchor],
        [self.progressIndicator.widthAnchor constraintEqualToConstant:16],
        [self.progressIndicator.heightAnchor constraintEqualToConstant:16],

        [self.statusLabel.leadingAnchor constraintEqualToAnchor:self.progressIndicator.trailingAnchor constant:8],
        [self.statusLabel.centerYAnchor constraintEqualToAnchor:statusSection.centerYAnchor],
        [self.statusLabel.trailingAnchor constraintLessThanOrEqualToAnchor:statusSection.trailingAnchor]
    ]];
    // Removed the fixed minimum width constraint so the content view can stretch fully horizontally.
}

// Make all table columns resizable so the tableView can expand to fill the window width
- (void)setupTableColumns {
    // Remove any existing columns
    while (self.tableView.tableColumns.count > 0) {
        [self.tableView removeTableColumn:self.tableView.tableColumns[0]];
    }

    // Symbol column
    NSTableColumn *symbolColumn = [[NSTableColumn alloc] initWithIdentifier:@"symbol"];
    symbolColumn.title = @"Symbol";
    symbolColumn.width = 80;
    symbolColumn.minWidth = 60;
    symbolColumn.resizingMask = NSTableColumnUserResizingMask | NSTableColumnAutoresizingMask;
    symbolColumn.sortDescriptorPrototype = [NSSortDescriptor sortDescriptorWithKey:@"symbol" ascending:YES selector:@selector(caseInsensitiveCompare:)];
    [self.tableView addTableColumn:symbolColumn];

    // Timeframe column
    NSTableColumn *timeframeColumn = [[NSTableColumn alloc] initWithIdentifier:@"timeframe"];
    timeframeColumn.title = @"Timeframe";
    timeframeColumn.width = 80;
    timeframeColumn.minWidth = 60;
    timeframeColumn.resizingMask = NSTableColumnUserResizingMask | NSTableColumnAutoresizingMask;
    timeframeColumn.sortDescriptorPrototype = [NSSortDescriptor sortDescriptorWithKey:@"mappedTimeframe" ascending:YES];
    [self.tableView addTableColumn:timeframeColumn];

    // File size column
    NSTableColumn *sizeColumn = [[NSTableColumn alloc] initWithIdentifier:@"fileSize"];
    sizeColumn.title = @"Size";
    sizeColumn.width = 70;
    sizeColumn.minWidth = 50;
    sizeColumn.resizingMask = NSTableColumnUserResizingMask | NSTableColumnAutoresizingMask;
    sizeColumn.sortDescriptorPrototype = [NSSortDescriptor sortDescriptorWithKey:@"fileSize" ascending:NO];
    [self.tableView addTableColumn:sizeColumn];

    // Date range column (only if parsed)
    NSTableColumn *rangeColumn = [[NSTableColumn alloc] initWithIdentifier:@"dateRange"];
    rangeColumn.title = @"Date Range";
    rangeColumn.width = 180;
    rangeColumn.minWidth = 150;
    rangeColumn.resizingMask = NSTableColumnUserResizingMask | NSTableColumnAutoresizingMask;
    rangeColumn.sortDescriptorPrototype = [NSSortDescriptor sortDescriptorWithKey:@"startDate" ascending:NO];
    [self.tableView addTableColumn:rangeColumn];

    // Bar count column (only if parsed)
    NSTableColumn *barsColumn = [[NSTableColumn alloc] initWithIdentifier:@"bars"];
    barsColumn.title = @"Bars";
    barsColumn.width = 60;
    barsColumn.minWidth = 50;
    barsColumn.resizingMask = NSTableColumnUserResizingMask | NSTableColumnAutoresizingMask;
    barsColumn.sortDescriptorPrototype = [NSSortDescriptor sortDescriptorWithKey:@"barCount" ascending:NO];
    [self.tableView addTableColumn:barsColumn];

    // Converted column
    NSTableColumn *convertedColumn = [[NSTableColumn alloc] initWithIdentifier:@"converted"];
    convertedColumn.title = @"Converted";
    convertedColumn.width = 80;
    convertedColumn.minWidth = 70;
    convertedColumn.resizingMask = NSTableColumnUserResizingMask | NSTableColumnAutoresizingMask;
    convertedColumn.sortDescriptorPrototype = [NSSortDescriptor sortDescriptorWithKey:@"isConverted" ascending:NO];
    [self.tableView addTableColumn:convertedColumn];

    // Status column
    NSTableColumn *statusColumn = [[NSTableColumn alloc] initWithIdentifier:@"status"];
    statusColumn.title = @"Status";
    statusColumn.width = 100;
    statusColumn.minWidth = 80;
    statusColumn.resizingMask = NSTableColumnUserResizingMask | NSTableColumnAutoresizingMask;
    statusColumn.sortDescriptorPrototype = [NSSortDescriptor sortDescriptorWithKey:@"isParsed" ascending:NO];
    [self.tableView addTableColumn:statusColumn];
}

#pragma mark - Actions

- (IBAction)selectDirectory:(id)sender {
    NSOpenPanel *openPanel = [NSOpenPanel openPanel];
    openPanel.canChooseDirectories = YES;
    openPanel.canChooseFiles = NO;
    openPanel.allowsMultipleSelection = NO;
    openPanel.prompt = @"Select DATA Directory";
    
    [openPanel beginSheetModalForWindow:self.view.window completionHandler:^(NSModalResponse result) {
        if (result == NSModalResponseOK) {
            NSURL *selectedURL = openPanel.URLs.firstObject;
            self.selectedDirectory = selectedURL.path;
            self.directoryLabel.stringValue = self.selectedDirectory;
            
            // Enable scan button
            self.scanButton.enabled = YES;
            self.statusLabel.stringValue = @"Directory selected. Click 'Scan Directory' to analyze files.";
        }
    }];
}

- (IBAction)scanDirectory:(id)sender {
    if (!self.selectedDirectory) return;
    
    [self.progressIndicator startAnimation:nil];
    self.statusLabel.stringValue = @"Scanning directory...";
    self.scanButton.enabled = NO;
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self scanDirectoryAndBuildFileList:self.selectedDirectory completion:^(NSArray<LegacyFileInfo *> *files, NSError *error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.progressIndicator stopAnimation:nil];
                self.scanButton.enabled = YES;
                
                if (error) {
                    self.statusLabel.stringValue = [NSString stringWithFormat:@"Scan failed: %@", error.localizedDescription];
                    NSAlert *alert = [[NSAlert alloc] init];
                    alert.messageText = @"Scan Failed";
                    alert.informativeText = error.localizedDescription;
                    [alert runModal];
                } else {
                    self.legacyFiles = files;
                    [self.tableView reloadData];
                    
                    self.convertSelectedButton.enabled = YES;
                    self.convertAllSnapshotButton.enabled = YES;
                    self.refreshButton.enabled = YES;
                    
                    NSInteger totalFiles = files.count;
                    NSInteger convertedFiles = 0;
                    for (LegacyFileInfo *file in files) {
                        if (file.isConverted) convertedFiles++;
                    }
                    
                    self.statusLabel.stringValue = [NSString stringWithFormat:@"Found %ld files (%ld already converted)", totalFiles, convertedFiles];
                }
            });
        }];
    });
}

- (IBAction)convertSelectedFiles:(id)sender {
    NSIndexSet *selectedIndexes = self.tableView.selectedRowIndexes;
    if (selectedIndexes.count == 0) {
        NSAlert *alert = [[NSAlert alloc] init];
        alert.messageText = @"No Selection";
        alert.informativeText = @"Please select files to convert.";
        [alert runModal];
        return;
    }
    
    [self showConversionOptionsForIndexes:selectedIndexes];
}

- (IBAction)convertAllAsSnapshot:(id)sender {
    if (self.legacyFiles.count == 0) return;
    
    // Filter non-converted files
    NSMutableArray *filesToConvert = [NSMutableArray array];
    for (LegacyFileInfo *file in self.legacyFiles) {
        if (!file.isConverted) {
            [filesToConvert addObject:file];
        }
    }
    
    if (filesToConvert.count == 0) {
        NSAlert *alert = [[NSAlert alloc] init];
        alert.messageText = @"No Files to Convert";
        alert.informativeText = @"All files have already been converted.";
        [alert runModal];
        return;
    }
    
    [self performBatchConversion:filesToConvert asType:SavedChartDataTypeSnapshot];
}

- (IBAction)refreshTable:(id)sender {
    if (self.selectedDirectory) {
        [self scanDirectory:sender];
    }
}

#pragma mark - Conversion Options Dialog

- (void)showConversionOptionsForIndexes:(NSIndexSet *)indexes {
    NSMutableArray *selectedFiles = [NSMutableArray array];
    [indexes enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop) {
        if (idx < self.legacyFiles.count) {
            LegacyFileInfo *file = self.legacyFiles[idx];
            if (!file.isConverted) {
                [selectedFiles addObject:file];
            }
        }
    }];
    
    if (selectedFiles.count == 0) {
        NSAlert *alert = [[NSAlert alloc] init];
        alert.messageText = @"No Files to Convert";
        alert.informativeText = @"All selected files have already been converted.";
        [alert runModal];
        return;
    }
    
    // Check if any can be continuous
    BOOL hasContinuousCandidate = NO;
    for (LegacyFileInfo *file in selectedFiles) {
        if (file.isParsed && file.canBeContinuous) {
            hasContinuousCandidate = YES;
            break;
        }
    }
    
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"Conversion Options";
    alert.informativeText = [NSString stringWithFormat:@"Convert %ld selected files as:", selectedFiles.count];
    [alert addButtonWithTitle:@"Snapshot"];
    
    if (hasContinuousCandidate) {
        [alert addButtonWithTitle:@"Continuous (when possible)"];
    }
    
    [alert addButtonWithTitle:@"Cancel"];
    
    NSModalResponse response = [alert runModal];
    
    if (response == NSAlertFirstButtonReturn) {
        // Snapshot
        [self performBatchConversion:selectedFiles asType:SavedChartDataTypeSnapshot];
    } else if (response == NSAlertSecondButtonReturn && hasContinuousCandidate) {
        // Continuous (when possible)
        [self performBatchConversion:selectedFiles asType:SavedChartDataTypeContinuous];
    }
}


#pragma mark - Timeframe Mapping



#pragma mark - Batch Conversion

- (void)performBatchConversion:(NSArray<LegacyFileInfo *> *)files asType:(SavedChartDataType)preferredType {
    if (files.count == 0) return;
    
    [self.progressIndicator startAnimation:nil];
    self.statusLabel.stringValue = @"Converting files...";
    
    // Disable buttons during conversion
    self.convertSelectedButton.enabled = NO;
    self.convertAllSnapshotButton.enabled = NO;
    self.scanButton.enabled = NO;
    self.refreshButton.enabled = NO;
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSInteger successCount = 0;
        NSInteger errorCount = 0;
        NSMutableArray *errors = [NSMutableArray array];
        
        for (LegacyFileInfo *file in files) {
            @autoreleasepool {
                NSError *error = nil;
                SavedChartDataType typeToUse = preferredType;

                // If preferred type is continuous but file can't be continuous, use snapshot
                if (typeToUse == SavedChartDataTypeContinuous && !file.canBeContinuous) {
                    typeToUse = SavedChartDataTypeSnapshot;
                }

                // Parse CSV file ONCE per file here, use bars immediately, do not store on fileInfo
                NSArray<HistoricalBarModel *> *bars = [self parseCSVFile:file.filePath
                                                                  symbol:file.symbol
                                                               timeframe:file.mappedTimeframe
                                                                   error:&error];

                if (!bars || bars.count == 0) {
                    errorCount++;
                    if (!error) {
                        error = [NSError errorWithDomain:@"LegacyConverter"
                                                    code:1002
                                                userInfo:@{NSLocalizedDescriptionKey: @"Failed to parse CSV file"}];
                    }
                    [errors addObject:[NSString stringWithFormat:@"%@: %@", file.symbol, error.localizedDescription]];
                } else {
                    // Check if continuous conversion is valid
                    BOOL canConvertContinuous = YES;
                    if (typeToUse == SavedChartDataTypeContinuous && !file.canBeContinuous) {
                        canConvertContinuous = NO;
                        error = [NSError errorWithDomain:@"LegacyConverter"
                                                    code:1003
                                                userInfo:@{NSLocalizedDescriptionKey: @"File data is too old for continuous conversion"}];
                        errorCount++;
                        [errors addObject:[NSString stringWithFormat:@"%@: %@", file.symbol, error.localizedDescription]];
                    }
                    if (typeToUse == SavedChartDataTypeSnapshot || canConvertContinuous) {
                        // Create SavedChartData
                        SavedChartData *savedData = [[SavedChartData alloc] init];
                        savedData.chartID = [[NSUUID UUID] UUIDString];
                        savedData.symbol = file.symbol;
                        // Map BarTimeframe to BarTimeframe before assigning
                        savedData.timeframe = file.mappedTimeframe;
                        savedData.dataType = typeToUse;
                        savedData.startDate = bars.firstObject.date;
                        savedData.endDate = bars.lastObject.date;
                        savedData.historicalBars = bars;
                        savedData.creationDate = [NSDate date];
                        savedData.includesExtendedHours = NO; // Legacy data assumption
                        savedData.notes = [NSString stringWithFormat:@"Converted from legacy CSV: %@", file.filePath];
                        if (typeToUse == SavedChartDataTypeContinuous) {
                            savedData.lastUpdateDate = [NSDate date];
                            savedData.lastSuccessfulUpdate = [NSDate date];
                        }
                        NSString *chartDataDir = [ChartWidget savedChartDataDirectory];
                        [[NSFileManager defaultManager] createDirectoryAtPath:chartDataDir
                                                  withIntermediateDirectories:YES
                                                                   attributes:nil
                                                                        error:nil];
                        NSString *filename = [savedData suggestedFilename];
                        NSString *outputPath = [chartDataDir stringByAppendingPathComponent:filename];
                        BOOL saveSuccess = [savedData saveToFile:outputPath error:&error];
                        if (saveSuccess) {
                            file.convertedFilePath = outputPath;
                            file.isConverted = YES;
                            successCount++;
                        } else {
                            errorCount++;
                            [errors addObject:[NSString stringWithFormat:@"%@: %@", file.symbol, error ? error.localizedDescription : @"Unknown error"]];
                        }
                    }
                }
                // Update progress on main thread
                dispatch_async(dispatch_get_main_queue(), ^{
                    NSInteger processed = successCount + errorCount;
                    self.statusLabel.stringValue = [NSString stringWithFormat:@"Converting... %ld/%ld", processed, files.count];
                    // [self.tableView reloadData];  // Removed per instructions
                });
            }
        }
        
        // Final update on main thread
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.progressIndicator stopAnimation:nil];
            
            // Re-enable buttons
            self.convertSelectedButton.enabled = YES;
            self.convertAllSnapshotButton.enabled = YES;
            self.scanButton.enabled = YES;
            self.refreshButton.enabled = YES;
            
            if (errorCount == 0) {
                self.statusLabel.stringValue = [NSString stringWithFormat:@"Conversion complete: %ld files converted successfully", successCount];
            } else {
                self.statusLabel.stringValue = [NSString stringWithFormat:@"Conversion complete: %ld success, %ld errors", successCount, errorCount];
                
                // Show error details
                if (errors.count > 0) {
                    NSAlert *errorAlert = [[NSAlert alloc] init];
                    errorAlert.messageText = @"Conversion Errors";
                    errorAlert.informativeText = [errors componentsJoinedByString:@"\n"];
                    [errorAlert runModal];
                }
            }
            // Simple reload - macOS handles sorting automatically
            // [self.tableView reloadData];  // Removed per instructions
        });
    });
}

#pragma mark - Table View Data Source

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    return self.legacyFiles.count;
}

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    LegacyFileInfo *file = self.legacyFiles[row];
    NSString *identifier = tableColumn.identifier;
    
    NSTextField *textField = [tableView makeViewWithIdentifier:identifier owner:nil];
    if (!textField) {
        textField = [[NSTextField alloc] init];
        textField.identifier = identifier;
        textField.editable = NO;
        textField.bordered = NO;
        textField.backgroundColor = [NSColor clearColor];
    }
    
    // Reset text color for reused cells
    textField.textColor = [NSColor labelColor];
    
    if ([identifier isEqualToString:@"symbol"]) {
        textField.stringValue = file.symbol;
    } else if ([identifier isEqualToString:@"timeframe"]) {
        textField.stringValue = [self displayStringForTimeframe:file.mappedTimeframe];
    } else if ([identifier isEqualToString:@"fileSize"]) {
        textField.stringValue = [self formatFileSize:file.fileSize];
    } else if ([identifier isEqualToString:@"dateRange"]) {
        if (file.isParsed && file.startDate && file.endDate) {
            NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
            formatter.dateStyle = NSDateFormatterShortStyle;
            NSString *startStr = [formatter stringFromDate:file.startDate];
            NSString *endStr = [formatter stringFromDate:file.endDate];
            textField.stringValue = [NSString stringWithFormat:@"%@ - %@", startStr, endStr];
        } else {
            textField.stringValue = @"Not parsed";
            textField.textColor = [NSColor secondaryLabelColor];
        }
    } else if ([identifier isEqualToString:@"bars"]) {
        if (file.isParsed) {
            textField.stringValue = [NSString stringWithFormat:@"%ld", file.barCount];
        } else {
            textField.stringValue = @"—";
            textField.textColor = [NSColor secondaryLabelColor];
        }
    } else if ([identifier isEqualToString:@"converted"]) {
        if (file.isConverted) {
            textField.stringValue = @"✓ Yes";
            textField.textColor = [NSColor systemGreenColor];
        } else {
            textField.stringValue = @"✗ No";
            textField.textColor = [NSColor systemRedColor];
        }
    } else if ([identifier isEqualToString:@"status"]) {
        if (file.isConverted) {
            textField.stringValue = @"Converted";
            textField.textColor = [NSColor systemGreenColor];
        } else if (file.isParsed) {
            if (file.isContinuous && file.canBeContinuous) {
                textField.stringValue = @"Ready (Continuous)";
                textField.textColor = [NSColor systemBlueColor];
            } else if (file.isContinuous) {
                textField.stringValue = @"Ready (Old data)";
                textField.textColor = [NSColor systemOrangeColor];
            } else {
                textField.stringValue = @"Ready (Gaps)";
                textField.textColor = [NSColor systemOrangeColor];
            }
        } else {
            textField.stringValue = @"Not parsed";
            textField.textColor = [NSColor secondaryLabelColor];
        }
    }
    
    return textField;
}

#pragma mark - Table View Delegate

- (void)tableViewSelectionDidChange:(NSNotification *)notification {
    NSIndexSet *selectedIndexes = self.tableView.selectedRowIndexes;
    self.convertSelectedButton.enabled = (selectedIndexes.count > 0);
}

// SIMPLE macOS automatic sorting - just this one method!
- (void)tableView:(NSTableView *)tableView sortDescriptorsDidChange:(NSArray<NSSortDescriptor *> *)oldDescriptors {
    self.legacyFiles = [self.legacyFiles sortedArrayUsingDescriptors:tableView.sortDescriptors];
    [tableView reloadData];
}

#pragma mark - Context Menu

- (NSMenu *)menuForTableView:(NSTableView *)tableView row:(NSInteger)row {
    if (row < 0 || row >= self.legacyFiles.count) return nil;
    
    LegacyFileInfo *file = self.legacyFiles[row];
    
    NSMenu *menu = [[NSMenu alloc] init];
    
    // Parse option (if not already parsed)
    if (!file.isParsed) {
        NSMenuItem *parseItem = [[NSMenuItem alloc] initWithTitle:@"Parse File Details"
                                                           action:@selector(parseSelectedFileDetails:)
                                                    keyEquivalent:@""];
        parseItem.target = self;
        parseItem.representedObject = @(row);
        [menu addItem:parseItem];
        [menu addItem:[NSMenuItem separatorItem]];
    }
    
    // Conversion options
    if (!file.isConverted) {
        NSMenuItem *snapshotItem = [[NSMenuItem alloc] initWithTitle:@"Convert as Snapshot"
                                                              action:@selector(convertFileAsSnapshot:)
                                                       keyEquivalent:@""];
        snapshotItem.target = self;
        snapshotItem.representedObject = @(row);
        [menu addItem:snapshotItem];
        
        if (file.isParsed && file.canBeContinuous) {
            NSMenuItem *continuousItem = [[NSMenuItem alloc] initWithTitle:@"Convert as Continuous"
                                                                    action:@selector(convertFileAsContinuous:)
                                                             keyEquivalent:@""];
            continuousItem.target = self;
            continuousItem.representedObject = @(row);
            [menu addItem:continuousItem];
        } else if (!file.isParsed) {
            NSMenuItem *continuousItem = [[NSMenuItem alloc] initWithTitle:@"Convert as Continuous (parse first)"
                                                                    action:@selector(parseAndConvertAsContinuous:)
                                                             keyEquivalent:@""];
            continuousItem.target = self;
            continuousItem.representedObject = @(row);
            [menu addItem:continuousItem];
        }
    } else {
        NSMenuItem *reconvertItem = [[NSMenuItem alloc] initWithTitle:@"Re-convert as Snapshot"
                                                               action:@selector(convertFileAsSnapshot:)
                                                        keyEquivalent:@""];
        reconvertItem.target = self;
        reconvertItem.representedObject = @(row);
        [menu addItem:reconvertItem];
        
        if (file.isParsed && file.canBeContinuous) {
            NSMenuItem *reconvertContinuousItem = [[NSMenuItem alloc] initWithTitle:@"Re-convert as Continuous"
                                                                             action:@selector(convertFileAsContinuous:)
                                                             keyEquivalent:@""];
            reconvertContinuousItem.target = self;
            reconvertContinuousItem.representedObject = @(row);
            [menu addItem:reconvertContinuousItem];
        }
        
        [menu addItem:[NSMenuItem separatorItem]];
        
        NSMenuItem *showFileItem = [[NSMenuItem alloc] initWithTitle:@"Show Converted File"
                                                              action:@selector(showConvertedFile:)
                                                       keyEquivalent:@""];
        showFileItem.target = self;
        showFileItem.representedObject = @(row);
        [menu addItem:showFileItem];
    }
    
    [menu addItem:[NSMenuItem separatorItem]];
    
    NSMenuItem *showOriginalItem = [[NSMenuItem alloc] initWithTitle:@"Show Original File"
                                                              action:@selector(showOriginalFile:)
                                                       keyEquivalent:@""];
    showOriginalItem.target = self;
    showOriginalItem.representedObject = @(row);
    [menu addItem:showOriginalItem];
    
    return menu;
}

- (void)parseSelectedFileDetails:(NSMenuItem *)sender {
    NSInteger row = [sender.representedObject integerValue];
    if (row >= 0 && row < self.legacyFiles.count) {
        LegacyFileInfo *file = self.legacyFiles[row];
        [self parseSelectedFiles:@[file] completion:^(NSInteger successCount, NSInteger errorCount) {
            [self.tableView reloadData];
        }];
    }
}

- (void)parseAndConvertAsContinuous:(NSMenuItem *)sender {
    NSInteger row = [sender.representedObject integerValue];
    if (row >= 0 && row < self.legacyFiles.count) {
        LegacyFileInfo *file = self.legacyFiles[row];
        
        // First parse the file
        [self parseSelectedFiles:@[file] completion:^(NSInteger successCount, NSInteger errorCount) {
            if (successCount > 0 && file.canBeContinuous) {
                // Then convert as continuous
                [self performBatchConversion:@[file] asType:SavedChartDataTypeContinuous];
            } else if (successCount > 0) {
                // Fallback to snapshot if can't be continuous
                NSAlert *alert = [[NSAlert alloc] init];
                alert.messageText = @"Cannot Convert as Continuous";
                alert.informativeText = @"File data is too old for continuous conversion. Convert as snapshot instead?";
                [alert addButtonWithTitle:@"Convert as Snapshot"];
                [alert addButtonWithTitle:@"Cancel"];
                
                if ([alert runModal] == NSAlertFirstButtonReturn) {
                    [self performBatchConversion:@[file] asType:SavedChartDataTypeSnapshot];
                }
            }
            [self.tableView reloadData];
        }];
    }
}

- (void)convertFileAsSnapshot:(NSMenuItem *)sender {
    NSInteger row = [sender.representedObject integerValue];
    if (row >= 0 && row < self.legacyFiles.count) {
        LegacyFileInfo *file = self.legacyFiles[row];
        [self performBatchConversion:@[file] asType:SavedChartDataTypeSnapshot];
    }
}

- (void)convertFileAsContinuous:(NSMenuItem *)sender {
    NSInteger row = [sender.representedObject integerValue];
    if (row >= 0 && row < self.legacyFiles.count) {
        LegacyFileInfo *file = self.legacyFiles[row];
        [self performBatchConversion:@[file] asType:SavedChartDataTypeContinuous];
    }
}

- (void)showConvertedFile:(NSMenuItem *)sender {
    NSInteger row = [sender.representedObject integerValue];
    if (row >= 0 && row < self.legacyFiles.count) {
        LegacyFileInfo *file = self.legacyFiles[row];
        if (file.convertedFilePath) {
            [[NSWorkspace sharedWorkspace] selectFile:file.convertedFilePath inFileViewerRootedAtPath:nil];
        }
    }
}

- (void)showOriginalFile:(NSMenuItem *)sender {
    NSInteger row = [sender.representedObject integerValue];
    if (row >= 0 && row < self.legacyFiles.count) {
        LegacyFileInfo *file = self.legacyFiles[row];
        [[NSWorkspace sharedWorkspace] selectFile:file.filePath inFileViewerRootedAtPath:nil];
    }
}

#pragma mark - Directory Scanning



- (void)scanDirectoryAndBuildFileList:(NSString *)directory completion:(void(^)(NSArray<LegacyFileInfo *> *files, NSError *error))completion {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSMutableArray<LegacyFileInfo *> *allFiles = [NSMutableArray array];
    
    @try {
        // ✅ NUOVO: Usa StorageManager + filename parsing invece di caricare file dal disco
        StorageManager *storageManager = [StorageManager sharedManager];
        NSMutableSet<NSString *> *convertedSymbolTimeframes = [NSMutableSet set];
        
        NSLog(@"📦 Checking %ld storages data for converted files...",
              (long)storageManager.allStorageItems.count);
        
        // ✅ Estrai symbol+timeframe dal filepath usando filename parsing
        for (ActiveStorageItem *item in storageManager.allStorageItems) {
            NSString *filename = [item.filePath lastPathComponent];
            
            // Verifica che sia un file nel nuovo formato
            if ([SavedChartData isNewFormatFilename:filename]) {
                NSString *symbol = [SavedChartData symbolFromFilename:filename];
                NSString *timeframeStr = [SavedChartData timeframeFromFilename:filename];
                
                if (symbol && timeframeStr) {
                    NSString *key = [NSString stringWithFormat:@"%@_%@", symbol, timeframeStr];
                    [convertedSymbolTimeframes addObject:key];
                    NSLog(@"   ✅ Found converted: %@", key);
                }
            }
        }
        
        NSLog(@"📦 Found %ld already converted symbol+timeframe combinations",
              (unsigned long)convertedSymbolTimeframes.count);
        
        // Scan timeframe directories - FAST SCAN ONLY
        NSArray *timeframeDirs = [fileManager contentsOfDirectoryAtPath:directory error:nil];
        
        for (NSString *timeframeDir in timeframeDirs) {
            NSString *timeframePath = [directory stringByAppendingPathComponent:timeframeDir];
            
            BOOL isDirectory;
            if (![fileManager fileExistsAtPath:timeframePath isDirectory:&isDirectory] || !isDirectory) {
                continue;
            }
            
            // Skip tick data for now
            if ([timeframeDir isEqualToString:@"tick"]) {
                NSLog(@"Skipping tick data directory");
                continue;
            }
            
            BarTimeframe mappedTimeframe = [self mapTimeframeFolderToEnum:timeframeDir];
            if (mappedTimeframe == -1) {
                NSLog(@"⚠️ Unknown timeframe folder: %@", timeframeDir);
                continue;
            }
            
            // Scan symbol files in timeframe directory - NO PARSING
            NSArray *symbolFiles = [fileManager contentsOfDirectoryAtPath:timeframePath error:nil];
            
            for (NSString *fileName in symbolFiles) {
                if (![fileName.pathExtension.lowercaseString isEqualToString:@"csv"] &&
                    ![fileName.pathExtension.lowercaseString isEqualToString:@"txt"]) {
                    continue;
                }
                
                NSString *symbol = [fileName stringByDeletingPathExtension];
                NSString *filePath = [timeframePath stringByAppendingPathComponent:fileName];
                
                // Get file size only (fast operation)
                NSDictionary *fileAttributes = [fileManager attributesOfItemAtPath:filePath error:nil];
                long long fileSize = [fileAttributes[NSFileSize] longLongValue];
                
                LegacyFileInfo *fileInfo = [[LegacyFileInfo alloc] init];
                fileInfo.symbol = symbol;
                fileInfo.timeframeFolder = timeframeDir;
                fileInfo.mappedTimeframe = mappedTimeframe;
                fileInfo.filePath = filePath;
                fileInfo.fileSize = fileSize;
                
                // NOT PARSED YET - these will be set on demand
                fileInfo.startDate = nil;
                fileInfo.endDate = nil;
                fileInfo.barCount = 0;
                fileInfo.isContinuous = NO;
                fileInfo.isParsed = NO;
                fileInfo.canBeContinuous = NO;
                
                // ✅ NUOVO: Check usando symbol + timeframe string del converter
                NSString *legacyTimeframeString = [self displayStringForTimeframe:mappedTimeframe];
                NSString *conversionKey = [NSString stringWithFormat:@"%@_%@", symbol, legacyTimeframeString];
                fileInfo.isConverted = [convertedSymbolTimeframes containsObject:conversionKey];
                
                // ✅ DEBUG: Log del confronto
                if (fileInfo.isConverted) {
                    NSLog(@"   ✅ %@ marked as CONVERTED (key: %@)", symbol, conversionKey);
                } else {
                    NSLog(@"   ❌ %@ marked as NOT converted (key: %@)", symbol, conversionKey);
                }
                
                [allFiles addObject:fileInfo];
            }
        }
        
        // Sort by symbol, then timeframe
        [allFiles sortUsingComparator:^NSComparisonResult(LegacyFileInfo *obj1, LegacyFileInfo *obj2) {
            NSComparisonResult symbolComparison = [obj1.symbol compare:obj2.symbol];
            if (symbolComparison != NSOrderedSame) {
                return symbolComparison;
            }
            return [@(obj1.mappedTimeframe) compare:@(obj2.mappedTimeframe)];
        }];
        
        NSInteger convertedCount = 0;
        for (LegacyFileInfo *file in allFiles) {
            if (file.isConverted) convertedCount++;
        }
        
        NSLog(@"📁 Fast scan complete: %lu files found (%ld already converted) - using StorageManager + filename parsing",
              (unsigned long)allFiles.count, (long)convertedCount);
        
        if (completion) {
            completion([allFiles copy], nil);
        }
        
    } @catch (NSException *exception) {
        NSError *error = [NSError errorWithDomain:@"LegacyConverter"
                                             code:1001
                                         userInfo:@{NSLocalizedDescriptionKey: exception.reason ?: @"Unknown error"}];
        if (completion) {
            completion(nil, error);
        }
    }
}


#pragma mark - On-Demand Parsing

- (void)parseSelectedFiles:(NSArray<LegacyFileInfo *> *)files completion:(void(^)(NSInteger successCount, NSInteger errorCount))completion {
    if (files.count == 0) {
        if (completion) completion(0, 0);
        return;
    }
    
    [self.progressIndicator startAnimation:nil];
    self.statusLabel.stringValue = [NSString stringWithFormat:@"Parsing %lu files...", (unsigned long)files.count];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSInteger successCount = 0;
        NSInteger errorCount = 0;
        
        for (LegacyFileInfo *file in files) {
            if (file.isParsed) {
                successCount++; // Already parsed
                continue;
            }
            
            NSError *parseError = nil;
            NSArray<HistoricalBarModel *> *bars = [self parseCSVFile:file.filePath
                                                              symbol:file.symbol
                                                           timeframe:file.mappedTimeframe
                                                               error:&parseError];
            
            if (bars && bars.count > 0) {
                // Update file info with parsed data
                file.startDate = bars.firstObject.date;
                file.endDate = bars.lastObject.date;
                file.barCount = bars.count;
                file.isContinuous = [self checkDataContinuity:bars timeframe:file.mappedTimeframe];
                file.canBeContinuous = [self canConvertAsContinuous:file];
                file.isParsed = YES;
                
                successCount++;
                
                NSLog(@"✅ Parsed %@ [%@]: %ld bars, %@ to %@",
                      file.symbol, [self displayStringForTimeframe:file.mappedTimeframe],
                      file.barCount, file.startDate, file.endDate);
            } else {
                errorCount++;
                NSLog(@"❌ Failed to parse %@: %@", file.filePath, parseError.localizedDescription);
            }
            
            // Update progress on main thread
            dispatch_async(dispatch_get_main_queue(), ^{
                NSInteger processed = successCount + errorCount;
                self.statusLabel.stringValue = [NSString stringWithFormat:@"Parsing... %ld/%ld", processed, files.count];
            });
        }
        
        // Final update on main thread
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.progressIndicator stopAnimation:nil];
            self.statusLabel.stringValue = [NSString stringWithFormat:@"Parsing complete: %ld success, %ld errors", successCount, errorCount];
            
            // Simple reload - macOS handles sorting automatically
            [self.tableView reloadData];
            
            if (completion) {
                completion(successCount, errorCount);
            }
        });
    });
}

- (BOOL)checkDataContinuity:(NSArray<HistoricalBarModel *> *)bars timeframe:(BarTimeframe)timeframe {
    if (bars.count < 2) return YES;
    
    NSTimeInterval expectedInterval;
    switch (timeframe) {
        case BarTimeframe1Min: expectedInterval = 60; break;
        case BarTimeframe5Min: expectedInterval = 300; break;
        case BarTimeframe15Min: expectedInterval = 900; break;
        case BarTimeframe30Min: expectedInterval = 1800; break;
        case BarTimeframe1Hour: expectedInterval = 3600; break;
        case BarTimeframe4Hour: expectedInterval = 14400; break;
        case BarTimeframeDaily: expectedInterval = 86400; break;
        case BarTimeframeWeekly: expectedInterval = 604800; break;
        case BarTimeframeMonthly: return YES; // Monthly data gaps are normal
        default: return YES;
    }
    
    // Check for significant gaps (allow for weekends/holidays on daily+ data)
    for (NSInteger i = 1; i < bars.count; i++) {
        NSTimeInterval gap = [bars[i].date timeIntervalSinceDate:bars[i-1].date];
        
        if (timeframe >= BarTimeframeDaily) {
            // For daily+ data, allow gaps up to 7 days (weekends + holidays)
            if (gap > expectedInterval * 7) {
                return NO;
            }
        } else {
            // For intraday, be more strict but allow some flexibility
            if (gap > expectedInterval * 2) {
                return NO;
            }
        }
    }
    
    return YES;
}

#pragma mark - CSV Parsing

- (NSArray<HistoricalBarModel *> *)parseCSVFile:(NSString *)filePath symbol:(NSString *)symbol timeframe:(BarTimeframe)timeframe error:(NSError **)error {
    NSString *csvContent = [NSString stringWithContentsOfFile:filePath encoding:NSUTF8StringEncoding error:error];
    if (!csvContent) {
        return nil;
    }
    
    NSMutableArray<HistoricalBarModel *> *bars = [NSMutableArray array];
    NSArray *lines = [csvContent componentsSeparatedByString:@"\n"];
    
    for (NSString *line in lines) {
        NSString *trimmedLine = [line stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (trimmedLine.length == 0) continue;
        
        NSArray *components = [trimmedLine componentsSeparatedByString:@","];
        if (components.count < 7) {
            NSLog(@"⚠️ Invalid CSV line in %@: %@", filePath, line);
            continue;
        }
        
        @try {
            // Format: timestamp,close,volume,open,high,low,adjustedClose
            NSString *timestampStr = components[0];
            double close = [components[1] doubleValue];
            long long volume = [components[2] longLongValue];
            double open = [components[3] doubleValue];
            double high = [components[4] doubleValue];
            double low = [components[5] doubleValue];
            double adjustedClose = [components[6] doubleValue];
            
            // Parse timestamp
            NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
            formatter.dateFormat = @"yyyy-MM-dd HH:mm:ss Z";
            NSDate *date = [formatter dateFromString:timestampStr];
            
            if (!date) {
                NSLog(@"⚠️ Invalid timestamp in %@: %@", filePath, timestampStr);
                continue;
            }
            
            // Create HistoricalBarModel
            HistoricalBarModel *bar = [[HistoricalBarModel alloc] init];
            bar.symbol = symbol;
            bar.date = date;
            bar.open = open;
            bar.high = high;
            bar.low = low;
            bar.close = close;
            bar.adjustedClose = adjustedClose;
            bar.volume = volume;
            bar.timeframe = timeframe;
            
            // Basic validation
            if (bar.high >= bar.low && bar.high >= bar.open && bar.high >= bar.close &&
                bar.low <= bar.open && bar.low <= bar.close) {
                [bars addObject:bar];
            } else {
                NSLog(@"⚠️ Invalid OHLC data in %@: %@", filePath, line);
            }
            
        } @catch (NSException *exception) {
            NSLog(@"⚠️ Parse error in %@: %@ - Line: %@", filePath, exception.reason, line);
            continue;
        }
    }
    
    // Sort by date
    [bars sortUsingComparator:^NSComparisonResult(HistoricalBarModel *obj1, HistoricalBarModel *obj2) {
        return [obj1.date compare:obj2.date];
    }];
    
    NSLog(@"📈 Parsed %ld bars from %@", bars.count, filePath);
    return [bars copy];
}

#pragma mark - Conversion Logic

- (BOOL)convertLegacyFile:(LegacyFileInfo *)fileInfo asType:(SavedChartDataType)dataType error:(NSError **)error {
    NSLog(@"🔄 Converting %@ [%@] as %@", fileInfo.symbol, [self displayStringForTimeframe:fileInfo.mappedTimeframe],
          dataType == SavedChartDataTypeSnapshot ? @"SNAPSHOT" : @"CONTINUOUS");
    
    // Ensure file is parsed first
    if (!fileInfo.isParsed) {
        NSLog(@"⚠️ File not parsed yet, parsing now...");
        NSArray<HistoricalBarModel *> *bars = [self parseCSVFile:fileInfo.filePath
                                                          symbol:fileInfo.symbol
                                                       timeframe:fileInfo.mappedTimeframe
                                                           error:error];
        
        if (!bars || bars.count == 0) {
            if (error && !*error) {
                *error = [NSError errorWithDomain:@"LegacyConverter"
                                             code:1002
                                         userInfo:@{NSLocalizedDescriptionKey: @"Failed to parse CSV file"}];
            }
            return NO;
        }
        
        // Update file info with parsed data
        fileInfo.startDate = bars.firstObject.date;
        fileInfo.endDate = bars.lastObject.date;
        fileInfo.barCount = bars.count;
        fileInfo.isContinuous = [self checkDataContinuity:bars timeframe:fileInfo.mappedTimeframe];
        fileInfo.canBeContinuous = [self canConvertAsContinuous:fileInfo];
        fileInfo.isParsed = YES;
    }
    
    // Parse CSV file again to get the actual bars for conversion
    NSArray<HistoricalBarModel *> *bars = [self parseCSVFile:fileInfo.filePath
                                                      symbol:fileInfo.symbol
                                                   timeframe:fileInfo.mappedTimeframe
                                                       error:error];
    
    if (!bars || bars.count == 0) {
        if (error && !*error) {
            *error = [NSError errorWithDomain:@"LegacyConverter"
                                         code:1002
                                     userInfo:@{NSLocalizedDescriptionKey: @"Failed to parse CSV file for conversion"}];
        }
        return NO;
    }
    
    // Check if continuous conversion is valid
    if (dataType == SavedChartDataTypeContinuous && !fileInfo.canBeContinuous) {
        if (error) {
            *error = [NSError errorWithDomain:@"LegacyConverter"
                                         code:1003
                                     userInfo:@{NSLocalizedDescriptionKey: @"File data is too old for continuous conversion"}];
        }
        return NO;
    }
    
    // Create SavedChartData
    SavedChartData *savedData = [[SavedChartData alloc] init];
    savedData.chartID = [[NSUUID UUID] UUIDString];
    savedData.symbol = fileInfo.symbol;
    // Map BarTimeframe to BarTimeframe before assigning
    savedData.timeframe = fileInfo.mappedTimeframe;
    savedData.dataType = dataType;
    savedData.startDate = bars.firstObject.date;
    savedData.endDate = bars.lastObject.date;
    savedData.historicalBars = bars;
    savedData.creationDate = [NSDate date];
    savedData.includesExtendedHours = NO; // Legacy data assumption
    savedData.notes = [NSString stringWithFormat:@"Converted from legacy CSV: %@", fileInfo.filePath];
    
    if (dataType == SavedChartDataTypeContinuous) {
        savedData.lastUpdateDate = [NSDate date];
        savedData.lastSuccessfulUpdate = [NSDate date];
    }
    
    // Generate filename and save
    NSString *chartDataDir = [ChartWidget savedChartDataDirectory];
    [[NSFileManager defaultManager] createDirectoryAtPath:chartDataDir
                              withIntermediateDirectories:YES
                                               attributes:nil
                                                    error:nil];
    
    NSString *filename = [savedData suggestedFilename];
    NSString *outputPath = [chartDataDir stringByAppendingPathComponent:filename];
    
    BOOL success = [savedData saveToFile:outputPath error:error];
    
    if (success) {
        fileInfo.convertedFilePath = outputPath;
        NSLog(@"✅ Converted %@ successfully to %@", fileInfo.symbol, outputPath);
    } else {
        NSLog(@"❌ Failed to convert %@: %@", fileInfo.symbol, error ? (*error).localizedDescription : @"Unknown error");
    }
    
    return success;
}

- (BOOL)canConvertAsContinuous:(LegacyFileInfo *)fileInfo {
    if (!fileInfo.isParsed || !fileInfo.isContinuous || !fileInfo.endDate) return NO;
    
    NSDate *now = [NSDate date];
    NSTimeInterval daysAgo = [now timeIntervalSinceDate:fileInfo.endDate] / (24 * 60 * 60);
    
    // Check Schwab intraday data limits
    switch (fileInfo.mappedTimeframe) {
        case BarTimeframe1Min:
            return daysAgo <= 45; // ~1.5 months
        case BarTimeframe5Min:
        case BarTimeframe15Min:
        case BarTimeframe30Min:
        case BarTimeframe1Hour:
        case BarTimeframe4Hour:
            return daysAgo <= 255; // ~8.5 months
        case BarTimeframeDaily:
        case BarTimeframeWeekly:
        case BarTimeframeMonthly:
            return YES; // Daily+ data has no practical API limit
        default:
            return NO;
    }
}

#pragma mark - Utility Methods

// Fix per LegacyDataConverterWidget.m - metodo mapTimeframeFolderToEnum

- (BarTimeframe)mapTimeframeFolderToEnum:(NSString *)folderName {
    // ✅ NORMALIZZA: converti a lowercase per essere case-insensitive
    NSString *normalized = folderName.lowercaseString;
    
    // Map folder names to BarTimeframe enum
    if ([normalized isEqualToString:@"1"]) return BarTimeframe1Min;
    if ([normalized isEqualToString:@"5"]) return BarTimeframe5Min;
    if ([normalized isEqualToString:@"15"]) return BarTimeframe15Min;
    if ([normalized isEqualToString:@"30"]) return BarTimeframe30Min;
    if ([normalized isEqualToString:@"60"]) return BarTimeframe1Hour;
    if ([normalized isEqualToString:@"240"]) return BarTimeframe4Hour;
    
    // ✅ FIXED: Ora funziona sia con 'd' che con 'D'
    if ([normalized isEqualToString:@"d"] || [normalized isEqualToString:@"daily"]) return BarTimeframeDaily;
    if ([normalized isEqualToString:@"w"] || [normalized isEqualToString:@"weekly"]) return BarTimeframeWeekly;
    if ([normalized isEqualToString:@"m"] || [normalized isEqualToString:@"monthly"]) return BarTimeframeMonthly;
    
    return -1; // Unknown timeframe
}

- (NSString *)displayStringForTimeframe:(BarTimeframe)timeframe {
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

- (NSString *)formatFileSize:(long long)bytes {
    NSByteCountFormatter *formatter = [[NSByteCountFormatter alloc] init];
    formatter.allowedUnits = NSByteCountFormatterUseKB | NSByteCountFormatterUseMB;
    formatter.countStyle = NSByteCountFormatterCountStyleFile;
    return [formatter stringFromByteCount:bytes];
}

#pragma mark - State Management

- (NSDictionary *)serializeState {
    NSMutableDictionary *state = [[super serializeState] mutableCopy];
    
    if (self.selectedDirectory) {
        state[@"selectedDirectory"] = self.selectedDirectory;
    }
    
    return [state copy];
}

- (void)restoreState:(NSDictionary *)state {
    [super restoreState:state];
    
    if (state[@"selectedDirectory"]) {
        self.selectedDirectory = state[@"selectedDirectory"];
        self.directoryLabel.stringValue = self.selectedDirectory;
        self.scanButton.enabled = YES;
    }
}

@end
