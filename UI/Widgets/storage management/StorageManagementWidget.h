//
//  StorageManagementWidget.h
//  TradingApp
//
//  Widget per visualizzare e gestire tutti i continuous storage attivi
//  Fornisce dashboard completa per il monitoring dello storage automatico
//

#import "BaseWidget.h"
#import "StorageManager.h"

NS_ASSUME_NONNULL_BEGIN

/// Table view columns for storage display
typedef NS_ENUM(NSInteger, StorageTableColumn) {
    StorageTableColumnSymbol = 0,
    StorageTableColumnTimeframe,
    StorageTableColumnRange,
    StorageTableColumnStatus,
    StorageTableColumnNextUpdate,
    StorageTableColumnActions
};

@interface StorageManagementWidget : BaseWidget <NSTableViewDataSource, NSTableViewDelegate>

#pragma mark - UI Components

@property (nonatomic, strong) IBOutlet NSTableView *storageTableView;
@property (nonatomic, strong) IBOutlet NSTextField *statusLabel;
@property (nonatomic, strong) IBOutlet NSButton *pauseAllButton;
@property (nonatomic, strong) IBOutlet NSButton *updateAllButton;
@property (nonatomic, strong) IBOutlet NSButton *refreshButton;

#pragma mark - Statistics Display

@property (nonatomic, strong) IBOutlet NSTextField *totalStoragesLabel;
@property (nonatomic, strong) IBOutlet NSTextField *activeStoragesLabel;
@property (nonatomic, strong) IBOutlet NSTextField *errorStoragesLabel;
@property (nonatomic, strong) IBOutlet NSTextField *pausedStoragesLabel;
@property (nonatomic, strong) IBOutlet NSTextField *nextUpdateLabel;

#pragma mark - Data Source

/// Array of ActiveStorageItem objects for table display
@property (nonatomic, strong) NSArray<ActiveStorageItem *> *storageItems;

/// Auto-refresh timer for UI updates
@property (nonatomic, strong) NSTimer *refreshTimer;

#pragma mark - Actions

/// Refresh storage list and statistics
- (IBAction)refreshStorageList:(id)sender;

/// Pause/resume all automatic updates
- (IBAction)togglePauseAllStorages:(id)sender;

/// Force update all active storages
- (IBAction)forceUpdateAllStorages:(id)sender;

/// Open storage file browser
- (IBAction)browseStorageFiles:(id)sender;

#pragma mark - Context Menu Actions

/// Show context menu for selected storage item
- (void)showContextMenuForStorageItem:(ActiveStorageItem *)item atPoint:(NSPoint)point;

/// Context menu actions
- (void)forceUpdateStorage:(ActiveStorageItem *)item;
- (void)pauseResumeStorage:(ActiveStorageItem *)item;
- (void)convertToSnapshot:(ActiveStorageItem *)item;
- (void)deleteStorage:(ActiveStorageItem *)item;
- (void)showStorageDetails:(ActiveStorageItem *)item;
- (void)openStorageLocation:(ActiveStorageItem *)item;

#pragma mark - Status Management

/// Update all status labels and statistics
- (void)updateStatusDisplay;

/// Get status string for storage item
- (NSString *)statusStringForStorageItem:(ActiveStorageItem *)item;

/// Get status color for storage item
- (NSColor *)statusColorForStorageItem:(ActiveStorageItem *)item;

#pragma mark - Auto-refresh

/// Start/stop automatic UI refresh timer
- (void)startAutoRefresh;
- (void)stopAutoRefresh;

@end

NS_ASSUME_NONNULL_END

