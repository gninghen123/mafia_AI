#import "AppDelegate.h"
#import "DownloadManager.h"
#import "SchwabDataSource.h"
#import "WebullDataSource.h"
#import "OtherDataSource.h"
#import "DataHub.h"
#import "ClaudeDataSource.h"
#import "FloatingWidgetWindow.h"
#import "WidgetTypeManager.h"
#import "BaseWidget.h"

// Import specifici per ogni widget
#import "ChartWidget.h"
#import "AlertWidget.h"
#import "WatchlistWidget.h"
#import "ConnectionsWidget.h"
#import "SeasonalChartWidget.h"
#import "ConnectionStatusWidget.h"
#import "APIPlaygroundWidget.h"
#import "ibkrdatasource.h"
#import "ibkrconfiguration.h"
#import "yahooDataSource.h"
#import "StorageSystemInitializer.h"
#import "storagemanager.h"

#import "GridWindow.h"
#import "GridTemplate.h"
#import "WorkspaceManager.h"
#import "GridPresetManager.h"
#import "PreferencesWindowController.h"



@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    NSLog(@"AppDelegate: applicationDidFinishLaunching called");
    
    // Window restoration fixes
    [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"NSQuitAlwaysKeepsWindows"];
    [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"NSCloseAlwaysConfirmsChanges"];
    
    [DataHub shared];
    self.widgetTypeManager = [WidgetTypeManager sharedManager];
    // Initialize storage system
    [[StorageSystemInitializer sharedInitializer] initializeStorageSystemWithCompletion:^(BOOL success, NSError *error) {
        if (success) {
            NSLog(@"✅ Storage system initialized successfully at app startup");
        } else {
            NSLog(@"❌ Failed to initialize storage system: %@", error.localizedDescription);
        }
    }];
    
    [self registerDataSources];
    
    // Initialize window arrays
    self.floatingWindows = [[NSMutableArray alloc] init];
    self.gridWindows = [NSMutableArray array];
    
    // Setup WorkspaceManager
    [WorkspaceManager sharedManager].appDelegate = self;
    
    [NSApp activateIgnoringOtherApps:YES];
    
    // Auto-connect after delay
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self autoConnectToSchwab];
        [self autoConnectToIBKRWithPreferences];
    });
    
    [self setupClaudeDataSource];
    
    if (self.window) {
        self.window.restorationClass = [self class];
        self.window.identifier = @"MainWindow";
        NSLog(@"✅ AppDelegate: Main window configured with restoration ID");
    } else {
        NSLog(@"❌ AppDelegate: Main window outlet not connected!");
    }
    
    // ✅ Setup all menus programmatically
    [self setupAllMenus];

    // ✅ Listen for grid preset changes
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleGridPresetsDidChange:)
                                                 name:@"GridPresetsDidChange"
                                               object:nil];

    // ✅ Restore last used workspace
    [[WorkspaceManager sharedManager] restoreLastUsedWorkspace];
}

- (void)handleGridPresetsDidChange:(NSNotification *)notification {
    [self refreshGridPresetsMenu];
}

#pragma mark - Menu Setup

- (void)setupAllMenus {
    [self setupFileMenu];
    [self setupWindowMenu];
}

- (void)setupFileMenu {
    NSMenu *mainMenu = [NSApp mainMenu];
    NSMenuItem *fileMenuItem = [mainMenu itemWithTitle:@"File"];
    
    if (!fileMenuItem) {
        NSLog(@"⚠️ File menu not found - creating one");
        fileMenuItem = [[NSMenuItem alloc] initWithTitle:@"File" action:nil keyEquivalent:@""];
        NSMenu *fileMenu = [[NSMenu alloc] initWithTitle:@"File"];
        [fileMenuItem setSubmenu:fileMenu];
        [mainMenu insertItem:fileMenuItem atIndex:0];
    }
    
    NSMenu *fileMenu = [fileMenuItem submenu];
    NSInteger insertIndex = 0;
    
    // ✅ Save Workspace (Cmd+Shift+W)
    NSMenuItem *saveWorkspace = [[NSMenuItem alloc] initWithTitle:@"Save Workspace"
                                                           action:@selector(saveWorkspace:)
                                                    keyEquivalent:@"W"];
    saveWorkspace.keyEquivalentModifierMask = NSEventModifierFlagCommand | NSEventModifierFlagShift;
    saveWorkspace.target = self;
    [fileMenu insertItem:saveWorkspace atIndex:insertIndex++];
    
    // ✅ Save Workspace As...
    NSMenuItem *saveWorkspaceAs = [[NSMenuItem alloc] initWithTitle:@"Save Workspace As..."
                                                             action:@selector(saveWorkspaceAs:)
                                                      keyEquivalent:@""];
    saveWorkspaceAs.target = self;
    [fileMenu insertItem:saveWorkspaceAs atIndex:insertIndex++];
    
    // ✅ Load Workspace...
    NSMenuItem *loadWorkspace = [[NSMenuItem alloc] initWithTitle:@"Load Workspace..."
                                                           action:@selector(loadWorkspace:)
                                                    keyEquivalent:@""];
    loadWorkspace.target = self;
    [fileMenu insertItem:loadWorkspace atIndex:insertIndex++];

    // ✅ Delete Workspace...
    NSMenuItem *deleteWorkspace = [[NSMenuItem alloc] initWithTitle:@"Delete Workspace..."
                                                             action:@selector(deleteWorkspace:)
                                                      keyEquivalent:@""];
    deleteWorkspace.target = self;
    [fileMenu insertItem:deleteWorkspace atIndex:insertIndex++];

    // ✅ Clear Auto-Restore
    NSMenuItem *clearAutoRestore = [[NSMenuItem alloc] initWithTitle:@"Clear Auto-Restore"
                                                              action:@selector(clearAutoRestore:)
                                                       keyEquivalent:@""];
    clearAutoRestore.target = self;
    [fileMenu insertItem:clearAutoRestore atIndex:insertIndex++];

    // ✅ Separator
    [fileMenu insertItem:[NSMenuItem separatorItem] atIndex:insertIndex++];

    // ✅ Close All Windows
    NSMenuItem *closeAllWindows = [[NSMenuItem alloc] initWithTitle:@"Close All Windows"
                                                             action:@selector(closeAllWindows:)
                                                      keyEquivalent:@"W"];
    closeAllWindows.keyEquivalentModifierMask = NSEventModifierFlagCommand | NSEventModifierFlagOption;
    closeAllWindows.target = self;
    [fileMenu insertItem:closeAllWindows atIndex:insertIndex++];

    // ✅ Separator
    [fileMenu insertItem:[NSMenuItem separatorItem] atIndex:insertIndex++];

    // ✅ New Grid submenu - includes both built-in and custom presets
    NSMenuItem *newGridItem = [[NSMenuItem alloc] initWithTitle:@"New Grid"
                                                         action:nil
                                                  keyEquivalent:@""];
    NSMenu *gridSubmenu = [self buildGridPresetsMenu];
    [newGridItem setSubmenu:gridSubmenu];
    [fileMenu insertItem:newGridItem atIndex:insertIndex++];

    NSLog(@"✅ File menu setup complete (workspace + grid items added)");
}

- (NSMenu *)buildGridPresetsMenu {
    NSMenu *gridSubmenu = [[NSMenu alloc] initWithTitle:@"New Grid"];

    // ✅ BUILT-IN PRESETS
    NSArray *builtInPresets = @[
        @{@"name": @"Single (1×1)", @"rows": @1, @"cols": @1},
        @{@"name": @"List + Chart (1×2)", @"rows": @1, @"cols": @2},
        @{@"name": @"Triple Horizontal (1×3)", @"rows": @1, @"cols": @3},
        @{@"name": @"2×2 Grid", @"rows": @2, @"cols": @2},
        @{@"name": @"2×3 Grid", @"rows": @2, @"cols": @3},
        @{@"name": @"3×3 Grid", @"rows": @3, @"cols": @3}
    ];

    for (NSDictionary *preset in builtInPresets) {
        NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:preset[@"name"]
                                                      action:@selector(openGridPreset:)
                                               keyEquivalent:@""];
        item.target = self;
        item.representedObject = preset;
        [gridSubmenu addItem:item];
    }

    // ✅ CUSTOM PRESETS
    NSArray<NSDictionary *> *customPresets = [[GridPresetManager sharedManager] availablePresets];

    if (customPresets.count > 0) {
        [gridSubmenu addItem:[NSMenuItem separatorItem]];

        // Add section header
        NSMenuItem *headerItem = [[NSMenuItem alloc] initWithTitle:@"Custom Presets" action:nil keyEquivalent:@""];
        headerItem.enabled = NO;
        [gridSubmenu addItem:headerItem];

        for (NSDictionary *presetData in customPresets) {
            NSString *name = presetData[@"name"];
            GridTemplate *template = presetData[@"template"];

            NSString *title = [NSString stringWithFormat:@"%@ (%ldx%ld)",
                              name, (long)template.rows, (long)template.cols];

            NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:title
                                                          action:@selector(openCustomGridPreset:)
                                                   keyEquivalent:@""];
            item.target = self;
            item.representedObject = @{@"name": name, @"template": template};
            [gridSubmenu addItem:item];
        }

        // Add "Manage Presets..." option
        [gridSubmenu addItem:[NSMenuItem separatorItem]];
        NSMenuItem *manageItem = [[NSMenuItem alloc] initWithTitle:@"Manage Presets..."
                                                            action:@selector(manageGridPresets:)
                                                     keyEquivalent:@""];
        manageItem.target = self;
        [gridSubmenu addItem:manageItem];
    }

    return gridSubmenu;
}

- (void)refreshGridPresetsMenu {
    NSMenu *mainMenu = [NSApp mainMenu];
    NSMenuItem *fileMenuItem = [mainMenu itemWithTitle:@"File"];
    NSMenu *fileMenu = [fileMenuItem submenu];

    // Find "New Grid" menu item
    for (NSMenuItem *item in fileMenu.itemArray) {
        if ([item.title isEqualToString:@"New Grid"]) {
            NSMenu *newSubmenu = [self buildGridPresetsMenu];
            [item setSubmenu:newSubmenu];
            NSLog(@"🔄 AppDelegate: Grid presets menu refreshed");
            break;
        }
    }
}

#pragma mark - Preferences Actions

#pragma mark - Preferences Actions

- (IBAction)openPreferences:(id)sender {
    NSLog(@"⚙️ AppDelegate: Opening preferences window");
    
    // ✅ USA SINGLETON (non creare nuova istanza)
    PreferencesWindowController *prefs = [PreferencesWindowController sharedController];
    
    
    
    if (!prefs.window) {
        NSLog(@"❌ ERROR: Window is nil!");
        return;
    }
    
    [prefs.window makeKeyAndOrderFront:self];
    [NSApp activateIgnoringOtherApps:YES];
    
    NSLog(@"✅ AppDelegate: Preferences window opened");
}

- (void)setupWindowMenu {
    NSMenu *mainMenu = [NSApp mainMenu];
    NSMenuItem *windowMenuItem = [mainMenu itemWithTitle:@"Window"];
    
    if (!windowMenuItem) {
        NSLog(@"⚠️ Window menu not found - creating one");
        windowMenuItem = [[NSMenuItem alloc] initWithTitle:@"Window" action:nil keyEquivalent:@""];
        NSMenu *windowMenu = [[NSMenu alloc] initWithTitle:@"Window"];
        [windowMenuItem setSubmenu:windowMenu];
        [mainMenu addItem:windowMenuItem];
    }
    
    NSMenu *windowMenu = [windowMenuItem submenu];
    
    // Add separator
    if (windowMenu.numberOfItems > 0) {
        [windowMenu addItem:[NSMenuItem separatorItem]];
    }
    
    // ✅ Arrange Floating Windows (if not exists)
    NSMenuItem *arrangeFloating = [[NSMenuItem alloc] initWithTitle:@"Arrange Floating Windows"
                                                             action:@selector(arrangeFloatingWindows:)
                                                      keyEquivalent:@""];
    arrangeFloating.target = self;
    [windowMenu addItem:arrangeFloating];
    
    // ✅ Close All Floating Windows
    NSMenuItem *closeAllFloating = [[NSMenuItem alloc] initWithTitle:@"Close All Floating Windows"
                                                              action:@selector(closeAllFloatingWindows:)
                                                       keyEquivalent:@""];
    closeAllFloating.target = self;
    [windowMenu addItem:closeAllFloating];
    
    // ✅ Close All Grids
    NSMenuItem *closeAllGrids = [[NSMenuItem alloc] initWithTitle:@"Close All Grids"
                                                           action:@selector(closeAllGrids:)
                                                    keyEquivalent:@""];
    closeAllGrids.target = self;
    [windowMenu addItem:closeAllGrids];
    
    NSLog(@"✅ Window menu setup complete");
}

#pragma mark - Data Sources

- (void)registerDataSources {
    DownloadManager *downloadManager = [DownloadManager sharedManager];
       
    NSLog(@"📡 AppDelegate: Registering data sources with updated priority order...");
    
    // Priority 1 - Schwab
    SchwabDataSource *schwabSource = [[SchwabDataSource alloc] init];
    [downloadManager registerDataSource:schwabSource
                                withType:DataSourceTypeSchwab
                                priority:1];
    NSLog(@"📊 Registered Schwab - Priority 1");
    
    // Priority 2 - IBKR
    IBKRConfiguration *ibkrConfig = [IBKRConfiguration sharedConfiguration];
    IBKRDataSource *ibkrSource = [ibkrConfig createDataSource];
    [downloadManager registerDataSource:ibkrSource
                                withType:DataSourceTypeIBKR
                                priority:2];
    NSLog(@"📊 Registered IBKR - Priority 2");
    
    // Priority 3 - Yahoo
    YahooDataSource *yahooSource = [[YahooDataSource alloc] init];
    [downloadManager registerDataSource:yahooSource
                                withType:DataSourceTypeYahoo
                                priority:3];
    NSLog(@"📊 Registered Yahoo Finance - Priority 3");
    
    // Priority 50 - Webull
    WebullDataSource *webullSource = [[WebullDataSource alloc] init];
    [downloadManager registerDataSource:webullSource
                                withType:DataSourceTypeWebull
                                priority:50];
    NSLog(@"📊 Registered Webull - Priority 50");
    
    // Priority 100 - Other/CSV
    OtherDataSource *otherSource = [[OtherDataSource alloc] init];
    [downloadManager registerDataSource:otherSource
                                withType:DataSourceTypeOther
                                priority:100];
    NSLog(@"📊 Registered Other/CSV - Priority 100");
    
    // Priority 200 - Claude
    ClaudeDataSource *claudeSource = [ClaudeDataSource sharedInstance];
    [downloadManager registerDataSource:claudeSource
                                withType:DataSourceTypeClaude
                                priority:200];
    
    NSLog(@"AppDelegate: Registered all data sources");
    
    // Connect free sources
    [downloadManager connectDataSource:DataSourceTypeYahoo completion:nil];
    [downloadManager connectDataSource:DataSourceTypeWebull completion:nil];
    [downloadManager connectDataSource:DataSourceTypeOther completion:nil];
}

#pragma mark - Claude Setup

- (void)setupClaudeDataSource {
    NSLog(@"AppDelegate: Setting up Claude AI Data Source");
    
    NSString *claudeApiKey = [self loadClaudeAPIKey];
    
    if (!claudeApiKey || claudeApiKey.length == 0) {
        NSLog(@"AppDelegate: Claude API key not found - AI features disabled");
        return;
    }
    
    ClaudeDataSource *claudeSource = [[ClaudeDataSource alloc] initWithAPIKey:claudeApiKey];
    
    NSDictionary *claudeConfig = [self loadClaudeConfiguration];
    if (claudeConfig) {
        [claudeSource updateConfiguration:claudeConfig];
    }
    
    DownloadManager *downloadManager = [DownloadManager sharedManager];
    [downloadManager registerDataSource:claudeSource
                                withType:DataSourceTypeClaude
                                priority:1];
    
    [claudeSource connectWithCompletion:^(BOOL success, NSError *error) {
        if (success) {
            NSLog(@"AppDelegate: Claude AI connected successfully");
        } else {
            NSLog(@"AppDelegate: Claude AI connection failed: %@", error.localizedDescription);
        }
    }];
}

- (NSString *)loadClaudeAPIKey {
    NSString *envKey = [[[NSProcessInfo processInfo] environment] objectForKey:@"CLAUDE_API_KEY"];
    if (envKey && envKey.length > 0) return envKey;
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *settingsKey = [defaults stringForKey:@"ClaudeAPIKey"];
    if (settingsKey && settingsKey.length > 0) return settingsKey;
    
    NSString *configPath = [[NSBundle mainBundle] pathForResource:@"claude_config" ofType:@"plist"];
    if (configPath) {
        NSDictionary *config = [NSDictionary dictionaryWithContentsOfFile:configPath];
        NSString *configKey = config[@"apiKey"];
        if (configKey && configKey.length > 0) return configKey;
    }
    
    return nil;
}

- (NSDictionary *)loadClaudeConfiguration {
    NSMutableDictionary *config = [NSMutableDictionary dictionary];
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    NSString *baseURL = [defaults stringForKey:@"ClaudeBaseURL"];
    if (baseURL) config[@"baseURL"] = baseURL;
    
    NSString *model = [defaults stringForKey:@"ClaudeModel"];
    if (model) config[@"model"] = model;
    
    NSNumber *timeout = [defaults objectForKey:@"ClaudeTimeout"];
    if (timeout) config[@"timeout"] = timeout;
    
    NSString *configPath = [[NSBundle mainBundle] pathForResource:@"claude_config" ofType:@"plist"];
    if (configPath) {
        NSDictionary *fileConfig = [NSDictionary dictionaryWithContentsOfFile:configPath];
        [config addEntriesFromDictionary:fileConfig];
    }
    
    return config.count > 0 ? [config copy] : nil;
}

- (void)saveClaudeAPIKey:(NSString *)apiKey {
    if (!apiKey) return;
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:apiKey forKey:@"ClaudeAPIKey"];
    [defaults synchronize];
    
    NSLog(@"AppDelegate: Claude API key saved");
    [self setupClaudeDataSource];
}

#pragma mark - Auto-Connect

- (void)autoConnectToSchwabWithPreferences {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    BOOL autoConnectEnabled = [defaults boolForKey:@"AutoConnectSchwab"];
    
    if (!autoConnectEnabled) {
        NSLog(@"Auto-connect Schwab disabled by user");
        return;
    }
    
    [self autoConnectToSchwab];
}

- (void)autoConnectToSchwab {
    NSLog(@"AppDelegate: Attempting auto-connection to Schwab...");
    
    DownloadManager *downloadManager = [DownloadManager sharedManager];
    
    if ([downloadManager isDataSourceConnected:DataSourceTypeSchwab]) {
        NSLog(@"AppDelegate: Schwab already connected");
        return;
    }
    
    [downloadManager connectDataSource:DataSourceTypeSchwab
                            completion:^(BOOL success, NSError *error) {
        if (success) {
            NSLog(@"AppDelegate: Schwab auto-connection successful");
        } else {
            NSLog(@"AppDelegate: Schwab auto-connection failed: %@", error.localizedDescription);
        }
    }];
}

- (void)autoConnectToIBKRWithPreferences {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    BOOL autoConnectEnabled = [defaults boolForKey:@"AutoConnectIBKR"];
    
    if (!autoConnectEnabled) {
        NSLog(@"IBKR Auto-connect disabled by user");
        return;
    }
    
    [self autoConnectToIBKR];
}

- (void)autoConnectToIBKR {
    NSLog(@"AppDelegate: Attempting auto-connection to IBKR...");
    
    DownloadManager *downloadManager = [DownloadManager sharedManager];
    
    if ([downloadManager isDataSourceConnected:DataSourceTypeIBKR]) {
        NSLog(@"AppDelegate: IBKR already connected");
        return;
    }
    
    [downloadManager connectDataSource:DataSourceTypeIBKR completion:^(BOOL success, NSError *error) {
        if (success) {
            NSLog(@"AppDelegate: IBKR auto-connection successful");
        } else {
            NSLog(@"AppDelegate: IBKR auto-connection failed: %@", error.localizedDescription);
            [self scheduleIBKRRetry];
        }
    }];
}

- (void)scheduleIBKRRetry {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(30.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        BOOL autoRetryEnabled = [defaults boolForKey:@"AutoRetryIBKR"];
        
        if (autoRetryEnabled) {
            NSLog(@"AppDelegate: Retrying IBKR connection...");
            [self autoConnectToIBKR];
        }
    });
}

#pragma mark - Floating Widget Actions

- (IBAction)openFloatingWidget:(id)sender {
    NSMenuItem *menuItem = (NSMenuItem *)sender;
    NSString *widgetTitle = menuItem.title;
    
    NSLog(@"🚀 AppDelegate: Opening floating widget: %@", widgetTitle);
    
    BaseWidget *widget = [self createWidgetOfType:widgetTitle];
    if (!widget) {
        NSLog(@"❌ AppDelegate: Failed to create widget of type: %@", widgetTitle);
        return;
    }
    
    [widget loadView];
    
    if (widget.titleComboBox) {
        widget.titleComboBox.stringValue = widgetTitle;
    }
    
    NSSize windowSize = [self defaultSizeForWidgetType:widgetTitle];
    
    FloatingWidgetWindow *window = [self createFloatingWindowWithWidget:widget
                                                                   title:widgetTitle
                                                                    size:windowSize];
    [window makeKeyAndOrderFront:self];
    
    NSLog(@"✅ AppDelegate: Successfully opened floating %@ widget", widgetTitle);
}

#pragma mark - Grid Actions

#pragma mark - Grid Actions

- (IBAction)openGridPreset:(id)sender {
    NSMenuItem *menuItem = (NSMenuItem *)sender;
    NSDictionary *preset = menuItem.representedObject;
    
    NSInteger rows = [preset[@"rows"] integerValue];
    NSInteger cols = [preset[@"cols"] integerValue];
    NSString *name = preset[@"name"];
    
    NSLog(@"🏗️ AppDelegate: Opening grid preset: %@ (%ldx%ld)", name, (long)rows, (long)cols);
    
    GridTemplate *template = [GridTemplate templateWithRows:rows
                                                       cols:cols
                                                displayName:name];
    
    GridWindow *gridWindow = [[GridWindow alloc] initWithTemplate:template
                                                             name:name
                                                      appDelegate:self];
    
    [self.gridWindows addObject:gridWindow];
    [gridWindow makeKeyAndOrderFront:self];
    
    NSLog(@"✅ AppDelegate: Grid window opened (%ldx%ld)", (long)rows, (long)cols);
}

- (IBAction)openCustomGridPreset:(id)sender {
    NSMenuItem *menuItem = (NSMenuItem *)sender;
    NSDictionary *presetData = menuItem.representedObject;

    NSString *name = presetData[@"name"];
    GridTemplate *template = presetData[@"template"];

    NSLog(@"🏗️ AppDelegate: Opening custom grid preset: %@ (%ldx%ld)",
          name, (long)template.rows, (long)template.cols);

    GridWindow *gridWindow = [[GridWindow alloc] initWithTemplate:template
                                                             name:name
                                                      appDelegate:self];

    [self.gridWindows addObject:gridWindow];
    [gridWindow makeKeyAndOrderFront:self];

    NSLog(@"✅ AppDelegate: Custom grid window opened (%ldx%ld)",
          (long)template.rows, (long)template.cols);
}

- (IBAction)manageGridPresets:(id)sender {
    NSArray<NSString *> *presetNames = [[GridPresetManager sharedManager] availablePresetNames];

    if (presetNames.count == 0) {
        NSAlert *alert = [[NSAlert alloc] init];
        alert.messageText = @"No Custom Presets";
        alert.informativeText = @"You haven't saved any custom grid presets yet.\n\nTo create a preset:\n1. Open a grid window\n2. Adjust the layout and proportions\n3. Click the settings button (⚙️)\n4. Select \"Save as Preset...\"";
        [alert addButtonWithTitle:@"OK"];
        [alert runModal];
        return;
    }

    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"Manage Grid Presets";
    alert.informativeText = @"Select a preset to delete:";

    NSPopUpButton *popup = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(0, 0, 250, 24)
                                                      pullsDown:NO];
    [popup addItemsWithTitles:presetNames];

    alert.accessoryView = popup;

    [alert addButtonWithTitle:@"Delete"];
    [alert addButtonWithTitle:@"Cancel"];

    if ([alert runModal] == NSAlertFirstButtonReturn) {
        NSString *selectedPreset = [popup titleOfSelectedItem];

        if (selectedPreset) {
            // Confirm deletion
            NSAlert *confirmAlert = [[NSAlert alloc] init];
            confirmAlert.messageText = @"Confirm Deletion";
            confirmAlert.informativeText = [NSString stringWithFormat:@"Are you sure you want to delete the preset '%@'?\n\nThis action cannot be undone.", selectedPreset];
            [confirmAlert addButtonWithTitle:@"Delete"];
            [confirmAlert addButtonWithTitle:@"Cancel"];

            if ([confirmAlert runModal] == NSAlertFirstButtonReturn) {
                BOOL success = [[GridPresetManager sharedManager] deletePresetWithName:selectedPreset];

                if (success) {
                    // Refresh menu
                    [self refreshGridPresetsMenu];

                    NSAlert *successAlert = [[NSAlert alloc] init];
                    successAlert.messageText = @"Preset Deleted";
                    successAlert.informativeText = [NSString stringWithFormat:@"The preset '%@' has been deleted.", selectedPreset];
                    [successAlert addButtonWithTitle:@"OK"];
                    [successAlert runModal];

                    NSLog(@"✅ AppDelegate: Deleted preset '%@'", selectedPreset);
                } else {
                    NSAlert *errorAlert = [[NSAlert alloc] init];
                    errorAlert.messageText = @"Delete Failed";
                    errorAlert.informativeText = @"Failed to delete the preset. Please try again.";
                    [errorAlert addButtonWithTitle:@"OK"];
                    [errorAlert runModal];
                }
            }
        }
    }
}


#pragma mark - Workspace Actions

- (IBAction)saveWorkspace:(id)sender {
    [[WorkspaceManager sharedManager] saveCurrentWorkspaceWithName:@"Default"];
    
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"Workspace Saved";
    alert.informativeText = @"Current workspace saved as 'Default'";
    [alert addButtonWithTitle:@"OK"];
    [alert runModal];
}

- (IBAction)saveWorkspaceAs:(id)sender {
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"Save Workspace As";
    alert.informativeText = @"Enter a name for this workspace:";
    
    NSTextField *input = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 200, 24)];
    input.placeholderString = @"My Workspace";
    alert.accessoryView = input;
    
    [alert addButtonWithTitle:@"Save"];
    [alert addButtonWithTitle:@"Cancel"];
    
    if ([alert runModal] == NSAlertFirstButtonReturn) {
        NSString *name = input.stringValue;
        
        if (name.length > 0) {
            BOOL success = [[WorkspaceManager sharedManager] saveCurrentWorkspaceWithName:name];
            
            if (success) {
                NSAlert *successAlert = [[NSAlert alloc] init];
                successAlert.messageText = @"Workspace Saved";
                successAlert.informativeText = [NSString stringWithFormat:@"Workspace '%@' saved successfully", name];
                [successAlert addButtonWithTitle:@"OK"];
                [successAlert runModal];
            }
        }
    }
}

- (IBAction)loadWorkspace:(id)sender {
    NSArray *workspaces = [[WorkspaceManager sharedManager] availableWorkspaces];
    
    if (workspaces.count == 0) {
        NSAlert *alert = [[NSAlert alloc] init];
        alert.messageText = @"No Workspaces";
        alert.informativeText = @"No saved workspaces found. Save a workspace first.";
        [alert addButtonWithTitle:@"OK"];
        [alert runModal];
        return;
    }
    
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"Load Workspace";
    alert.informativeText = @"Select a workspace to load:";
    
    NSPopUpButton *popup = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(0, 0, 200, 24)];
    [popup addItemsWithTitles:workspaces];
    alert.accessoryView = popup;
    
    [alert addButtonWithTitle:@"Load"];
    [alert addButtonWithTitle:@"Cancel"];
    
    if ([alert runModal] == NSAlertFirstButtonReturn) {
        NSString *selectedWorkspace = [popup titleOfSelectedItem];
        [[WorkspaceManager sharedManager] loadWorkspaceWithName:selectedWorkspace];
    }
}

- (IBAction)deleteWorkspace:(id)sender {
    NSArray *workspaces = [[WorkspaceManager sharedManager] availableWorkspaces];

    if (workspaces.count == 0) {
        NSAlert *alert = [[NSAlert alloc] init];
        alert.messageText = @"No Workspaces";
        alert.informativeText = @"No saved workspaces found.";
        [alert addButtonWithTitle:@"OK"];
        [alert runModal];
        return;
    }

    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"Delete Workspace";
    alert.informativeText = @"Select a workspace to delete:";

    NSPopUpButton *popup = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(0, 0, 200, 24)
                                                      pullsDown:NO];
    [popup addItemsWithTitles:workspaces];
    alert.accessoryView = popup;

    [alert addButtonWithTitle:@"Delete"];
    [alert addButtonWithTitle:@"Cancel"];

    if ([alert runModal] == NSAlertFirstButtonReturn) {
        NSString *selectedWorkspace = [popup titleOfSelectedItem];

        if (selectedWorkspace) {
            // Confirm deletion
            NSAlert *confirmAlert = [[NSAlert alloc] init];
            confirmAlert.messageText = @"Confirm Deletion";
            confirmAlert.informativeText = [NSString stringWithFormat:@"Are you sure you want to delete the workspace '%@'?\n\nThis action cannot be undone.", selectedWorkspace];
            [confirmAlert addButtonWithTitle:@"Delete"];
            [confirmAlert addButtonWithTitle:@"Cancel"];

            if ([confirmAlert runModal] == NSAlertFirstButtonReturn) {
                BOOL success = [[WorkspaceManager sharedManager] deleteWorkspaceWithName:selectedWorkspace];

                if (success) {
                    NSAlert *successAlert = [[NSAlert alloc] init];
                    successAlert.messageText = @"Workspace Deleted";
                    successAlert.informativeText = [NSString stringWithFormat:@"The workspace '%@' has been deleted.", selectedWorkspace];
                    [successAlert addButtonWithTitle:@"OK"];
                    [successAlert runModal];

                    NSLog(@"✅ AppDelegate: Deleted workspace '%@'", selectedWorkspace);
                } else {
                    NSAlert *errorAlert = [[NSAlert alloc] init];
                    errorAlert.messageText = @"Delete Failed";
                    errorAlert.informativeText = @"Failed to delete the workspace. Please try again.";
                    [errorAlert addButtonWithTitle:@"OK"];
                    [errorAlert runModal];
                }
            }
        }
    }
}

- (IBAction)closeAllWindows:(id)sender {
    NSLog(@"🗑️ AppDelegate: Closing all windows (floating + grid)");

    // Close all floating windows
    NSArray *floatingCopy = [self.floatingWindows copy];
    for (FloatingWidgetWindow *window in floatingCopy) {
        [window close];
    }

    // Close all grid windows
    NSArray *gridCopy = [self.gridWindows copy];
    for (GridWindow *window in gridCopy) {
        [window close];
    }

    NSLog(@"✅ AppDelegate: All windows closed");
}

- (IBAction)clearAutoRestore:(id)sender {
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"Clear Auto-Restore";
    alert.informativeText = @"This will clear the last used workspace that gets restored when you launch the app.\n\nThe app will start with a clean slate next time.\n\nYour saved workspaces will NOT be affected.";
    [alert addButtonWithTitle:@"Clear"];
    [alert addButtonWithTitle:@"Cancel"];

    if ([alert runModal] == NSAlertFirstButtonReturn) {
        [[WorkspaceManager sharedManager] clearLastUsedWorkspace];

        NSAlert *successAlert = [[NSAlert alloc] init];
        successAlert.messageText = @"Auto-Restore Cleared";
        successAlert.informativeText = @"The app will start with no windows next time you launch it.";
        [successAlert addButtonWithTitle:@"OK"];
        [successAlert runModal];

        NSLog(@"✅ AppDelegate: Auto-restore cleared by user");
    }
}

#pragma mark - Widget Creation

- (BaseWidget *)createWidgetOfType:(NSString *)widgetType {
    Class widgetClass = [self.widgetTypeManager classForWidgetType:widgetType];
    
    if (!widgetClass) {
        NSLog(@"⚠️ AppDelegate: No class found for widget type: %@", widgetType);
        widgetClass = [BaseWidget class];
    }
    
    BaseWidget *widget = [[widgetClass alloc] initWithType:widgetType];
    
    NSLog(@"🔧 AppDelegate: Created widget: %@ -> %@", widgetType, NSStringFromClass(widgetClass));
    
    return widget;
}

- (NSSize)defaultSizeForWidgetType:(NSString *)widgetType {
    NSDictionary *widgetSizes = @{
        @"Chart": [NSValue valueWithSize:NSMakeSize(800, 600)],
        @"MultiChart": [NSValue valueWithSize:NSMakeSize(1000, 700)],
        @"Seasonal Chart": [NSValue valueWithSize:NSMakeSize(800, 500)],
        @"Tick Chart": [NSValue valueWithSize:NSMakeSize(700, 500)],
        @"Microscope Chart": [NSValue valueWithSize:NSMakeSize(800, 600)],
        @"Watchlist": [NSValue valueWithSize:NSMakeSize(400, 600)],
        @"Alerts": [NSValue valueWithSize:NSMakeSize(450, 500)],
        @"SymbolDatabase": [NSValue valueWithSize:NSMakeSize(500, 650)],
        @"Quote": [NSValue valueWithSize:NSMakeSize(350, 400)],
        @"Connection Status": [NSValue valueWithSize:NSMakeSize(300, 250)],
        @"Connections": [NSValue valueWithSize:NSMakeSize(600, 450)],
        @"API Playground": [NSValue valueWithSize:NSMakeSize(700, 500)]
    };
    
    NSValue *sizeValue = widgetSizes[widgetType];
    return sizeValue ? [sizeValue sizeValue] : NSMakeSize(500, 400);
}

#pragma mark - Window Management

- (FloatingWidgetWindow *)createFloatingWindowWithWidget:(BaseWidget *)widget
                                                   title:(NSString *)title
                                                    size:(NSSize)size {
    
    FloatingWidgetWindow *window = [[FloatingWidgetWindow alloc] initWithWidget:widget
                                                                           title:title
                                                                            size:size
                                                                     appDelegate:self];
    
    [self registerFloatingWindow:window];
    
    NSLog(@"🪟 AppDelegate: Created floating window: %@", title);
    return window;
}

- (void)registerFloatingWindow:(FloatingWidgetWindow *)window {
    if (window && ![self.floatingWindows containsObject:window]) {
        [self.floatingWindows addObject:window];
        [[WorkspaceManager sharedManager] autoSaveLastUsedWorkspace];

        NSLog(@"📝 AppDelegate: Registered floating window (total: %ld)",
              (long)self.floatingWindows.count);
    }
}

- (void)unregisterFloatingWindow:(FloatingWidgetWindow *)window {
    if (window && [self.floatingWindows containsObject:window]) {
        [self.floatingWindows removeObject:window];
        [[WorkspaceManager sharedManager] autoSaveLastUsedWorkspace];

        NSLog(@"🗑️ AppDelegate: Unregistered floating window (remaining: %ld)",
              (long)self.floatingWindows.count);
    }
}

- (GridWindow *)createGridWindowWithTemplate:(GridTemplate *)template
                                         name:(NSString *)name {
    GridWindow *window = [[GridWindow alloc] initWithTemplate:template
                                                          name:name
                                                   appDelegate:self];
    [self.gridWindows addObject:window];
    return window;
}

- (void)registerGridWindow:(GridWindow *)window {
    if (window && ![self.gridWindows containsObject:window]) {
        [self.gridWindows addObject:window];
        [[WorkspaceManager sharedManager] autoSaveLastUsedWorkspace];

        NSLog(@"📝 AppDelegate: Registered grid window (total: %ld)",
              (long)self.gridWindows.count);
    }
}

- (void)unregisterGridWindow:(GridWindow *)window {
    if (window && [self.gridWindows containsObject:window]) {
        [self.gridWindows removeObject:window];
        [[WorkspaceManager sharedManager] autoSaveLastUsedWorkspace];

        NSLog(@"🗑️ AppDelegate: Unregistered grid window (remaining: %ld)",
              (long)self.gridWindows.count);
    }
}

- (IBAction)arrangeFloatingWindows:(id)sender {
    if (self.floatingWindows.count == 0) return;
    
    NSScreen *mainScreen = [NSScreen mainScreen];
    NSRect screenFrame = mainScreen.visibleFrame;
    
    NSInteger windowCount = self.floatingWindows.count;
    NSInteger columns = (NSInteger)ceil(sqrt(windowCount));
    NSInteger rows = (NSInteger)ceil((double)windowCount / columns);
    
    CGFloat windowWidth = screenFrame.size.width / columns;
    CGFloat windowHeight = screenFrame.size.height / rows;
    
    for (NSInteger i = 0; i < windowCount; i++) {
        FloatingWidgetWindow *window = self.floatingWindows[i];
        
        NSInteger row = i / columns;
        NSInteger col = i % columns;
        
        NSRect newFrame = NSMakeRect(
            screenFrame.origin.x + (col * windowWidth),
            screenFrame.origin.y + screenFrame.size.height - ((row + 1) * windowHeight),
            windowWidth - 10,
            windowHeight - 10
        );
        
        [window setFrame:newFrame display:YES animate:YES];
    }
}

- (IBAction)closeAllFloatingWindows:(id)sender {
    NSArray *windowsCopy = [self.floatingWindows copy];
    for (FloatingWidgetWindow *window in windowsCopy) {
        [window close];
    }
}

- (IBAction)closeAllGrids:(id)sender {
    NSArray *windowsCopy = [self.gridWindows copy];
    for (GridWindow *window in windowsCopy) {
        [window close];
    }
}

#pragma mark - Microscope Window

- (FloatingWidgetWindow *)createMicroscopeWindowWithChartWidget:(ChartWidget *)chartWidget
                                                          title:(NSString *)title
                                                           size:(NSSize)size {
    
    if (!chartWidget) {
        NSLog(@"❌ AppDelegate: Cannot create microscope window - chartWidget is nil");
        return nil;
    }
    
    FloatingWidgetWindow *window = [[FloatingWidgetWindow alloc] initWithWidget:chartWidget
                                                                           title:title
                                                                            size:size
                                                                     appDelegate:self];
    
    [self registerFloatingWindow:window];
    
    NSLog(@"🔬 AppDelegate: Created microscope window: %@", title);
    return window;
}

#pragma mark - Application Lifecycle

- (BOOL)applicationSupportsSecureRestorableState:(NSApplication *)app {
    return NO;
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender {
    return YES;
}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
    [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"NSQuitAlwaysKeepsWindows"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    // Save floating window states
    for (FloatingWidgetWindow *window in self.floatingWindows) {
        [window saveWindowState];
    }
    
    // Save grid window states
    for (GridWindow *window in self.gridWindows) {
        NSDictionary *state = [window serializeState];
        NSString *key = [NSString stringWithFormat:@"GridWindow_%@", window.gridName];
        [[NSUserDefaults standardUserDefaults] setObject:state forKey:key];
    }
    
    // Auto-save last used workspace
    [[WorkspaceManager sharedManager] saveLastUsedWorkspace];
    
    NSLog(@"💾AppDelegate: Saved state for %ld floating + %ld grid windows",
          (long)self.floatingWindows.count,
          (long)self.gridWindows.count);
}

#pragma mark - Menu Validation

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem {
    if (menuItem.action == @selector(arrangeFloatingWindows:) ||
        menuItem.action == @selector(closeAllFloatingWindows:)) {
        return self.floatingWindows.count > 0;
    }
    
    if (menuItem.action == @selector(closeAllGrids:)) {
        return self.gridWindows.count > 0;
    }

    if (menuItem.action == @selector(closeAllWindows:)) {
        return (self.floatingWindows.count > 0 || self.gridWindows.count > 0);
    }

    if (menuItem.action == @selector(deleteWorkspace:)) {
        NSArray *workspaces = [[WorkspaceManager sharedManager] availableWorkspaces];
        return workspaces.count > 0;
    }

    if (menuItem.action == @selector(openFloatingWidget:) ||
        menuItem.action == @selector(openGrid:) ||
        menuItem.action == @selector(saveWorkspace:) ||
        menuItem.action == @selector(saveWorkspaceAs:) ||
        menuItem.action == @selector(loadWorkspace:)) {
        return YES;
    }

    return YES;
}

#pragma mark - Window Restoration

+ (void)restoreWindowWithIdentifier:(NSString *)identifier
                              state:(NSCoder *)state
                  completionHandler:(void (^)(NSWindow *, NSError *))completionHandler {
    
    NSLog(@"🔄 AppDelegate: Restoring window with identifier: %@", identifier);
    
    if ([identifier isEqualToString:@"MainWindow"]) {
        AppDelegate *appDelegate = (AppDelegate *)[NSApp delegate];
        if (appDelegate.window) {
            completionHandler(appDelegate.window, nil);
        } else {
            NSError *error = [NSError errorWithDomain:@"WindowRestoration"
                                                 code:404
                                             userInfo:@{NSLocalizedDescriptionKey: @"Main window not found"}];
            completionHandler(nil, error);
        }
    } else {
        NSError *error = [NSError errorWithDomain:@"WindowRestoration"
                                             code:404
                                         userInfo:@{NSLocalizedDescriptionKey: @"Unknown window identifier"}];
        completionHandler(nil, error);
    }
}

- (BOOL)application:(NSApplication *)application willContinueUserActivityWithType:(NSString *)userActivityType {
    return NO;
}

@end
