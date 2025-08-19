//
//  LegacyDataConverterWidget.h
//  TradingApp
//
//  Widget per convertire dati CSV legacy in formato SavedChartData
//

#import "BaseWidget.h"
#import "SavedChartData.h"

NS_ASSUME_NONNULL_BEGIN

/// Struttura per rappresentare un file legacy scansionato
@interface LegacyFileInfo : NSObject
@property (nonatomic, strong) NSString *symbol;
@property (nonatomic, strong) NSString *timeframeFolder; // "1", "D", "60", etc.
@property (nonatomic, assign) BarTimeframe mappedTimeframe;
@property (nonatomic, strong) NSString *filePath;

// Parsed info (populated only on demand)
@property (nonatomic, strong, nullable) NSDate *startDate;
@property (nonatomic, strong, nullable) NSDate *endDate;
@property (nonatomic, assign) NSInteger barCount;
@property (nonatomic, assign) BOOL isContinuous; // NO gaps in data
@property (nonatomic, assign) BOOL isParsed; // Whether detailed parsing has been done

// Conversion status
@property (nonatomic, assign) BOOL isConverted; // Already converted
@property (nonatomic, assign) BOOL canBeContinuous; // End date within Schwab intraday limits
@property (nonatomic, strong, nullable) NSString *convertedFilePath; // Path to .chartdata file if converted

// File size info (always available)
@property (nonatomic, assign) long long fileSize; // File size in bytes
@end

@interface LegacyDataConverterWidget : BaseWidget <NSTableViewDataSource, NSTableViewDelegate>

#pragma mark - UI Components

/// Directory selection
@property (nonatomic, strong) NSTextField *directoryLabel;
@property (nonatomic, strong) NSButton *selectDirectoryButton;
@property (nonatomic, strong) NSString *selectedDirectory;

/// Table view for file listing
@property (nonatomic, strong) NSScrollView *scrollView;
@property (nonatomic, strong) NSTableView *tableView;

/// Action buttons
@property (nonatomic, strong) NSButton *scanButton;
@property (nonatomic, strong) NSButton *convertSelectedButton;
@property (nonatomic, strong) NSButton *convertAllSnapshotButton;
@property (nonatomic, strong) NSButton *refreshButton;

/// Status display
@property (nonatomic, strong) NSTextField *statusLabel;
@property (nonatomic, strong) NSProgressIndicator *progressIndicator;

#pragma mark - Data Source

/// Array of scanned legacy files
@property (nonatomic, strong) NSArray<LegacyFileInfo *> *legacyFiles;

#pragma mark - Actions

/// Select DATA directory
- (IBAction)selectDirectory:(id)sender;

/// Scan selected directory for legacy files
- (IBAction)scanDirectory:(id)sender;

/// Convert selected files
- (IBAction)convertSelectedFiles:(id)sender;

/// Convert all files as snapshot
- (IBAction)convertAllAsSnapshot:(id)sender;

/// Refresh table after conversion
- (IBAction)refreshTable:(id)sender;

#pragma mark - Conversion Logic

/// Fast scan directory for files (no parsing)
- (void)scanDirectoryAndBuildFileList:(NSString *)directory completion:(void(^)(NSArray<LegacyFileInfo *> *files, NSError *error))completion;

/// Parse selected files for detailed info (on demand)
- (void)parseSelectedFiles:(NSArray<LegacyFileInfo *> *)files completion:(void(^)(NSInteger successCount, NSInteger errorCount))completion;

/// Parse CSV file and create HistoricalBarModel array
- (NSArray<HistoricalBarModel *> *)parseCSVFile:(NSString *)filePath symbol:(NSString *)symbol timeframe:(BarTimeframe)timeframe error:(NSError **)error;

/// Convert LegacyFileInfo to SavedChartData (requires parsing first)
- (BOOL)convertLegacyFile:(LegacyFileInfo *)fileInfo asType:(SavedChartDataType)dataType error:(NSError **)error;

/// Check if file can be converted as continuous (requires parsing first)
- (BOOL)canConvertAsContinuous:(LegacyFileInfo *)fileInfo;

/// Map timeframe folder name to BarTimeframe enum
- (BarTimeframe)mapTimeframeFolderToEnum:(NSString *)folderName;

/// Get display string for timeframe
- (NSString *)displayStringForTimeframe:(BarTimeframe)timeframe;

@end

NS_ASSUME_NONNULL_END
