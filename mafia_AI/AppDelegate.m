#import "AppDelegate.h"
#import "DownloadManager.h"
#import "SchwabDataSource.h"
#import "WebullDataSource.h"
#import "OtherDataSource.h"      // NUOVO: Import per OtherDataSource
#import "DataHub.h"
#import "ClaudeDataSource.h"
#import "FloatingWidgetWindow.h"
#import "WidgetTypeManager.h"
#import "BaseWidget.h"

// Import specifici per ogni widget (solo quelli che esistono)
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
#import "StorageSystemInitializer.h"  // ← AGGIUNGI QUESTA RIGA
#import "storagemanager.h"

#import "GridWindow.h"  // ✅ NUOVO
#import "GridTemplate.h"  // ✅ NUOVO

@interface AppDelegate ()
@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
   // forza aggiornamento banca datio sotrage
    //[[StorageManager sharedManager] forceConsistencyCheck];

    
    self.gridWindows = [NSMutableArray array];  // ✅ NUOVO

    NSLog(@"AppDelegate: applicationDidFinishLaunching called");
    
    // ADD THESE LINES to fix window restoration crashes:
    [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"NSQuitAlwaysKeepsWindows"];
    [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"NSCloseAlwaysConfirmsChanges"];
    
    [DataHub shared];
    
    // 🎯 FIX: Inizializza il sistema di storage automatico
    [[StorageSystemInitializer sharedInitializer] initializeStorageSystemWithCompletion:^(BOOL success, NSError *error) {
        if (success) {
            NSLog(@"✅ Storage system initialized successfully at app startup");
        } else {
            NSLog(@"❌ Failed to initialize storage system: %@", error.localizedDescription);
        }
    }];
    [self registerDataSources];
    self.floatingWindows = [[NSMutableArray alloc] init];
    self.widgetTypeManager = [WidgetTypeManager sharedManager];
   
    
    [NSApp activateIgnoringOtherApps:YES];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self autoConnectToSchwab];
        [self autoConnectToIBKRWithPreferences];

    });
   // [self initializeSpotlightSearch];

    [self setupClaudeDataSource];
    if (self.window) {
        self.window.restorationClass = [self class];
        self.window.identifier = @"MainWindow";
        
        NSLog(@"✅ AppDelegate: Main window configured with restoration ID");
    } else {
        NSLog(@"❌ AppDelegate: Main window outlet not connected!");
    }
    [self setupGridMenus];

}

- (void)setupGridMenus {
    NSMenu *mainMenu = [NSApp mainMenu];
    
    // Find File menu
    NSMenuItem *fileMenuItem = [mainMenu itemWithTitle:@"File"];
    if (!fileMenuItem) {
        NSLog(@"⚠️ File menu not found");
        return;
    }
    
    NSMenu *fileMenu = [fileMenuItem submenu];
    
    // Create "New Grid" submenu
    NSMenuItem *newGridItem = [[NSMenuItem alloc] initWithTitle:@"New Grid"
                                                         action:nil
                                                  keyEquivalent:@""];
    
    NSMenu *gridSubmenu = [[NSMenu alloc] initWithTitle:@"New Grid"];
    
    // Add template options
    NSArray *templates = @[
        @"List + Chart",
        @"List + Dual Charts",
        @"Triple Horizontal",
        @"2x2 Grid"
    ];
    
    for (NSString *template in templates) {
        NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:template
                                                      action:@selector(openGrid:)
                                               keyEquivalent:@""];
        item.target = self;
        [gridSubmenu addItem:item];
    }
    
    [newGridItem setSubmenu:gridSubmenu];
    
    // Add to File menu (after "New Widget" if exists, or at index 1)
    NSInteger insertIndex = 1; // After "New"
    for (NSInteger i = 0; i < fileMenu.numberOfItems; i++) {
        NSMenuItem *item = [fileMenu itemAtIndex:i];
        if ([item.title isEqualToString:@"New Widget"]) {
            insertIndex = i + 1;
            break;
        }
    }
    
    [fileMenu insertItem:newGridItem atIndex:insertIndex];
    
    NSLog(@"✅ Grid menus setup complete");
    
    // Add Window menu items
    [self setupWindowMenuItems];
}

- (void)setupWindowMenuItems {
    NSMenu *mainMenu = [NSApp mainMenu];
    NSMenuItem *windowMenuItem = [mainMenu itemWithTitle:@"Window"];
    
    if (!windowMenuItem) {
        NSLog(@"⚠️ Window menu not found");
        return;
    }
    
    NSMenu *windowMenu = [windowMenuItem submenu];
    
    // Add separator if not already there
    if (windowMenu.numberOfItems > 0) {
        [windowMenu addItem:[NSMenuItem separatorItem]];
    }
    
    // Add "Close All Grids"
    NSMenuItem *closeAllGridsItem = [[NSMenuItem alloc] initWithTitle:@"Close All Grids"
                                                               action:@selector(closeAllGrids:)
                                                        keyEquivalent:@""];
    closeAllGridsItem.target = self;
    [windowMenu addItem:closeAllGridsItem];
    
    NSLog(@"✅ Window menu items setup complete");
}


- (void)registerDataSources {
    DownloadManager *downloadManager = [DownloadManager sharedManager];
       
       NSLog(@"📡 AppDelegate: Registering data sources with updated priority order...");
       
       // 🥇 Priority 1 - PREMIUM TIER (Schwab)
       SchwabDataSource *schwabSource = [[SchwabDataSource alloc] init];
       [downloadManager registerDataSource:schwabSource
                                   withType:DataSourceTypeSchwab
                                   priority:1];
       NSLog(@"📊 Registered Schwab - Priority 1 (Premium - Real-time data)");
       
       // 🥈 Priority 2 - PREMIUM TIER (IBKR)
       IBKRConfiguration *ibkrConfig = [IBKRConfiguration sharedConfiguration];
       IBKRDataSource *ibkrSource = [ibkrConfig createDataSource];
       [downloadManager registerDataSource:ibkrSource
                                   withType:DataSourceTypeIBKR
                                   priority:2];
       NSLog(@"📊 Registered IBKR - Priority 2 (Premium - Professional grade)");
       
       // 🥉 Priority 3 - FREE TIER HIGH QUALITY (Yahoo Finance) - NEW POSITION
       YahooDataSource *yahooSource = [[YahooDataSource alloc] init];
       [downloadManager registerDataSource:yahooSource
                                   withType:DataSourceTypeYahoo
                                   priority:3];
       NSLog(@"📊 Registered Yahoo Finance - Priority 3 (Free - JSON API, good quality)");
       
       // 🏃 Priority 50 - FREE TIER (Webull)
       WebullDataSource *webullSource = [[WebullDataSource alloc] init];
       [downloadManager registerDataSource:webullSource
                                   withType:DataSourceTypeWebull
                                   priority:50];
       NSLog(@"📊 Registered Webull - Priority 50 (Free - Delayed data)");
       
       // 📄 Priority 100 - FALLBACK (Other/CSV)
       OtherDataSource *otherSource = [[OtherDataSource alloc] init];
       [downloadManager registerDataSource:otherSource
                                   withType:DataSourceTypeOther
                                   priority:100];
       NSLog(@"📊 Registered Other/CSV - Priority 100 (Fallback - Basic CSV data)");
       
       // 🤖 Priority 200 - AI ONLY (Claude)
       ClaudeDataSource *claudeSource = [ClaudeDataSource sharedInstance];
       [downloadManager registerDataSource:claudeSource
                                   withType:DataSourceTypeClaude
                                   priority:200];
    
    NSLog(@"AppDelegate: Registered all data sources (Schwab, Webull, Other, Claude)");
    
    [downloadManager connectDataSource:DataSourceTypeYahoo completion:^(BOOL success, NSError *error) {
           if (success) {
               NSLog(@"✅ Yahoo Finance connected successfully");
           } else {
               NSLog(@"❌ Yahoo Finance connection failed: %@", error.localizedDescription);
           }
       }];
       
       // Connect Webull (no auth needed for market data)
       [downloadManager connectDataSource:DataSourceTypeWebull completion:^(BOOL success, NSError *error) {
           if (success) {
               NSLog(@"✅ Webull connected successfully");
           } else {
               NSLog(@"❌ Webull connection failed: %@", error.localizedDescription);
           }
       }];
       
       // Connect Other/CSV (always available)
       [downloadManager connectDataSource:DataSourceTypeOther completion:^(BOOL success, NSError *error) {
           if (success) {
               NSLog(@"✅ Other/CSV connected successfully");
           } else {
               NSLog(@"❌ Other/CSV connection failed: %@", error.localizedDescription);
           }
       }];
}



- (BOOL)applicationSupportsSecureRestorableState:(NSApplication *)app {
    return NO;
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender {
    return YES;
}
- (BOOL)application:(NSApplication *)application willContinueUserActivityWithType:(NSString *)userActivityType {
    return NO;
}

- (void)autoConnectToSchwabWithPreferences {
    // Controlla se l'utente ha abilitato la connessione automatica
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    BOOL autoConnectEnabled = [defaults boolForKey:@"AutoConnectSchwab"];
    
    if (!autoConnectEnabled) {
        NSLog(@"Auto-connect disabled by user");
        return;
    }
    
    [self autoConnectToSchwab];
}

- (void)autoConnectToSchwab {
    NSLog(@"AppDelegate: Attempting auto-connection to Schwab...");
    
    DownloadManager *downloadManager = [DownloadManager sharedManager];
    
    // Controlla se Schwab è già connesso
    if ([downloadManager isDataSourceConnected:DataSourceTypeSchwab]) {
        NSLog(@"AppDelegate: Schwab already connected");
        return;
    }
    
    // Prova a connettersi automaticamente
    [downloadManager connectDataSource:DataSourceTypeSchwab
                            completion:^(BOOL success, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (success) {
                NSLog(@"AppDelegate: Schwab auto-connection successful");
                
                // Opzionale: Mostra una notifica di successo
                //todo inserire preferenza per non mosrtare piu
               // [self showConnectionNotification:@"Connected to Schwab" success:YES];
            } else {
                NSLog(@"AppDelegate: Schwab auto-connection failed: %@", error.localizedDescription);
                
                // Opzionale: Mostra notifica di errore (solo per errori non di autenticazione)
                if (error.code != 401) { // Non mostrare errori di autenticazione
                    [self showConnectionNotification:@"Schwab connection failed" success:NO];
                }
            }
        });
    }];
}

// NUOVO METODO: Mostra notifiche di connessione (opzionale)
- (void)showConnectionNotification:(NSString *)message success:(BOOL)success {
    // Crea una notifica discreta nell'app
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = success ? @"Connection Successful" : @"Connection Failed";
    alert.informativeText = message;
    alert.alertStyle = success ? NSAlertStyleInformational : NSAlertStyleWarning;
    
   
}

#pragma mark - cluade api

- (void)setupClaudeDataSource {
    NSLog(@"AppDelegate: Setting up Claude AI Data Source");
    
    // Load API key from secure storage or settings
    NSString *claudeApiKey = [self loadClaudeAPIKey];
    
    if (!claudeApiKey || claudeApiKey.length == 0) {
        NSLog(@"AppDelegate: Claude API key not found - AI features will be disabled");
        NSLog(@"AppDelegate: Please configure Claude API key in app settings");
        return;
    }
    
    // Create and configure Claude data source
    ClaudeDataSource *claudeSource = [[ClaudeDataSource alloc] initWithAPIKey:claudeApiKey];
    
    // Optional: Update configuration from app settings
    NSDictionary *claudeConfig = [self loadClaudeConfiguration];
    if (claudeConfig) {
        [claudeSource updateConfiguration:claudeConfig];
    }
    
    // Register with DownloadManager
    DownloadManager *downloadManager = [DownloadManager sharedManager];
    [downloadManager registerDataSource:claudeSource
                                withType:DataSourceTypeClaude
                                priority:1]; // High priority for AI requests
    
    // Test connection
    [claudeSource connectWithCompletion:^(BOOL success, NSError *error) {
        if (success) {
            NSLog(@"AppDelegate: Claude AI connected successfully");
        } else {
            NSLog(@"AppDelegate: Claude AI connection failed: %@", error.localizedDescription);
        }
    }];
}

// NUOVO: Load API key from secure storage
- (NSString *)loadClaudeAPIKey {
    // In production, questo dovrebbe essere caricato dal Keychain o da un file di configurazione sicuro
    // Per ora, supportiamo alcune opzioni:
    
    // 1. Check environment variable (for development)
    NSString *envKey = [[[NSProcessInfo processInfo] environment] objectForKey:@"CLAUDE_API_KEY"];
    if (envKey && envKey.length > 0) {
        return envKey;
    }
    
    // 2. Check app settings/preferences
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *settingsKey = [defaults stringForKey:@"ClaudeAPIKey"];
    if (settingsKey && settingsKey.length > 0) {
        return settingsKey;
    }
    
    // 3. Check configuration file (claude_config.plist in app bundle)
    NSString *configPath = [[NSBundle mainBundle] pathForResource:@"claude_config" ofType:@"plist"];
    if (configPath) {
        NSDictionary *config = [NSDictionary dictionaryWithContentsOfFile:configPath];
        NSString *configKey = config[@"apiKey"];
        if (configKey && configKey.length > 0) {
            return configKey;
        }
    }
    
    // 4. TODO: Load from macOS Keychain (most secure option)
    // NSString *keychainKey = [self loadFromKeychain:@"ClaudeAPIKey"];
    
    return nil;
}

// NUOVO: Load Claude configuration
- (NSDictionary *)loadClaudeConfiguration {
    NSMutableDictionary *config = [NSMutableDictionary dictionary];
    
    // Load from app settings
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    NSString *baseURL = [defaults stringForKey:@"ClaudeBaseURL"];
    if (baseURL) config[@"baseURL"] = baseURL;
    
    NSString *model = [defaults stringForKey:@"ClaudeModel"];
    if (model) config[@"model"] = model;
    
    NSNumber *timeout = [defaults objectForKey:@"ClaudeTimeout"];
    if (timeout) config[@"timeout"] = timeout;
    
    // Load from config file if exists
    NSString *configPath = [[NSBundle mainBundle] pathForResource:@"claude_config" ofType:@"plist"];
    if (configPath) {
        NSDictionary *fileConfig = [NSDictionary dictionaryWithContentsOfFile:configPath];
        [config addEntriesFromDictionary:fileConfig];
    }
    
    return config.count > 0 ? [config copy] : nil;
}

// NUOVO: Utility method to save API key (for preferences window)
- (void)saveClaudeAPIKey:(NSString *)apiKey {
    if (!apiKey) return;
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:apiKey forKey:@"ClaudeAPIKey"];
    [defaults synchronize];
    
    NSLog(@"AppDelegate: Claude API key saved to preferences");
    
    // Restart Claude data source with new key
    [self setupClaudeDataSource];
}




#pragma mark - Window Restoration

+ (void)restoreWindowWithIdentifier:(NSString *)identifier
                              state:(NSCoder *)state
                  completionHandler:(void (^)(NSWindow *, NSError *))completionHandler {
    
    NSLog(@"🔄 AppDelegate: Restoring window with identifier: %@", identifier);
    
    if ([identifier isEqualToString:@"MainWindow"]) {
        // Ripristina la finestra principale
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
        // Identificatore sconosciuto
        NSError *error = [NSError errorWithDomain:@"WindowRestoration"
                                             code:404
                                         userInfo:@{NSLocalizedDescriptionKey: @"Unknown window identifier"}];
        completionHandler(nil, error);
    }
}
- (IBAction)openFloatingWidget:(id)sender {
   // 🎯 UNICA FUNZIONE che gestisce TUTTI i widget
   
   NSMenuItem *menuItem = (NSMenuItem *)sender;
   NSString *widgetTitle = menuItem.title;
   
   NSLog(@"🚀 AppDelegate: Opening floating widget: %@", widgetTitle);
   
   // Create widget using CORRECTED method
   BaseWidget *widget = [self createWidgetOfType:widgetTitle];
   if (!widget) {
       NSLog(@"❌ AppDelegate: Failed to create widget of type: %@", widgetTitle);
       return;
   }
   
   // ✅ CORRETTO: Usa loadView invece di setupWidget (che non esiste)
   [widget loadView];
   
   // ✅ CORRETTO: Configura il widget dopo loadView
   if (widget.titleComboBox) {
       widget.titleComboBox.stringValue = widgetTitle;
   }
   
   // Get default size for this widget type
   NSSize windowSize = [self defaultSizeForWidgetType:widgetTitle];
   
   // Create and show floating window
   FloatingWidgetWindow *window = [self createFloatingWindowWithWidget:widget
                                                                  title:widgetTitle
                                                                   size:windowSize];
   [window makeKeyAndOrderFront:self];
   
   NSLog(@"✅ AppDelegate: Successfully opened floating %@ widget", widgetTitle);
}
#pragma mark - Grid Actions

- (IBAction)openGrid:(id)sender {
    NSString *templateName = [sender title];
    NSLog(@"🏗️ AppDelegate: Opening grid with template: %@", templateName);
    
    // Map menu title to template type
    GridTemplateType templateType = [self templateTypeFromMenuTitle:templateName];
    
    // Create grid window
    GridWindow *gridWindow = [self createGridWindowWithTemplate:templateType
                                                           name:templateName];
    
    [gridWindow makeKeyAndOrderFront:self];
    
    NSLog(@"✅ AppDelegate: Grid window opened");
}

- (GridTemplateType)templateTypeFromMenuTitle:(NSString *)menuTitle {
    if ([menuTitle isEqualToString:@"List + Chart"]) {
        return GridTemplateTypeListChart;
    } else if ([menuTitle isEqualToString:@"List + Dual Charts"]) {
        return GridTemplateTypeListDualChart;
    } else if ([menuTitle isEqualToString:@"Triple Horizontal"]) {
        return GridTemplateTypeTripleHorizontal;
    } else if ([menuTitle isEqualToString:@"2x2 Grid"]) {
        return GridTemplateTypeQuad;
    }
    
    return GridTemplateTypeListChart; // Default
}

#pragma mark - Grid Window Management

- (GridWindow *)createGridWindowWithTemplate:(NSString *)templateType
                                        name:(NSString *)name {
    
    GridWindow *window = [[GridWindow alloc] initWithTemplate:templateType
                                                         name:name
                                                  appDelegate:self];
    
    [self registerGridWindow:window];
    
    NSLog(@"🏗️ AppDelegate: Created grid window: %@", name);
    return window;
}

- (void)registerGridWindow:(GridWindow *)window {
    if (window && ![self.gridWindows containsObject:window]) {
        [self.gridWindows addObject:window];
        NSLog(@"📝 AppDelegate: Registered grid window (total: %ld)",
              (long)self.gridWindows.count);
    }
}

- (void)unregisterGridWindow:(GridWindow *)window {
    if (window && [self.gridWindows containsObject:window]) {
        [self.gridWindows removeObject:window];
        NSLog(@"🗑️ AppDelegate: Unregistered grid window (remaining: %ld)",
              (long)self.gridWindows.count);
    }
}

- (IBAction)closeAllGrids:(id)sender {
    NSLog(@"🗑️ AppDelegate: Closing all grid windows");
    
    NSArray *windowsCopy = [self.gridWindows copy];
    
    for (GridWindow *window in windowsCopy) {
        [window close];
    }
    
    NSLog(@"✅ AppDelegate: Closed %ld grid windows", (long)windowsCopy.count);
}

#pragma mark - Widget Creation Helper

- (BaseWidget *)createWidgetOfType:(NSString *)widgetType {
   // Use WidgetTypeManager to get the correct class
   Class widgetClass = [self.widgetTypeManager classForWidgetType:widgetType];
   
   if (!widgetClass) {
       NSLog(@"⚠️ AppDelegate: No class found for widget type: %@, using BaseWidget", widgetType);
       widgetClass = [BaseWidget class];
   }
   
   // ✅ CORRETTO: Usa il metodo di inizializzazione corretto di BaseWidget
   BaseWidget *widget = [[widgetClass alloc] initWithType:widgetType];
   
   NSLog(@"🔧 AppDelegate: Created widget: %@ -> %@", widgetType, NSStringFromClass(widgetClass));
   
   return widget;
}

- (NSSize)defaultSizeForWidgetType:(NSString *)widgetType {
   // Define default sizes for different widget types
   NSDictionary *widgetSizes = @{
       // Chart widgets - need more space
       @"Chart Widget": [NSValue valueWithSize:NSMakeSize(800, 600)],
       @"MultiChart Widget": [NSValue valueWithSize:NSMakeSize(1000, 700)],
       @"Seasonal Chart": [NSValue valueWithSize:NSMakeSize(800, 500)],
       @"Tick Chart": [NSValue valueWithSize:NSMakeSize(700, 500)],
       
       // NUOVO: Dimensioni specifiche per finestre microscopio
       @"Microscope Chart": [NSValue valueWithSize:NSMakeSize(800, 600)],
       
       // List-based widgets - vertical orientation
       @"Watchlist": [NSValue valueWithSize:NSMakeSize(400, 600)],
       @"Alerts": [NSValue valueWithSize:NSMakeSize(450, 500)],
       @"SymbolDatabase": [NSValue valueWithSize:NSMakeSize(500, 650)],
       
       // Information widgets - compact
       @"Quote": [NSValue valueWithSize:NSMakeSize(350, 400)],
       @"Connection Status": [NSValue valueWithSize:NSMakeSize(300, 250)],
       @"Connections": [NSValue valueWithSize:NSMakeSize(600, 450)],
       
       // Utility widgets
       @"API Playground": [NSValue valueWithSize:NSMakeSize(700, 500)]
   };
   
   NSValue *sizeValue = widgetSizes[widgetType];
   if (sizeValue) {
       return [sizeValue sizeValue];
   }
   
   // Default size for unknown widget types
   return NSMakeSize(500, 400);
}

#pragma mark - Window Management Actions

- (IBAction)arrangeFloatingWindows:(id)sender {
   NSLog(@"🎯 AppDelegate: Arranging floating windows");
   
   if (self.floatingWindows.count == 0) {
       NSLog(@"ℹ️ AppDelegate: No floating windows to arrange");
       return;
   }
   
   // Get screen bounds
   NSScreen *mainScreen = [NSScreen mainScreen];
   NSRect screenFrame = mainScreen.visibleFrame;
   
   // Calculate grid arrangement
   NSInteger windowCount = self.floatingWindows.count;
   NSInteger columns = (NSInteger)ceil(sqrt(windowCount));
   NSInteger rows = (NSInteger)ceil((double)windowCount / columns);
   
   CGFloat windowWidth = screenFrame.size.width / columns;
   CGFloat windowHeight = screenFrame.size.height / rows;
   
   // Arrange windows in grid
   for (NSInteger i = 0; i < windowCount; i++) {
       FloatingWidgetWindow *window = self.floatingWindows[i];
       
       NSInteger row = i / columns;
       NSInteger col = i % columns;
       
       NSRect newFrame = NSMakeRect(
           screenFrame.origin.x + (col * windowWidth),
           screenFrame.origin.y + screenFrame.size.height - ((row + 1) * windowHeight),
           windowWidth - 10, // Small margin
           windowHeight - 10
       );
       
       [window setFrame:newFrame display:YES animate:YES];
   }
   
   NSLog(@"✅ AppDelegate: Arranged %ld windows in %ldx%ld grid",
         (long)windowCount, (long)columns, (long)rows);
}

- (IBAction)closeAllFloatingWindows:(id)sender {
   NSLog(@"🗑️ AppDelegate: Closing all floating windows");
   
   // Create copy to avoid mutation during enumeration
   NSArray *windowsCopy = [self.floatingWindows copy];
   
   for (FloatingWidgetWindow *window in windowsCopy) {
       [window close];
   }
   
   NSLog(@"✅ AppDelegate: Closed %ld floating windows", (long)windowsCopy.count);
}

#pragma mark - Floating Window Management

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
       NSLog(@"📝 AppDelegate: Registered floating window (total: %ld)",
             (long)self.floatingWindows.count);
   }
}

- (void)unregisterFloatingWindow:(FloatingWidgetWindow *)window {
   if (window && [self.floatingWindows containsObject:window]) {
       [self.floatingWindows removeObject:window];
       NSLog(@"🗑️ AppDelegate: Unregistered floating window (remaining: %ld)",
             (long)self.floatingWindows.count);
   }
}
#pragma mark - Application Delegate Extensions

- (void)applicationWillTerminate:(NSNotification *)aNotification {
    [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"NSQuitAlwaysKeepsWindows"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    // Save all floating window states before terminating
    for (FloatingWidgetWindow *window in self.floatingWindows) {
        [window saveWindowState];
    }
    for (GridWindow *window in self.gridWindows) {
            NSDictionary *state = [window serializeState];
            NSString *key = [NSString stringWithFormat:@"GridWindow_%@", window.gridName];
            [[NSUserDefaults standardUserDefaults] setObject:state forKey:key];
        }    NSLog(@"💾 AppDelegate: Saved state for %ld floating windows",
          (long)self.floatingWindows.count);
}

#pragma mark - Menu Validation

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem {
    if (menuItem.action == @selector(arrangeFloatingWindows:) ||
        menuItem.action == @selector(closeAllFloatingWindows:)) {
        return self.floatingWindows.count > 0;
    }
    for (GridWindow *window in self.gridWindows) {
            NSDictionary *state = [window serializeState];
            NSString *key = [NSString stringWithFormat:@"GridWindow_%@", window.gridName];
            [[NSUserDefaults standardUserDefaults] setObject:state forKey:key];
        }
    
    if (menuItem.action == @selector(openFloatingWidget:) ||
            menuItem.action == @selector(openGrid:)) {
            return YES;
        }
        
    
    return YES;
}


#pragma mark - Microscope Window Management

- (FloatingWidgetWindow *)createMicroscopeWindowWithChartWidget:(ChartWidget *)chartWidget
                                                          title:(NSString *)title
                                                           size:(NSSize)size {
    
    if (!chartWidget) {
        NSLog(@"❌ AppDelegate: Cannot create microscope window - chartWidget is nil");
        return nil;
    }
    
    NSLog(@"🔬 AppDelegate: Creating microscope window: %@", title);
    
    // Crea la floating window utilizzando l'infrastruttura esistente
    FloatingWidgetWindow *window = [[FloatingWidgetWindow alloc] initWithWidget:chartWidget
                                                                           title:title
                                                                            size:size
                                                                     appDelegate:self];
    
    // Registra la finestra nell'array delle floating windows
    [self registerFloatingWindow:window];
    
    NSLog(@"✅ AppDelegate: Created microscope window: %@ (total floating windows: %ld)",
          title, (long)self.floatingWindows.count);
    
    return window;
}

#pragma mark - ibkr

- (void)autoConnectToIBKRWithPreferences {
    // Controlla se l'utente ha abilitato la connessione automatica a IBKR
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
    
    // Controlla se IBKR è già connesso
    if ([downloadManager isDataSourceConnected:DataSourceTypeIBKR]) {
        NSLog(@"AppDelegate: IBKR already connected");
        return;
    }
    
    // Tenta connessione automatica
    [downloadManager connectDataSource:DataSourceTypeIBKR completion:^(BOOL success, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (success) {
                NSLog(@"AppDelegate: IBKR auto-connection successful");
                [self showIBKRConnectionAlert:YES message:@"Successfully connected to Interactive Brokers TWS/Gateway"];
            } else {
                NSLog(@"AppDelegate: IBKR auto-connection failed: %@", error.localizedDescription);
                
                // Non mostrare errore per connessioni automatiche fallite
                // L'utente può comunque connettersi manualmente se necessario
                
                // Optional: Schedule retry after a delay
                [self scheduleIBKRRetry];
            }
        });
    }];
}

- (void)scheduleIBKRRetry {
    // Retry connection after 30 seconds if TWS/Gateway might be starting up
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(30.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        BOOL autoRetryEnabled = [defaults boolForKey:@"AutoRetryIBKR"];
        
        if (autoRetryEnabled) {
            NSLog(@"AppDelegate: Retrying IBKR connection...");
            [self autoConnectToIBKR];
        }
    });
}

- (void)showIBKRConnectionAlert:(BOOL)success message:(NSString *)message {
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = success ? @"IBKR Connection Successful" : @"IBKR Connection Failed";
    alert.informativeText = message;
    alert.alertStyle = success ? NSAlertStyleInformational : NSAlertStyleWarning;
    
    // Add action button for failed connections
    if (!success) {
        [alert addButtonWithTitle:@"Retry"];
        [alert addButtonWithTitle:@"Cancel"];
    } else {
        [alert addButtonWithTitle:@"OK"];
    }
    
  
        // Fallback to modal if no main window
        [alert runModal];
}

// Optional: Method to test IBKR connection manually
- (void)testIBKRConnection {
    DownloadManager *downloadManager = [DownloadManager sharedManager];
    
    [downloadManager connectDataSource:DataSourceTypeIBKR completion:^(BOOL success, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            NSString *message;
            if (success) {
                message = @"Interactive Brokers connection test successful.\nTWS/Gateway is running and accessible.";
            } else {
                message = [NSString stringWithFormat:@"Interactive Brokers connection test failed.\n\nError: %@\n\nPlease ensure:\n• TWS or IB Gateway is running\n• API connections are enabled\n• Correct host/port configuration", error.localizedDescription];
            }
            
            [self showIBKRConnectionAlert:success message:message];
        });
    }];
}
@end
