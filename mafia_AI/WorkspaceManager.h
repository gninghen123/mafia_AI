//
//  WorkspaceManager.h
//  TradingApp
//
//  Manages workspace saving, loading, and restoration
//  A workspace is a collection of FloatingWindows + GridWindows
//

#import <Foundation/Foundation.h>

@class AppDelegate;
@class FloatingWidgetWindow;
@class GridWindow;

NS_ASSUME_NONNULL_BEGIN

@interface WorkspaceManager : NSObject

// Singleton
+ (instancetype)sharedManager;

// AppDelegate reference (needed to create windows)
@property (nonatomic, weak) AppDelegate *appDelegate;

#pragma mark - Workspace Management

// Save current workspace (all open floating + grid windows)
- (BOOL)saveCurrentWorkspaceWithName:(NSString *)name;

// Load workspace (closes all windows, opens saved ones)
- (BOOL)loadWorkspaceWithName:(NSString *)name;

// Delete workspace
- (BOOL)deleteWorkspaceWithName:(NSString *)name;

// List all saved workspaces
- (NSArray<NSString *> *)availableWorkspaces;

// Check if workspace exists
- (BOOL)workspaceExistsWithName:(NSString *)name;

#pragma mark - Auto-save/restore

// Save "Last Used" workspace automatically
- (void)saveLastUsedWorkspace;

// Restore "Last Used" workspace on app launch
- (void)restoreLastUsedWorkspace;

// Clear "Last Used" workspace (reset auto-restore)
- (void)clearLastUsedWorkspace;

#pragma mark - Export/Import

// Export workspace to file
- (BOOL)exportWorkspace:(NSString *)name toURL:(NSURL *)fileURL;

// Import workspace from file
- (BOOL)importWorkspaceFromURL:(NSURL *)fileURL withName:(NSString *)name;
#pragma mark - Auto-save

// Auto-save last used workspace (debounced)
- (void)autoSaveLastUsedWorkspace;

@end

NS_ASSUME_NONNULL_END
