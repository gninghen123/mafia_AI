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

/// Filtro per tipo di storage da visualizzare
typedef NS_ENUM(NSInteger, StorageFilterType) {
    StorageFilterTypeAll = 0,
    StorageFilterTypeContinuous,
    StorageFilterTypeSnapshot
};

/// Table view columns for storage display
typedef NS_ENUM(NSInteger, StorageTableColumn) {
    StorageTableColumnSymbol = 0,
    StorageTableColumnTimeframe,
    StorageTableColumnType,
    StorageTableColumnStatus,
    StorageTableColumnRange,
    StorageTableColumnActions
};

@interface StorageManagementWidget : BaseWidget <NSTableViewDataSource, NSTableViewDelegate>

#pragma mark - UI Components

@property (nonatomic, strong) IBOutlet NSTableView *storageTableView;
@property (nonatomic, strong) IBOutlet NSTextField *statusLabel;
@property (nonatomic, strong) IBOutlet NSButton *pauseAllButton;
@property (nonatomic, strong) IBOutlet NSButton *updateAllButton;
@property (nonatomic, strong) IBOutlet NSButton *refreshButton;

/// Filtro per tipo di storage
@property (nonatomic, weak) IBOutlet NSSegmentedControl *filterSegmentedControl;

#pragma mark - Statistics Display

@property (nonatomic, strong) IBOutlet NSTextField *totalStoragesLabel;
@property (nonatomic, strong) IBOutlet NSTextField *continuousStoragesLabel;
@property (nonatomic, strong) IBOutlet NSTextField *snapshotStoragesLabel;
@property (nonatomic, strong) IBOutlet NSTextField *errorStoragesLabel;
@property (nonatomic, strong) IBOutlet NSTextField *nextUpdateLabel;

#pragma mark - Data Source

/// Filtro attualmente attivo
@property (nonatomic, assign) StorageFilterType currentFilter;

/// Array di UnifiedStorageItem objects per table display
@property (nonatomic, strong) NSArray<UnifiedStorageItem *> *storageItems;

/// Auto-refresh timer for UI updates
@property (nonatomic, strong) NSTimer *refreshTimer;

#pragma mark - Actions

/// Cambia il filtro per tipo di storage
- (IBAction)filterTypeChanged:(NSSegmentedControl *)sender;

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
- (void)forceUpdateStorage:(UnifiedStorageItem *)item;
- (void)pauseResumeStorage:(UnifiedStorageItem *)item;
- (void)convertToSnapshot:(UnifiedStorageItem *)item;
- (void)deleteStorage:(UnifiedStorageItem *)item;
- (void)showStorageDetails:(UnifiedStorageItem *)item;
- (void)openStorageLocation:(UnifiedStorageItem *)item;
- (void)loadInChart:(UnifiedStorageItem *)item; // NEW: Per snapshot

#pragma mark - Status Management

/// Update all status labels and statistics
- (void)updateStatusDisplay;

/// Get status string for unified storage item
- (NSString *)statusStringForStorageItem:(UnifiedStorageItem *)item;

/// Get status color for unified storage item
- (NSColor *)statusColorForStorageItem:(UnifiedStorageItem *)item;

/// Get type string for display
- (NSString *)typeStringForStorageItem:(UnifiedStorageItem *)item;

#pragma mark - Auto-refresh

/// Start/stop automatic UI refresh timer
- (void)startAutoRefresh;
- (void)stopAutoRefresh;

@end

NS_ASSUME_NONNULL_END
