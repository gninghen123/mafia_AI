//
//  WorkspaceManager.m
//  TradingApp
//

#import "WorkspaceManager.h"
#import "AppDelegate.h"
#import "FloatingWidgetWindow.h"
#import "GridWindow.h"
#import "BaseWidget.h"
#import "WidgetTypeManager.h"

static NSString * const kWorkspacePrefix = @"Workspace_";
static NSString * const kLastUsedWorkspaceKey = @"LastUsedWorkspace";
static NSString * const kWorkspaceVersion = @"1.0";


@interface WorkspaceManager ()
@property (nonatomic, strong) NSDate *lastAutoSaveTime;
@property (nonatomic, assign) BOOL isPerformingWorkspaceOperation;  // ✅ FIX: Prevent auto-save during workspace ops
@end
@implementation WorkspaceManager

#pragma mark - Singleton

+ (instancetype)sharedManager {
    static WorkspaceManager *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[WorkspaceManager alloc] init];
    });
    return sharedInstance;
}

#pragma mark - Workspace Saving

- (BOOL)saveCurrentWorkspaceWithName:(NSString *)name {
    if (!name || name.length == 0) {
        NSLog(@"❌ WorkspaceManager: Invalid workspace name");
        return NO;
    }

    if (!self.appDelegate) {
        NSLog(@"❌ WorkspaceManager: AppDelegate not set");
        return NO;
    }

    NSLog(@"💾 WorkspaceManager: Saving workspace '%@'", name);
    NSLog(@"   Current state: %ld floating + %ld grid windows",
          (long)self.appDelegate.floatingWindows.count,
          (long)self.appDelegate.gridWindows.count);

    // Serialize current state
    NSDictionary *workspaceData = [self serializeCurrentWorkspace];

    if (!workspaceData) {
        NSLog(@"❌ WorkspaceManager: Failed to serialize workspace");
        return NO;
    }

    NSLog(@"   Serialized: %ld floating + %ld grid windows",
          (long)[workspaceData[@"floatingWindows"] count],
          (long)[workspaceData[@"gridWindows"] count]);

    // Save to UserDefaults
    NSString *key = [self keyForWorkspaceName:name];
    [[NSUserDefaults standardUserDefaults] setObject:workspaceData forKey:key];
    [[NSUserDefaults standardUserDefaults] synchronize];

    NSLog(@"✅ WorkspaceManager: Workspace '%@' saved to key: %@", name, key);

    return YES;
}

- (NSDictionary *)serializeCurrentWorkspace {
    NSMutableArray *floatingWindowsData = [NSMutableArray array];
    NSMutableArray *gridWindowsData = [NSMutableArray array];
    
    // Serialize floating windows
    for (FloatingWidgetWindow *window in self.appDelegate.floatingWindows) {
        @autoreleasepool {
            NSDictionary *windowData = [self serializeFloatingWindow:window];
            if (windowData) {
                [floatingWindowsData addObject:windowData];
            }
        }
    }
    
    // Serialize grid windows
    for (GridWindow *window in self.appDelegate.gridWindows) {
        @autoreleasepool {
            NSDictionary *windowData = [window serializeState];
            if (windowData) {
                [gridWindowsData addObject:windowData];
            }
        }
    }
    
    return @{
        @"version": kWorkspaceVersion,
        @"timestamp": [NSDate date],
        @"floatingWindows": floatingWindowsData,
        @"gridWindows": gridWindowsData
    };
}

- (NSDictionary *)serializeFloatingWindow:(FloatingWidgetWindow *)window {
    if (!window.containedWidget) {
        return nil;
    }
    
    return @{
        @"widgetType": window.containedWidget.widgetType ?: @"Unknown",
        @"widgetClass": NSStringFromClass([window.containedWidget class]),
        @"frame": NSStringFromRect(window.frame),
        @"widgetState": [window.containedWidget serializeState] ?: @{}
    };
}

#pragma mark - Workspace Loading

- (BOOL)loadWorkspaceWithName:(NSString *)name {
    if (!name || name.length == 0) {
        NSLog(@"❌ WorkspaceManager: Invalid workspace name");
        return NO;
    }

    if (!self.appDelegate) {
        NSLog(@"❌ WorkspaceManager: AppDelegate not set");
        return NO;
    }

    NSLog(@"🔄 WorkspaceManager: Loading workspace '%@'", name);
    NSLog(@"   Current state: %ld floating + %ld grid windows",
          (long)self.appDelegate.floatingWindows.count,
          (long)self.appDelegate.gridWindows.count);

    // Load from UserDefaults
    NSString *key = [self keyForWorkspaceName:name];
    NSDictionary *workspaceData = [[NSUserDefaults standardUserDefaults] objectForKey:key];

    if (!workspaceData) {
        NSLog(@"❌ WorkspaceManager: Workspace '%@' not found", name);
        return NO;
    }

    NSLog(@"   Workspace data: %ld floating + %ld grid windows to restore",
          (long)[workspaceData[@"floatingWindows"] count],
          (long)[workspaceData[@"gridWindows"] count]);

    // ✅ FIX: Disable auto-save during workspace load
    self.isPerformingWorkspaceOperation = YES;
    NSLog(@"🔒 WorkspaceManager: Auto-save disabled during load operation");

    // Close all current windows
    [self closeAllWindows];

    // Restore workspace
    BOOL success = [self restoreWorkspace:workspaceData];

    // ✅ FIX: Re-enable auto-save after load completes
    self.isPerformingWorkspaceOperation = NO;
    NSLog(@"🔓 WorkspaceManager: Auto-save re-enabled");

    if (success) {
        NSLog(@"✅ WorkspaceManager: Workspace '%@' loaded successfully", name);
        NSLog(@"   Final state: %ld floating + %ld grid windows",
              (long)self.appDelegate.floatingWindows.count,
              (long)self.appDelegate.gridWindows.count);
    } else {
        NSLog(@"❌ WorkspaceManager: Failed to load workspace '%@'", name);
    }

    return success;
}

- (BOOL)restoreWorkspace:(NSDictionary *)workspaceData {
    // Verify version
    NSString *version = workspaceData[@"version"];
    if (![version isEqualToString:kWorkspaceVersion]) {
        NSLog(@"⚠️ WorkspaceManager: Workspace version mismatch (saved: %@, current: %@)",
              version, kWorkspaceVersion);
    }
    
    // Restore floating windows
    NSArray *floatingWindowsData = workspaceData[@"floatingWindows"];
    for (NSDictionary *windowData in floatingWindowsData) {
        @autoreleasepool {
            [self restoreFloatingWindow:windowData];
        }
    }
    
    // Restore grid windows
    NSArray *gridWindowsData = workspaceData[@"gridWindows"];
    for (NSDictionary *windowData in gridWindowsData) {
        @autoreleasepool {
            [self restoreGridWindow:windowData];
        }
    }
    
    NSLog(@"✅ WorkspaceManager: Restored %ld floating + %ld grid windows",
          (long)floatingWindowsData.count,
          (long)gridWindowsData.count);
    
    return YES;
}

- (void)restoreFloatingWindow:(NSDictionary *)windowData {
    NSString *widgetClassName = windowData[@"widgetClass"];
    NSString *widgetType = windowData[@"widgetType"];
    NSString *frameString = windowData[@"frame"];
    NSDictionary *widgetState = windowData[@"widgetState"];
    
    // Create widget
    Class widgetClass = NSClassFromString(widgetClassName);
    if (!widgetClass) {
        NSLog(@"⚠️ WorkspaceManager: Unknown widget class: %@", widgetClassName);
        return;
    }
    
    BaseWidget *widget = [[widgetClass alloc] initWithType:widgetType];
    [widget loadView];
    
    // Restore widget state
    if (widgetState) {
        [widget restoreState:widgetState];
    }
    
    // Create window
    NSSize windowSize = [self.appDelegate defaultSizeForWidgetType:widgetType];
    FloatingWidgetWindow *window = [self.appDelegate createFloatingWindowWithWidget:widget
                                                                              title:widgetType
                                                                               size:windowSize];
    
    // Restore frame
    if (frameString) {
        NSRect frame = NSRectFromString(frameString);
        if (!NSIsEmptyRect(frame)) {
            [window setFrame:frame display:NO];
        }
    }
    
    [window makeKeyAndOrderFront:nil];
    
    NSLog(@"✅ WorkspaceManager: Restored floating window: %@", widgetType);
}

- (void)restoreGridWindow:(NSDictionary *)windowData {
    NSString *gridName = windowData[@"gridName"];
    NSDictionary *templateDict = windowData[@"template"];  // ✅ FIX: Read template dict, not templateType
    NSString *frameString = windowData[@"frame"];

    // ✅ FIX: Deserialize GridTemplate object
    GridTemplate *template = [GridTemplate deserialize:templateDict];
    if (!template) {
        NSLog(@"❌ WorkspaceManager: Failed to deserialize grid template");
        return;
    }

    // Create grid window with deserialized template
    GridWindow *gridWindow = [self.appDelegate createGridWindowWithTemplate:template
                                                                        name:gridName];
    
    // Restore full state (includes widgets)
    [gridWindow restoreState:windowData];
    
    // Restore frame
    if (frameString) {
        NSRect frame = NSRectFromString(frameString);
        if (!NSIsEmptyRect(frame)) {
            [gridWindow setFrame:frame display:NO];
        }
    }
    
    [gridWindow makeKeyAndOrderFront:nil];
    
    NSLog(@"✅ WorkspaceManager: Restored grid window: %@", gridName);
}

#pragma mark - Window Management

- (void)closeAllWindows {
    NSLog(@"🗑️ WorkspaceManager: Closing all windows");
    
    // Close floating windows
    NSArray *floatingCopy = [self.appDelegate.floatingWindows copy];
    for (FloatingWidgetWindow *window in floatingCopy) {
        [window close];
    }
    
    // Close grid windows
    NSArray *gridCopy = [self.appDelegate.gridWindows copy];
    for (GridWindow *window in gridCopy) {
        [window close];
    }
    
    NSLog(@"✅ WorkspaceManager: All windows closed");
}

#pragma mark - Workspace Deletion

- (BOOL)deleteWorkspaceWithName:(NSString *)name {
    if (!name || name.length == 0) {
        return NO;
    }
    
    NSString *key = [self keyForWorkspaceName:name];
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:key];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    NSLog(@"🗑️ WorkspaceManager: Deleted workspace '%@'", name);
    return YES;
}

#pragma mark - Workspace Listing

- (NSArray<NSString *> *)availableWorkspaces {
    NSMutableArray *workspaces = [NSMutableArray array];
    
    NSDictionary *defaults = [[NSUserDefaults standardUserDefaults] dictionaryRepresentation];
    for (NSString *key in defaults.allKeys) {
        if ([key hasPrefix:kWorkspacePrefix]) {
            NSString *workspaceName = [key substringFromIndex:kWorkspacePrefix.length];
            [workspaces addObject:workspaceName];
        }
    }
    
    return [workspaces sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
}

- (BOOL)workspaceExistsWithName:(NSString *)name {
    NSString *key = [self keyForWorkspaceName:name];
    return [[NSUserDefaults standardUserDefaults] objectForKey:key] != nil;
}

#pragma mark - Auto-save/restore

- (void)saveLastUsedWorkspace {
    NSLog(@"💾 WorkspaceManager: Saving last used workspace");
    
    NSDictionary *workspaceData = [self serializeCurrentWorkspace];
    
    if (workspaceData) {
        [[NSUserDefaults standardUserDefaults] setObject:workspaceData forKey:kLastUsedWorkspaceKey];
        [[NSUserDefaults standardUserDefaults] synchronize];
        NSLog(@"✅ WorkspaceManager: Last used workspace saved");
    }
}

- (void)restoreLastUsedWorkspace {
    NSLog(@"🔄 WorkspaceManager: Restoring last used workspace");

    NSDictionary *workspaceData = [[NSUserDefaults standardUserDefaults] objectForKey:kLastUsedWorkspaceKey];

    if (workspaceData) {
        // ✅ FIX: Disable auto-save during workspace restore
        self.isPerformingWorkspaceOperation = YES;

        [self restoreWorkspace:workspaceData];

        // ✅ FIX: Re-enable auto-save after restore completes
        self.isPerformingWorkspaceOperation = NO;

        NSLog(@"✅ WorkspaceManager: Last used workspace restored");
    } else {
        NSLog(@"ℹ️ WorkspaceManager: No last used workspace found");
    }
}

#pragma mark - Export/Import

- (BOOL)exportWorkspace:(NSString *)name toURL:(NSURL *)fileURL {
    NSString *key = [self keyForWorkspaceName:name];
    NSDictionary *workspaceData = [[NSUserDefaults standardUserDefaults] objectForKey:key];
    
    if (!workspaceData) {
        NSLog(@"❌ WorkspaceManager: Workspace '%@' not found", name);
        return NO;
    }
    
    NSError *error = nil;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:workspaceData
                                                       options:NSJSONWritingPrettyPrinted
                                                         error:&error];
    
    if (error) {
        NSLog(@"❌ WorkspaceManager: Failed to serialize workspace: %@", error);
        return NO;
    }
    
    BOOL success = [jsonData writeToURL:fileURL atomically:YES];
    
    if (success) {
        NSLog(@"✅ WorkspaceManager: Workspace exported to %@", fileURL.path);
    }
    
    return success;
}

- (BOOL)importWorkspaceFromURL:(NSURL *)fileURL withName:(NSString *)name {
    NSError *error = nil;
    NSData *jsonData = [NSData dataWithContentsOfURL:fileURL options:0 error:&error];
    
    if (error) {
        NSLog(@"❌ WorkspaceManager: Failed to read file: %@", error);
        return NO;
    }
    
    NSDictionary *workspaceData = [NSJSONSerialization JSONObjectWithData:jsonData
                                                                  options:0
                                                                    error:&error];
    
    if (error) {
        NSLog(@"❌ WorkspaceManager: Failed to parse JSON: %@", error);
        return NO;
    }
    
    // Save to UserDefaults
    NSString *key = [self keyForWorkspaceName:name];
    [[NSUserDefaults standardUserDefaults] setObject:workspaceData forKey:key];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    NSLog(@"✅ WorkspaceManager: Workspace imported as '%@'", name);
    return YES;
}

#pragma mark - Helper Methods

- (NSString *)keyForWorkspaceName:(NSString *)name {
    return [kWorkspacePrefix stringByAppendingString:name];
}

#pragma mark - Auto-save

- (void)autoSaveLastUsedWorkspace {
    // ✅ FIX: Skip auto-save during workspace load/close operations
    if (self.isPerformingWorkspaceOperation) {
        NSLog(@"⏸️ WorkspaceManager: Auto-save skipped (workspace operation in progress)");
        return;
    }

    // Debounce: salva solo se è passato almeno 2 secondi dall'ultimo save
    if (self.lastAutoSaveTime && [[NSDate date] timeIntervalSinceDate:self.lastAutoSaveTime] < 2.0) {
        return; // Skip se troppo frequente
    }

    self.lastAutoSaveTime = [NSDate date];

    NSLog(@"⏰ WorkspaceManager: Auto-saving workspace...");

    // Salva in background per non bloccare UI
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        [self saveLastUsedWorkspace];
    });
}

@end
