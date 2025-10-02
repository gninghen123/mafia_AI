//
//  ChartWidget.m
//  TradingApp
//
//  Chart widget with XIB-based UI architecture
//

#import "ChartWidget.h"
#import "DataHub+MarketData.h"
#import "RuntimeModels.h"
#import "ChartPanelView.h"
#import "ChartWidget+ObjectsUI.h"
#import "ChartObjectModels.h"
#import "ChartObjectManagerWindow.h"
#import "ChartWidget+SaveData.h"
#import "Quartz/Quartz.h"
#import "SharedXCoordinateContext.h"
#import "ChartWidget+ImageExport.h"
#import "chartpatternmanager.h"
#import "ChartWidget+IndicatorsUI.h"
#import "DataHub+ChartTemplates.h"
#import "ChartWidget+InteractionHandlers.h"  
#import "ChartWidget+UnifiedSearch.h"

#pragma mark - Smart Symbol Input Parameters

// Constants
static NSString *const kWidgetChainUpdateNotification = @"WidgetChainUpdateNotification";
static NSString *const kChainUpdateKey = @"update";
static NSString *const kChainSenderKey = @"sender";

extern NSString *const DataHubDataLoadedNotification;

@interface ChartWidget ()

// Internal data
@property (nonatomic, strong) NSArray<HistoricalBarModel *> *chartData;

// Interaction state
@property (nonatomic, assign) BOOL isInChartPortionSelectionMode;
@property (nonatomic, assign) NSPoint dragStartPoint;

// Placeholder components (created programmatically)
@property (strong) NSView *placeholderView;
@property (strong) NSTextField *placeholderLabel;

@end

@implementation ChartWidget

#pragma mark - Initialization

- (instancetype)initWithType:(NSString *)type panelType:(PanelType)panelType {
    self = [super initWithType:type panelType:panelType];
    if (self) {
        [self setupChartDefaults];
        [self registerForDataNotifications];
    }
    return self;
}


- (void)loadView {
    NSLog(@"🔧 ChartWidget: Loading XIB...");
    
    // Load ChartWidget.xib
    NSArray *topLevelObjects = nil;
    BOOL xibLoaded = [[NSBundle mainBundle] loadNibNamed:@"ChartWidget"
                                                   owner:self
                                         topLevelObjects:&topLevelObjects];
    
    if (!xibLoaded || !topLevelObjects) {
        NSLog(@"❌ ChartWidget: Failed to load ChartWidget.xib");
        @throw [NSException exceptionWithName:@"XIBLoadException"
                                       reason:@"ChartWidget.xib could not be loaded"
                                     userInfo:nil];
    }
    
    // Find the main view from XIB
    NSView *mainView = nil;
    for (id object in topLevelObjects) {
        if ([object isKindOfClass:[NSView class]]) {
            mainView = (NSView *)object;
            break;
        }
    }
    
    if (!mainView) {
        NSLog(@"❌ ChartWidget: No NSView found in XIB");
        @throw [NSException exceptionWithName:@"XIBLoadException"
                                       reason:@"No NSView found in ChartWidget.xib"
                                     userInfo:nil];
    }
    
    // Set the XIB view as our main view
    self.view = mainView;
    
    // Configure view properties
    self.view.wantsLayer = YES;
    
    // Set minimum size constraints for chart widget
   [self.view.widthAnchor constraintGreaterThanOrEqualToConstant:1800].active = YES;
   [self.view.heightAnchor constraintGreaterThanOrEqualToConstant:1400].active = YES;
    
    NSLog(@"✅ ChartWidget: XIB loaded successfully");
    NSLog(@"   - View frame: %@", NSStringFromRect(self.view.frame));
    
    // Verify outlets and setup
 // [self setupAfterXIBLoad];
}

- (void)setupAfterXIBLoad {
    NSLog(@"🔧 ChartWidget: Setting up after XIB load...");
    
    // Configure XIB controls
   // [self configureXIBControls];
    
    // Initialize chart components
   // [self initializeChartComponents];
    
    // Setup data handling
    [self setupChartDefaults];
    [self registerForDataNotifications];
    
    // Load saved preferences
    [self loadDateRangeDefaults];
    [self loadDateRangeSegmentedDefaults];
    
    NSLog(@"✅ ChartWidget: Setup completed");
}
#pragma mark - XIB Loading and Setup

- (void)awakeFromNib {
    [super awakeFromNib];
    
    NSLog(@"🚀 Starting ChartWidget setup...");
    
    // ✅ Setup UI controls
    [self setupPlaceholderView];
    
    // ✅ Load preferences
    [self loadInitialPreferences];
    
    [self setupObjectsAndIndicatorsUI];

    [self setupUnifiedSearchField];

    // ✅ Setup template system (SEMPLIFICATO)
    [self loadAndApplyLastUsedTemplate];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(chartViewFrameDidChange:)
                                                 name:NSViewFrameDidChangeNotification
                                               object:self.view];

    // ✅ Enable frame change notifications
    self.view.postsFrameChangedNotifications = YES;
    NSLog(@"✅ ChartWidget setup completed");
}

- (void)setupUnifiedSearchField {
    if (!self.symbolTextField) {
        NSLog(@"⚠️ symbolTextField is nil - check IBOutlet connection");
        return;
    }
    
    self.symbolTextField.completes = YES;    // Setup initial appearance based on current static mode
    [self updateSearchFieldForMode];
    
    NSLog(@"✅ Unified search field setup completed");
}

- (void)updateSearchFieldForMode {
    if (!self.symbolTextField) return;
    
    if (self.isStaticMode) {
        // 🔵 STATIC MODE: Search saved data
        self.symbolTextField.placeholderString = @"Search saved data...";
        
        // Style as search field
        self.symbolTextField.wantsLayer = YES;
        self.symbolTextField.layer.cornerRadius = 12.0;
        self.symbolTextField.layer.borderColor = [NSColor systemBlueColor].CGColor;
        self.symbolTextField.layer.borderWidth = 1.5;
        
        NSLog(@"🔍 Search field configured for static mode (saved data search)");
        
    } else {
        // 🔴 NORMAL MODE: Live symbol search + smart entry
        self.symbolTextField.placeholderString = @"Symbol or search...";
        
        // Style as normal field with search capability
        self.symbolTextField.layer.cornerRadius = 6.0;
        self.symbolTextField.layer.borderColor = [NSColor controlAccentColor].CGColor;
        self.symbolTextField.layer.borderWidth = 1.0;
        
        NSLog(@"📈 Search field configured for normal mode (live symbols + smart entry)");
    }
}

/**
 * Loads initial preferences from UserDefaults.
 * Idempotent - safe to call multiple times.
 */
- (void)loadInitialPreferences {
    NSLog(@"📝 Loading initial preferences...");
    
    // Date range defaults
    [self loadDateRangeSegmentedDefaults];
    [self updateDateRangeSegmentedForTimeframe:self.currentTimeframe];
    
    // Objects manager
    if (!self.objectsManager) {
        self.objectsManager = [ChartObjectsManager managerForSymbol:self.currentSymbol];
    }
    
    // Chart defaults
    [self setupChartDefaults];
    
    NSLog(@"✅ Initial preferences loaded");
}

/**
 * Setup coordinato dei pannelli UI per oggetti e indicatori.
 * Questo metodo era mancante dopo il refactoring e causava la mancata
 * inizializzazione dei pannelli laterali con i toggle buttons.
 */
- (void)setupObjectsAndIndicatorsUI {
    
   
    [self createObjectsPanel];
    
    [self setupIndicatorsUI];
    
    
   
}


- (void)loadAndApplyLastUsedTemplate {
    NSLog(@"🎨 Loading and applying last used template...");
    
    // ✅ Check se IndicatorsUI extension è disponibile
    if (![self respondsToSelector:@selector(loadAvailableTemplates:)]) {
        NSLog(@"⚠️ ChartWidget+IndicatorsUI not loaded, using emergency fallback");
        [self createEmergencyFallbackPanels];
        return;
    }
    
    // ✅ SENZA CAST - lascia che il compilatore risolva automaticamente
    [self loadAvailableTemplates:^(BOOL success) {
        if (success && self.availableTemplates.count > 0) {
            ChartTemplateModel *templateToApply = [self determineTemplateToApply];
            
            if (templateToApply) {
                NSLog(@"🎯 Applying template: %@", templateToApply.templateName);
                
                // ✅ SENZA CAST anche qui
                [self applyTemplate:templateToApply];
                
                // ✅ Save as last used
                [self saveLastUsedTemplate:templateToApply];
            } else {
                NSLog(@"❌ No valid template found, using emergency fallback");
                [self createEmergencyFallbackPanels];
            }
        } else {
            NSLog(@"❌ Failed to load templates, using emergency fallback");
            [self createEmergencyFallbackPanels];
        }
    }];
}

- (NSString *)getLastUsedTemplateFromUserDefaults {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *lastUsedID = [defaults stringForKey:@"ChartWidget_LastUsedTemplateID"];
    
    if (lastUsedID) {
        NSLog(@"📋 Found last used template ID: %@", lastUsedID);
    } else {
        NSLog(@"📋 No last used template found (first time?)");
    }
    
    return lastUsedID;
}

- (void)saveLastUsedTemplate:(ChartTemplateModel *)template {
    if (template && template.templateID) {
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        [defaults setObject:template.templateID forKey:@"ChartWidget_LastUsedTemplateID"];
        [defaults synchronize];
        
        NSLog(@"💾 Saved last used template: %@ (ID: %@)", template.templateName, template.templateID);
    }
}

- (ChartTemplateModel *)findTemplateByID:(NSString *)templateID {
    for (ChartTemplateModel *template in self.availableTemplates) {
        if ([template.templateID isEqualToString:templateID]) {
            return template;
        }
    }
    return nil;
}

- (ChartTemplateModel *)determineTemplateToApply {
    // ✅ STEP 1: Cerca last used da UserDefaults
    NSString *lastUsedTemplateID = [self getLastUsedTemplateFromUserDefaults];
    
    if (lastUsedTemplateID) {
        // ✅ STEP 2: Cerca template per ID
        ChartTemplateModel *lastUsedTemplate = [self findTemplateByID:lastUsedTemplateID];
        if (lastUsedTemplate) {
            NSLog(@"♻️ Using last used template: %@", lastUsedTemplate.templateName);
            return lastUsedTemplate;
        } else {
            NSLog(@"⚠️ Last used template '%@' not found", lastUsedTemplateID);
        }
    }
    
    // ✅ STEP 3: Fallback al primo disponibile (sarà default se prima volta)
    ChartTemplateModel *firstTemplate = self.availableTemplates.firstObject;
    if (firstTemplate) {
        NSLog(@"🎯 Using first available template: %@", firstTemplate.templateName);
        return firstTemplate;
    }
    
    NSLog(@"❌ No templates available");
    return nil;
}



- (void)setupPlaceholderView {
    if (!self.panelsSplitView) return;
    
    // Create placeholder view
    self.placeholderView = [[NSView alloc] init];
    self.placeholderView.translatesAutoresizingMaskIntoConstraints = NO;
    self.placeholderView.wantsLayer = YES;
    self.placeholderView.layer.backgroundColor = [NSColor controlBackgroundColor].CGColor;
    [self.panelsSplitView addSubview:self.placeholderView];
    
    self.placeholderLabel = [[NSTextField alloc] init];
    self.placeholderLabel.stringValue = @"Enter a symbol to load chart data";
    self.placeholderLabel.editable = NO;
    self.placeholderLabel.bordered = NO;
    self.placeholderLabel.backgroundColor = [NSColor clearColor];
    self.placeholderLabel.font = [NSFont systemFontOfSize:16];
    self.placeholderLabel.textColor = [NSColor secondaryLabelColor];
    self.placeholderLabel.alignment = NSTextAlignmentCenter;
    self.placeholderLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.placeholderView addSubview:self.placeholderLabel];
    
    [NSLayoutConstraint activateConstraints:@[
        [self.placeholderView.topAnchor constraintEqualToAnchor:self.panelsSplitView.topAnchor],
        [self.placeholderView.leadingAnchor constraintEqualToAnchor:self.panelsSplitView.leadingAnchor],
        [self.placeholderView.trailingAnchor constraintEqualToAnchor:self.panelsSplitView.trailingAnchor],
        [self.placeholderView.bottomAnchor constraintEqualToAnchor:self.panelsSplitView.bottomAnchor],
        
        [self.placeholderLabel.centerXAnchor constraintEqualToAnchor:self.placeholderView.centerXAnchor],
        [self.placeholderLabel.centerYAnchor constraintEqualToAnchor:self.placeholderView.centerYAnchor]
    ]];
}


- (IBAction)toggleObjectsPanel:(id)sender {
    NSButton *button = (NSButton *)sender;
    BOOL shouldShow = (button.state == NSControlStateValueOn);
    
    if (shouldShow && !self.isObjectsPanelVisible) {
        NSLog(@"🎨 Showing objects panel...");
        
        // ✅ SEMPLICE: Insert al primo posto
        [self.mainSplitView insertArrangedSubview:self.objectsPanel atIndex:0];
        self.isObjectsPanelVisible = YES;
        
    } else if (!shouldShow && self.isObjectsPanelVisible) {
        NSLog(@"🎨 Hiding objects panel...");
        
        // ✅ SEMPLICE: Remove from superview
        [self.objectsPanel removeFromSuperview];
        self.isObjectsPanelVisible = NO;
    }
    [self.mainSplitView layoutSubtreeIfNeeded];

    [self splitViewFrameDidChange:nil];
    NSLog(@"🎨 Objects panel toggled: %@", self.isObjectsPanelVisible ? @"VISIBLE" : @"HIDDEN");
}

// ✅ TOGGLE INDICATORS PANEL - Versione semplificata
- (IBAction)toggleIndicatorsPanel:(id)sender {
    NSButton *button = (NSButton *)sender;
    BOOL shouldShow = (button.state == NSControlStateValueOn);
    
    if (shouldShow && !self.isIndicatorsPanelVisible) {
        NSLog(@"📈 Showing indicators panel...");
        
        // ✅ SEMPLICE: Add all'ultimo posto
        [self.mainSplitView addArrangedSubview:self.indicatorsPanel];
        self.isIndicatorsPanelVisible = YES;
        
    } else if (!shouldShow && self.isIndicatorsPanelVisible) {
        NSLog(@"📈 Hiding indicators panel...");
        
        // ✅ SEMPLICE: Remove from superview
        [self.indicatorsPanel removeFromSuperview];
        self.isIndicatorsPanelVisible = NO;
    }
    [self.mainSplitView layoutSubtreeIfNeeded];

    [self splitViewFrameDidChange:nil];
    NSLog(@"📈 Indicators panel toggled: %@", self.isIndicatorsPanelVisible ? @"VISIBLE" : @"HIDDEN");
}

#pragma mark - XIB Actions - Top Toolbar


- (IBAction)toggleObjectsVisibility:(id)sender {
  // Update all chart panels
    for (ChartPanelView *panel in self.chartPanels) {
        if (panel.objectRenderer) {
            panel.objectRenderer.objectsVisible = [sender state];
            [panel setNeedsDisplay:YES];
        }
    }
}



- (IBAction)dateRangeSegmentedChanged:(NSSegmentedControl *)sender {
    NSLog(@"🔄 IBAction: dateRangeSegmentedChanged");
    
    NSInteger selectedSegment = sender.selectedSegment;
    
    if (selectedSegment < 0) {
        NSLog(@"⚠️ Invalid date range selection");
        return;
    }
    
    // ✅ Calculate days for selected segment using existing method
    NSInteger newDays = [self getDaysForSegment:selectedSegment];
    
    // ✅ Determine if this is an extension or new range
    BOOL isExtension = (newDays > self.currentDateRangeDays);
    
    // ✅ Update persistence BEFORE handler call (handler might trigger data load)
    self.selectedDateRangeSegment = selectedSegment;
    [self saveDateRangeSegmentedDefaults];
    
    // ✅ USE HANDLER instead of legacy logic
    [self handleDataRangeChange:newDays isExtension:isExtension];
    
    NSLog(@"✅ IBAction: dateRangeSegmentedChanged completed via handler (%ld days, extension: %@)",
          (long)newDays, isExtension ? @"YES" : @"NO");
}



#pragma mark - Data Loading and Notifications


- (void)dataLoaded:(NSNotification *)notification {
    NSLog(@"🔄 Advanced: Data loaded notification received");
    
    NSString *symbol = notification.userInfo[@"symbol"];
    NSArray<HistoricalBarModel *> *bars = notification.userInfo[@"bars"];
    
    // ✅ Validate notification data
    if (!symbol || !bars || bars.count == 0) {
        NSLog(@"⚠️ Invalid data in notification");
        return;
    }
    
    // ✅ Only process if it's for current symbol
    if ([symbol isEqualToString:self.currentSymbol]) {
        NSLog(@"🔄 Notification: Processing data for current symbol via handler");
        [self processNewHistoricalData:bars
                         invalidations:ChartInvalidationData | ChartInvalidationIndicators | ChartInvalidationViewport];
    } else {
        NSLog(@"⏭️ Notification: Ignoring data for different symbol (%@ vs %@)", symbol, self.currentSymbol);
    }
    
    NSLog(@"✅ Advanced: Data loaded notification completed");
}



#pragma mark - NUOVE AZIONI ZOOM

- (IBAction)zoomOut:(NSButton *)sender {
    NSLog(@"🔍 Zoom Out requested - expanding left from fixed end");
    
    if (!self.chartData || self.chartData.count == 0) {
        NSLog(@"⚠️ No chart data for zoom");
        return;
    }
    
    // ✅ LOGIC: EndIndex resta fisso, aumentiamo il range verso sinistra
    NSInteger currentRange = self.visibleEndIndex - self.visibleStartIndex + 1; // +1 per range inclusivo
    NSInteger newRange = currentRange * 1.5; // Aumenta del 50%
    
    // Limita il nuovo range ai dati disponibili
    NSInteger maxPossibleRange = self.visibleEndIndex + 1; // +1 perché partiamo da index 0
    newRange = MIN(newRange, maxPossibleRange);
    
    // ✅ FIXED END: EndIndex non cambia mai
    // ✅ MOVING START: StartIndex si sposta verso sinistra
    self.visibleStartIndex = self.visibleEndIndex - newRange + 1;
    self.visibleStartIndex = MAX(0, self.visibleStartIndex); // Non andare sotto 0
    
    NSLog(@"🔍 Zoom Out: range %ld→%ld, fixed end=%ld, new start=%ld",
          (long)currentRange, (long)newRange,
          (long)self.visibleEndIndex, (long)self.visibleStartIndex);
    
    [self updatePanSliderFromVisibleRange];
    [self synchronizePanels];
}

- (IBAction)zoomIn:(NSButton *)sender {
    NSLog(@"🔍 Zoom In requested - contracting left from fixed end");
    
    if (!self.chartData || self.chartData.count == 0) {
        NSLog(@"⚠️ No chart data for zoom");
        return;
    }
    
    // ✅ LOGIC: EndIndex resta fisso, riduciamo il range verso sinistra
    NSInteger currentRange = self.visibleEndIndex - self.visibleStartIndex + 1; // +1 per range inclusivo
    NSInteger newRange = currentRange * 0.7; // Riduci del 30%
    
    // Minimo range per evitare zoom eccessivo
    NSInteger minRange = 10;
    newRange = MAX(newRange, minRange);
    
    // ✅ FIXED END: EndIndex non cambia mai
    // ✅ MOVING START: StartIndex si sposta verso destra (riducendo il range)
    self.visibleStartIndex = self.visibleEndIndex - newRange + 1;
    self.visibleStartIndex = MAX(0, self.visibleStartIndex); // Non andare sotto 0
    
    NSLog(@"🔍 Zoom In: range %ld→%ld, fixed end=%ld, new start=%ld",
          (long)currentRange, (long)newRange,
          (long)self.visibleEndIndex, (long)self.visibleStartIndex);
    
    [self updatePanSliderFromVisibleRange];
    [self synchronizePanels];
}

- (IBAction)zoomAll:(NSButton *)sender {
    NSLog(@"📊 Show All Data requested");
    
    // Mostra tutti i dati disponibili
    if (self.chartData.count > 0) {
        self.visibleStartIndex = 0;
        self.visibleEndIndex = self.chartData.count - 1;
        
        [self updatePanSliderFromVisibleRange];
        [self synchronizePanels];
    }
}

- (void)updatePanSliderFromVisibleRange {
    // Aggiorna lo slider per riflettere il range visibile corrente
    if (self.chartData.count > 0) {
        double progress = (double)self.visibleEndIndex / (double)(self.chartData.count - 1);
        self.panSlider.doubleValue = progress * 100.0;
    }
}


// ======== AGGIUNGI setupMainSplitView ========
- (void)setupMainSplitView {
    // Split view principale per i pannelli
    self.panelsSplitView = [[NSSplitView alloc] init];
    self.panelsSplitView.translatesAutoresizingMaskIntoConstraints = NO;
    self.panelsSplitView.vertical = NO; // Divisione orizzontale
    self.panelsSplitView.dividerStyle = NSSplitViewDividerStyleThin;
    [self.contentView addSubview:self.panelsSplitView];
}


- (void)createDefaultPanels {
    // Inizializza l'array se non esiste
    if (!self.chartPanels) {
        self.chartPanels = [NSMutableArray array];
    }
    
    // Security panel (candlestick) - 80% dell'altezza
    ChartPanelView *securityPanel = [[ChartPanelView alloc] initWithType:@"security"];
    securityPanel.chartWidget = self; // ← Questo trigger setupObjectsRenderer
    securityPanel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.chartPanels addObject:securityPanel];
    [self.panelsSplitView addSubview:securityPanel];
    
    // Volume panel (histogram) - 20% dell'altezza
    ChartPanelView *volumePanel = [[ChartPanelView alloc] initWithType:@"volume"];
    volumePanel.chartWidget = self; // ← Renderer già inizializzati in init
    volumePanel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.chartPanels addObject:volumePanel];
    [self.panelsSplitView addSubview:volumePanel];
    
    // ✅ RIMOSSO: [self setupRenderersForAllPanels]; - non più necessario
    
    NSLog(@"🎯 Default panels created with all renderers initialized");
}





- (void)styleCustomSegment {
    // Approccio alternativo: usa selectedSegmentTintColor per il colore generale
    if (@available(macOS 10.14, *)) {
        self.dateRangeSegmented.selectedSegmentBezelColor = [NSColor systemBlueColor];
    }
    
    // Alternativa: usa un'immagine personalizzata per il segmento CUSTOM
    // Questo richiederà più codice ma funziona su tutte le versioni di macOS
    
    NSLog(@"🔵 Custom segment styling applied (selectedSegmentTintColor)");
}

- (void)updateSplitViewConstraintForObjectsPanel:(BOOL)visible {
    // Deactivate current constraint
    self.splitViewLeadingConstraint.active = NO;

    if (visible) {
        // Attiva i vincoli dell’objectsPanel
        [NSLayoutConstraint activateConstraints:@[
            [self.objectsPanel.topAnchor constraintEqualToAnchor:self.panelsSplitView.topAnchor],
            [self.objectsPanel.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:8],
            [self.objectsPanel.bottomAnchor constraintEqualToAnchor:self.panelsSplitView.bottomAnchor],
            [self.objectsPanel.widthAnchor constraintEqualToConstant:100]
        ]];

        // Split view dopo objectsPanel
        self.splitViewLeadingConstraint = [self.panelsSplitView.leadingAnchor
            constraintEqualToAnchor:self.objectsPanel.trailingAnchor constant:8];

    } else {
        // Disattiva vincoli objectsPanel
        [NSLayoutConstraint deactivateConstraints:self.objectsPanel.constraints];

        // Split view attaccato al bordo sinistro
        self.splitViewLeadingConstraint = [self.panelsSplitView.leadingAnchor
            constraintEqualToAnchor:self.contentView.leadingAnchor constant:8];
    }

    self.splitViewLeadingConstraint.active = YES;

    [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
        context.duration = 0.3;
        context.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
        [self.contentView layoutSubtreeIfNeeded];
    } completionHandler:nil];
}

- (void)setupChartDefaults {
    self.currentSymbol = @"";
    self.currentTimeframe = BarTimeframeDaily;
    
    // NUOVO: Default preferences
    self.tradingHoursMode = ChartTradingHoursRegularOnly;
    self.initialBarsToShow = 100;
    // 🆕 NEW: Load default preferences for date ranges
    [self loadDateRangeDefaults];
    
    // 🆕 NEW: Set initial date range for default timeframe (Daily)
    self.currentDateRangeDays = [self getDefaultDaysForTimeframe:BarTimeframeDaily];
    self.sharedXContext = [[SharedXCoordinateContext alloc] init];


    self.chartPanels = [NSMutableArray array];
    self.objectsManager = [ChartObjectsManager managerForSymbol:self.currentSymbol];
    
    // Reset viewport state
    self.visibleStartIndex = 0;
    self.visibleEndIndex = 0;
   
    [ChartPreferencesWindow loadDefaultPreferencesForChartWidget:self];

}


- (void)viewDidAppear {
    [super viewDidAppear];
    
    // ✅ Solo setup finale (pannelli già creati)
    [self setInitialDividerPosition];
    [self setupFrameChangeNotifications];
    
    NSLog(@"🎯 ChartWidget appeared - setup completed");
}

// ✅ AGGIUNGI metodo separato per notifications
- (void)setupFrameChangeNotifications {
    if (self.panelsSplitView && !self.panelsSplitView.postsFrameChangedNotifications) {
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(splitViewFrameDidChange:)
                                                     name:NSViewFrameDidChangeNotification
                                                   object:self.panelsSplitView];
        
        self.panelsSplitView.postsFrameChangedNotifications = YES;
    }
}


- (void)setupNotificationCenterIntegration {
    NSLog(@"🔗 Setting up NotificationCenter integration with handlers");
    
    // ✅ Data loading notifications
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(dataLoaded:)
                                                 name:DataHubDataLoadedNotification
                                               object:nil];
    
    // ✅ Widget chain notifications (if needed)
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleWidgetChainNotification:)
                                                 name:@"WidgetChainUpdateNotification"
                                               object:nil];
    
    NSLog(@"✅ NotificationCenter integration setup completed");
}


- (void)handleWidgetChainNotification:(NSNotification *)notification {
    NSLog(@"🔗 Widget chain notification received");
    
    NSDictionary *userInfo = notification.userInfo;
    NSString *updateType = userInfo[@"update"];
    BaseWidget *sender = userInfo[@"sender"];
    
    if ([updateType isEqualToString:@"symbolChange"]) {
        NSArray *symbols = userInfo[@"symbols"];
        if (symbols && symbols.count > 0) {
            [self handleSymbolsFromChain:symbols fromWidget:sender];
        }
    } else if ([updateType isEqualToString:@"chartPattern"]) {
        NSDictionary *patternData = userInfo[@"data"];
        if (patternData) {
            [self loadChartPatternFromChainData:patternData fromWidget:sender];
        }
    }
    
    NSLog(@"✅ Widget chain notification processed");
}


- (void)clearExistingPanels {
    if (self.chartPanels && self.chartPanels.count > 0) {
        NSLog(@"🗑️ Clearing existing panels...");
        
        for (ChartPanelView *panel in self.chartPanels) {
            [panel removeFromSuperview];
        }
        
        [self.chartPanels removeAllObjects];
    }
}




- (void)createEmergencyFallbackPanels {
    NSLog(@"🔧 Creating fallback panels...");
    
    // Clear existing panels
    [self clearExistingPanels];
    
    if (!self.chartPanels) {
        self.chartPanels = [NSMutableArray array];
    }
    
    // Security panel (80%)
    ChartPanelView *securityPanel = [[ChartPanelView alloc] initWithType:@"security"];
    securityPanel.chartWidget = self;
    securityPanel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.chartPanels addObject:securityPanel];
    [self.panelsSplitView addSubview:securityPanel];
    
    // Volume panel (20%)
    ChartPanelView *volumePanel = [[ChartPanelView alloc] initWithType:@"volume"];
    volumePanel.chartWidget = self;
    volumePanel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.chartPanels addObject:volumePanel];
    [self.panelsSplitView addSubview:volumePanel];
    
    NSLog(@"✅ Fallback panels created (renderers will be setup lazily)");
}

// Helper per aggiornare la visibilità del placeholder
- (void)updatePlaceholderVisibility {
    BOOL hasPanels = self.panelsSplitView.subviews.count > 1; // >1 perché include il placeholder
    self.placeholderView.hidden = hasPanels;
}




- (void)setInitialDividerPosition {
    dispatch_async(dispatch_get_main_queue(), ^{
        CGFloat totalHeight = self.panelsSplitView.frame.size.height;
        
        if (totalHeight > 100) {
            // 80% per security panel, 20% per volume panel
            CGFloat dividerPosition = totalHeight * 0.8;
            [self.panelsSplitView setPosition:dividerPosition ofDividerAtIndex:0];
            
            NSLog(@"✅ Set initial divider position: %.1f (80%% of %.1f)",
                  dividerPosition, totalHeight);
        }
    });
}

#pragma mark - Data Notifications

- (void)registerForDataNotifications {
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleHistoricalDataUpdate:)
                                                 name:DataHubDataLoadedNotification
                                               object:nil];
}

- (void)handleHistoricalDataUpdate:(NSNotification *)notification {
    if (self.isStaticMode) {
        NSLog(@"⚠️ StaticMode: Ignoring DataHub update (static data mode)");
        return;
    }

    NSDictionary *userInfo = notification.userInfo;
    NSString *symbol = userInfo[@"symbol"];
    
    if (![symbol isEqualToString:self.currentSymbol]) {
        NSLog(@"💡 Ignoring data update for different symbol: %@ (current: %@)", symbol, self.currentSymbol);
        return;
    }
    
    NSArray<HistoricalBarModel *> *bars = userInfo[@"bars"];
    
    // ✅ FIX CRITICO: Usa processNewHistoricalData invece di updateWithHistoricalBars
    // Questo assicura che venga chiamato applyInvalidations che invalida i layer
    NSLog(@"🔄 handleHistoricalDataUpdate: Routing to processNewHistoricalData");
    
    [self processNewHistoricalData:bars
                     invalidations:(ChartInvalidationData |
                                   ChartInvalidationIndicators |
                                   ChartInvalidationViewport)];
    
    NSLog(@"✅ handleHistoricalDataUpdate: Data processed with proper invalidations");
}


#pragma mark - Chain Notifications





- (void)broadcastSymbolToChain:(NSString *)symbol {
    if (!self.chainActive || !symbol) return;
    
    NSDictionary *update = @{
        @"action": @"setSymbols",
        @"symbols": @[symbol]
    };
    
    NSDictionary *userInfo = @{
        kChainUpdateKey: update,
        kChainSenderKey: self.widgetID,
        @"timestamp": [NSDate date]
    };
    
    [[NSNotificationCenter defaultCenter] postNotificationName:kWidgetChainUpdateNotification
                                                        object:self
                                                      userInfo:userInfo];
}

#pragma mark - Actions

- (IBAction)symbolChanged:(NSTextField *)sender {
    NSString *inputText = sender.stringValue;
    
    // Clean whitespace
    inputText = [inputText stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    
    if (inputText.length == 0) {
        NSLog(@"⚠️ Empty symbol field");
        return;
    }
    
    // ✅ CHECK FOR SMART INPUT (contains comma)
    if ([inputText containsString:@","]) {
        NSLog(@"🧠 Smart symbol input detected: %@", inputText);
        [self processSmartSymbolInput:inputText];
    } else {
        // ✅ SIMPLE SYMBOL - use handler directly
        NSString *cleanSymbol = inputText.uppercaseString;
        NSLog(@"📊 Simple symbol input: %@", cleanSymbol);
        [self handleSymbolChange:cleanSymbol forceReload:NO];
        
        // ✅ Broadcast to chain for simple symbol
        if ([self respondsToSelector:@selector(broadcastSymbolToChain:)]) {
            [self performSelector:@selector(broadcastSymbolToChain:) withObject:cleanSymbol];
        }
    }
}

#pragma mark - Timeframe Mapping (UNIFIED)

- (BarTimeframe)segmentIndexToBarTimeframe:(NSInteger)segmentIndex {
    switch (segmentIndex) {
        case 0: return BarTimeframe1Min;      // Segment 0 → 1 min
        case 1: return BarTimeframe5Min;      // Segment 1 → 5 min
        case 2: return BarTimeframe30Min;
        case 3: return BarTimeframe1Hour;
        case 4: return BarTimeframe4Hour;
        case 5: return BarTimeframeDaily;
        case 6: return BarTimeframeWeekly;
        case 7: return BarTimeframeMonthly;
        default:
            NSLog(@"⚠️ Invalid timeframe segment: %ld", (long)segmentIndex);
            return BarTimeframeDaily;         // Fallback
    }
}

- (NSInteger)barTimeframeToSegmentIndex:(BarTimeframe)timeframe {
    switch (timeframe) {
        case BarTimeframe1Min: return 0;      // 1 min → Segment 0
        case BarTimeframe5Min: return 1;      // 5 min → Segment 1
        case BarTimeframe30Min: return 2;     // 30 min → Segment 3
        case BarTimeframe1Hour: return 3;     // 1 hour → Segment 4
        case BarTimeframe4Hour: return 4;     // 4 hour → Segment 5
        case BarTimeframeDaily: return 5;     // Daily → Segment 6
        case BarTimeframeWeekly: return 6;    // Weekly → Segment 7
        case BarTimeframeMonthly: return 7;   // Monthly → Segment 8
        default:
            NSLog(@"⚠️ Unsupported timeframe: %ld", (long)timeframe);
            return 6;                         // Fallback to Daily segment
    }
}

- (IBAction)timeframeChanged:(id)sender {
    if (self.timeframeSegmented.selectedSegment >= 0) {
        // ✅ FIXED: Use mapping function instead of direct cast
        BarTimeframe newTimeframe = [self segmentIndexToBarTimeframe:self.timeframeSegmented.selectedSegment];
        
        if (newTimeframe != self.currentTimeframe) {
            self.currentTimeframe = newTimeframe;
            
            // Update date range segmented control (usa preferences)
            [self updateDateRangeSegmentedForTimeframe:newTimeframe];
            
            // Reset visible range per il nuovo timeframe
            [self resetVisibleRangeForTimeframe];
            
            // Reload data if we have a symbol
            if (self.currentSymbol && self.currentSymbol.length > 0) {
                [self loadDataWithCurrentSettings];
            }
            
            NSLog(@"📊 Timeframe changed to: %ld (%@), visible range will be reset",
                  (long)newTimeframe, [self timeframeDisplayName:newTimeframe]);
        }
    }
}

#pragma mark - 🆕 NEW: Visible Range Management

- (void)resetVisibleRangeForTimeframe {
    // 🎯 UNICO PUNTO dove si resetta il visible range
    // Ottieni il default visible per il timeframe corrente
    NSInteger defaultVisible = [self getDefaultVisibleDaysForTimeframe:self.currentTimeframe];
    
    // Converte giorni in barre approssimative (dipende dal timeframe)
    NSInteger barsToShow = [self convertDaysToBarsForTimeframe:defaultVisible timeframe:self.currentTimeframe];
    
    // Imposta il nuovo initialBarsToShow
    self.initialBarsToShow = barsToShow;
    
    // Forza il reset del visible range al prossimo caricamento dati
    // Invalida il visible range corrente così updatePanelsWithData lo resetterà
    self.visibleStartIndex = -1;
    self.visibleEndIndex = -1;
    
    NSLog(@"🔄 Reset visible range for timeframe %ld: will show ~%ld bars (from %ld days default)",
          (long)self.currentTimeframe, (long)barsToShow, (long)defaultVisible);
}

- (NSInteger)convertDaysToBarsForTimeframe:(NSInteger)days timeframe:(BarTimeframe)timeframe {
    if (days <= 0) return 0;
    
    NSInteger barsPerDay = 0;
    
    switch (timeframe) {
        case BarTimeframe1Min:
        case BarTimeframe2Min:
        case BarTimeframe5Min:
        case BarTimeframe10Min:
        case BarTimeframe15Min:
        case BarTimeframe20Min:
        case BarTimeframe30Min:
        case BarTimeframe1Hour:
        case BarTimeframe90Min:
        case BarTimeframe2Hour:
        case BarTimeframe4Hour: {
            // Base: trading hours regolari (9:30 - 16:00 → 6.5h = 390 minuti)
            NSInteger minutesPerDay = 390;
            
            // Se extended hours → includi pre-market (4:00–9:30 = 5.5h) e after (16:00–20:00 = 4h)
            if (self.tradingHoursMode == ChartTradingHoursWithAfterHours) {
                minutesPerDay = 390 + 330 + 240; // 960 minuti = 16h
            }
            
            barsPerDay = minutesPerDay / timeframe;
            break;
        }
            
        case BarTimeframeDaily:
            barsPerDay = 1;
            break;
            
        case BarTimeframeWeekly:
            barsPerDay = 5; // trading days in una settimana
            break;
            
        case BarTimeframeMonthly:
            barsPerDay = 21; // trading days medi in un mese
            break;
            
        case BarTimeframeQuarterly:
            barsPerDay = 63; // ~3 mesi
            break;
    }
    
    return days * barsPerDay;
}


- (void)panSliderChanged:(NSSlider *)sender {
    if (self.isUpdatingSlider) return;  // ✅ Ignora se update programmatico

    if (!self.chartData || self.chartData.count == 0) return;
    
    NSInteger currentRange = self.visibleEndIndex - self.visibleStartIndex;
    NSInteger totalBars = self.chartData.count;
    double recentDataPercentage = sender.doubleValue / 100.0; // 0.0 = inizio timeline, 1.0 = fine timeline
    
    // ✅ NUOVA LOGICA: Calcola dove posizionare la finestra basandosi sull'estremo più recente desiderato
    NSInteger desiredEndIndex = (NSInteger)((totalBars - 1) * recentDataPercentage);
    NSInteger newStartIndex = desiredEndIndex - currentRange;
    NSInteger newEndIndex = desiredEndIndex;
    
    // Clamp ai limiti validi
    if (newStartIndex < 0) {
        newStartIndex = 0;
        newEndIndex = currentRange;
    } else if (newEndIndex >= totalBars) {
        newEndIndex = totalBars - 1;
        newStartIndex = newEndIndex - currentRange;
    }
    
    [self zoomToRange:newStartIndex endIndex:newEndIndex];
    
    NSLog(@"📅 Timeline position: %.1f%% -> showing bars [%ld-%ld] (most recent at bar %ld)",
          sender.doubleValue, (long)newStartIndex, (long)newEndIndex, (long)newEndIndex);
}

#pragma mark - Public Methods




- (void)showMicroscopeModeNotification {
    // Trova il primo panel per mostrare il messaggio
    ChartPanelView *targetPanel = self.chartPanels.firstObject;
    if (!targetPanel) return;
    
    // Crea messaggio temporaneo
    NSTextField *notificationLabel = [[NSTextField alloc] init];
    notificationLabel.stringValue = @"🔬 MICROSCOPE MODE - Static Data";
    notificationLabel.font = [NSFont boldSystemFontOfSize:14];
    notificationLabel.textColor = [NSColor systemBlueColor];
    notificationLabel.backgroundColor = [[NSColor systemBlueColor] colorWithAlphaComponent:0.1];
    notificationLabel.bordered = YES;
    notificationLabel.bezeled = YES;
    notificationLabel.editable = NO;
    notificationLabel.selectable = NO;
    notificationLabel.alignment = NSTextAlignmentCenter;
    
    // Posiziona al centro del panel
    notificationLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [targetPanel addSubview:notificationLabel];
    
    [NSLayoutConstraint activateConstraints:@[
        [notificationLabel.centerXAnchor constraintEqualToAnchor:targetPanel.centerXAnchor],
        [notificationLabel.topAnchor constraintEqualToAnchor:targetPanel.topAnchor constant:10],
        [notificationLabel.widthAnchor constraintEqualToConstant:250],
        [notificationLabel.heightAnchor constraintEqualToConstant:30]
    ]];
    
    // Rimuovi dopo 3 secondi
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [notificationLabel removeFromSuperview];
    });
    
    NSLog(@"🔬 Showed microscope mode notification to user");
}

- (void)forceChartRedraw {
    // Metodo helper per forzare redraw completo
    for (ChartPanelView *panel in self.chartPanels) {
        if (panel.objectRenderer) {
            [panel.objectRenderer invalidateObjectsLayer];
            [panel.objectRenderer invalidateEditingLayer];
            
            // ✅ FORZA anche redraw del panel view stesso
            [panel setNeedsDisplay:YES];
        }
    }
    
    NSLog(@"🎨 Forced complete chart redraw");
}



- (void)zoomToRange:(NSInteger)startIndex endIndex:(NSInteger)endIndex {
    if (!self.chartData || self.chartData.count == 0) return;
    if (self.visibleStartIndex == startIndex && self.visibleEndIndex == endIndex) {
        return;
    }
    // ✅ FIX: Clamp indices ai valori validi dell'array
    startIndex = MAX(0, startIndex);
    endIndex = MIN(self.chartData.count , endIndex);  // ❌ ERA: self.chartData.count
    
    // ✅ VERIFICA: Ensure valid range
    if (startIndex >= endIndex) {
        NSLog(@"⚠️ Invalid zoom range: start=%ld >= end=%ld, data count=%ld",
              (long)startIndex, (long)endIndex, (long)self.chartData.count);
        return;
    }
    
    self.visibleStartIndex = startIndex;
    self.visibleEndIndex = endIndex;
    
    [self updateViewport];
    [self synchronizePanels];
    
    NSLog(@"📊 Zoom applied: [%ld-%ld] (%ld bars visible, data=%ld bars total)",
          (long)startIndex, (long)endIndex,
          (long)(endIndex - startIndex + 1), (long)self.chartData.count);
}

- (void)resetZoom {
    if (!self.chartData || self.chartData.count == 0) return;
    
    // ✅ FIX: endIndex corretto
    [self zoomToRange:0 endIndex:self.chartData.count-1];
}
#pragma mark - Helper Methods


- (void)resetToInitialView {
    if (!self.chartData || self.chartData.count == 0) return;
        
    NSInteger totalBars = self.chartData.count;
    NSInteger barsToShow = totalBars;
    NSInteger startIndex = 0;
   
    if (!self.isStaticMode) {
         barsToShow = MIN(self.initialBarsToShow, totalBars);
         startIndex = MAX(0, totalBars - barsToShow);
    }
    // ✅ FIX: endIndex corretto (ultimo elemento valido)
    NSInteger endIndex = totalBars-1 ;
    
    [self zoomToRange:startIndex endIndex:endIndex];
    
    NSLog(@"📅 Reset to initial view: [%ld-%ld] showing %ld recent bars",
          (long)startIndex, (long)endIndex, (long)barsToShow);
}

- (void)updateViewport {
    [self updatePanSlider];
}


- (void)updatePanSlider {
    if (!self.chartData || self.chartData.count == 0) return;
    
    NSInteger totalBars = self.chartData.count;
    double recentDataPercentage = (double)self.visibleEndIndex / (totalBars - 1);
    recentDataPercentage = MAX(0.0, MIN(1.0, recentDataPercentage));
    
    double newValue = recentDataPercentage * 100.0;
    
    // ✅ Evita update se valore non cambiato
    if (fabs(newValue - self.lastSliderValue) < 0.01) return;
    
    // ✅ Usa flag invece di rimuovere/riassegnare target
    self.isUpdatingSlider = YES;
    [self.panSlider setDoubleValue:newValue];
    self.isUpdatingSlider = NO;
    
    self.lastSliderValue = newValue;
}


- (void)synchronizePanels {
    [self updateSharedXContext];

    for (ChartPanelView *panel in self.chartPanels) {
        [panel updateSharedXContext:self.sharedXContext];

        // ✅ NUOVO: Passa solo dati e range X - ogni pannello calcola il proprio Y
        [panel updateWithData:self.chartData
                   startIndex:self.visibleStartIndex
                     endIndex:self.visibleEndIndex];
    }
}
- (void)updateSharedXContext {
    if (!self.sharedXContext) {
        self.sharedXContext = [[SharedXCoordinateContext alloc] init];
    }
    
    // Update X context properties
    self.sharedXContext.chartData = self.chartData;
    self.sharedXContext.visibleStartIndex = self.visibleStartIndex;
    self.sharedXContext.visibleEndIndex = self.visibleEndIndex;
    
    // ✅ USA containerWidth del panelsSplitView (stessa larghezza per tutti i pannelli)
    self.sharedXContext.containerWidth = self.panelsSplitView.bounds.size.width;
    
    // Trading context
    self.sharedXContext.barsPerDay = [self barsPerDayForCurrentTimeframe];
    self.sharedXContext.currentTimeframeMinutes = [self getCurrentTimeframeInMinutes];
    self.sharedXContext.includesExtendedHours = self.tradingHoursMode;
}


- (NSString *)timeframeToString:(BarTimeframe)timeframe {
    switch (timeframe) {
        case BarTimeframe1Min: return @"1m";
        case BarTimeframe5Min: return @"5m";
        case BarTimeframe15Min: return @"15m";
        case BarTimeframe30Min: return @"30m";
        case BarTimeframe1Hour: return @"1h";
        case BarTimeframe4Hour: return @"4h";
        case BarTimeframeDaily: return @"1d";
        case BarTimeframeWeekly: return @"1w";
        case BarTimeframeMonthly: return @"1M";
        default: return @"1d";
    }
}

#pragma mark - Menu Support
/*menu sta nel chartpanelview
- (void)appendWidgetSpecificItemsToMenu:(NSMenu *)menu {
    // Add chart-specific menu items
    NSMenuItem *separator = [NSMenuItem separatorItem];
    [menu addItem:separator];
    
    NSMenuItem *addPanelItem = [[NSMenuItem alloc] initWithTitle:@"Add Panel"
                                                          action:@selector(showAddPanelMenu:)
                                                   keyEquivalent:@""];
    addPanelItem.target = self;
    [menu addItem:addPanelItem];
    
    NSMenuItem *resetZoomItem = [[NSMenuItem alloc] initWithTitle:@"Reset Zoom"
                                                           action:@selector(zoomAll:)
                                                    keyEquivalent:@""];
    resetZoomItem.target = self;
    [menu addItem:resetZoomItem];
    [self addSaveDataMenuItemsToMenu:menu];
    [self addImageExportMenuItemToMenu:menu];

}*/

- (NSArray<NSString *> *)selectedSymbols {
    // ChartWidget doesn't have selection, return current symbol if any
    return self.currentSymbol ? @[self.currentSymbol] : @[];
}

- (NSArray<NSString *> *)contextualSymbols {
    // Return current symbol as contextual
    return self.currentSymbol ? @[self.currentSymbol] : @[];
}

- (NSString *)contextMenuTitle {
    return self.currentSymbol ?: @"Chart";
}

- (void)showAddPanelMenu:(NSMenuItem *)sender {
    // TODO: Implement panel addition menu
}




// ======== AGGIUNGI metodi delegate per symbolTextField ========
#pragma mark - NSTextFieldDelegate

- (void)controlTextDidChange:(NSNotification *)notification {
    NSSearchField *searchField = notification.object;
    
    if (searchField != self.symbolTextField) return;
    
    NSString *searchTerm = searchField.stringValue;
    
    if (searchTerm.length == 0) {
        // Clear any search results
        self.currentSearchResults = nil;
        return;
    }
    
    if (self.isStaticMode) {
        // 🔵 STATIC MODE: Search in metadata cache
        [self performSavedDataSearch:searchTerm];
    } else {
        // 🔴 NORMAL MODE: Search live symbols via API
        [self performLiveSymbolSearch:searchTerm];
    }
 

}

- (void)controlTextDidEndEditing:(NSNotification *)notification {
    NSDictionary *info = notification.userInfo;
    NSNumber *movement = info[@"NSTextMovement"];
    
    if (movement.intValue != NSReturnTextMovement) {
        return;
    }
    
    NSSearchField *searchField = notification.object;
    
    // Handle base widget delegate first
    if (searchField == self.titleComboBox) {
        [super controlTextDidEndEditing:notification];
        return;
    }
    
    if (searchField == self.symbolTextField) {
        NSString *inputText = [searchField.stringValue stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        
        if (inputText.length == 0) return;
        
        if (self.isStaticMode) {
            // 🔵 STATIC MODE: Load best matching saved data
            [self executeStaticModeSearch:inputText];
        } else {
            // 🔴 NORMAL MODE: Execute symbol change (existing smart entry logic)
            [self executeNormalModeEntry:inputText];
        }
    }
}



#pragma mark - Search Results UI (Optional Enhancement)

// Optional: Add search results dropdown
- (NSInteger)numberOfItemsInComboBox:(NSComboBox *)comboBox {
    if (comboBox == self.symbolTextField && self.currentSearchResults) {
        return self.currentSearchResults.count;
    }
    return 0;
}

- (id)comboBox:(NSComboBox *)comboBox objectValueForItemAtIndex:(NSInteger)index {
    if (comboBox == self.symbolTextField &&
        self.currentSearchResults &&
        index < self.currentSearchResults.count) {
        
        StorageMetadataItem *item = self.currentSearchResults[index];
        
        if (self.isStaticMode) {
            // Show rich description for saved data
            return [NSString stringWithFormat:@"%@ %@ [%@] %ld bars",
                   item.symbol, item.timeframe,
                   item.isContinuous ? @"CONT" : @"SNAP",
                   (long)item.barCount];
        } else {
            // Show simple symbol for live search
            return item.symbol;
        }
    }
    return @"";
}

#pragma mark - Cleanup


- (void)cleanupNotificationCenterIntegration {
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                     name:DataHubDataLoadedNotification
                                                   object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                     name:@"WidgetChainUpdateNotification"
                                                   object:nil];
    
    NSLog(@"🧹 NotificationCenter integration cleaned up");
}


- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                     name:NSViewFrameDidChangeNotification
                                                   object:nil];
}



- (void)showTemporaryMessage:(NSString *)message {
    // Crea label temporanea che scompare dopo 2 secondi
    NSTextField *tempLabel = [[NSTextField alloc] init];
    tempLabel.stringValue = message;
    tempLabel.editable = NO;
    tempLabel.bordered = NO;
    tempLabel.backgroundColor = [[NSColor controlBackgroundColor] colorWithAlphaComponent:0.9];
    tempLabel.textColor = [NSColor secondaryLabelColor];
    tempLabel.font = [NSFont systemFontOfSize:11];
    tempLabel.alignment = NSTextAlignmentCenter;
    tempLabel.translatesAutoresizingMaskIntoConstraints = NO;
    
    [self.view addSubview:tempLabel];
    
    // Posiziona al centro del chart
    [NSLayoutConstraint activateConstraints:@[
        [tempLabel.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [tempLabel.topAnchor constraintEqualToAnchor:self.view.topAnchor constant:60],
        [tempLabel.heightAnchor constraintEqualToConstant:20]
    ]];
    
    // Scompare dopo 2 secondi
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [tempLabel removeFromSuperview];
    });
}

- (BOOL)areObjectsVisible {
    return (self.objectsVisibilityToggle.state == NSControlStateValueOn);
}

- (void)setObjectsVisible:(BOOL)visible {
    self.objectsVisibilityToggle.state = visible ? NSControlStateValueOn : NSControlStateValueOff;
}


#pragma mark - Alert Management

- (void)refreshAlertsForCurrentSymbol {
    if (!self.currentSymbol) return;
    
    NSLog(@"🚨 ChartWidget: Refreshing alerts for symbol %@", self.currentSymbol);
    
    for (ChartPanelView *panel in self.chartPanels) {
        if (panel.alertRenderer) {
            [panel.alertRenderer loadAlertsForSymbol:self.currentSymbol];
        }
    }
}

#pragma mark - Chain Notifications
- (void)handleChainAction:(NSString *)action withData:(id)data fromWidget:(BaseWidget *)sender {
    if ([action isEqualToString:@"loadChartPattern"]) {
        [self loadChartPatternFromChainData:data fromWidget:sender];
    } else {
        // ✅ IMPORTANTE: Chiama super per gestire altre azioni future
        [super handleChainAction:action withData:data fromWidget:sender];
    }
}


- (void)handleSymbolsFromChain:(NSArray<NSString *> *)symbols fromWidget:(BaseWidget *)sender {
    NSLog(@"🔗 Advanced: Received %lu symbols from chain", (unsigned long)symbols.count);
    
    // ChartWidget shows one symbol at a time - take first
    NSString *newSymbol = symbols.firstObject;
    if (!newSymbol || newSymbol.length == 0) {
        NSLog(@"⚠️ No valid symbol in chain data");
        return;
    }
    
    // ✅ Early exit if same symbol
    if ([newSymbol.uppercaseString isEqualToString:self.currentSymbol]) {
        NSLog(@"⏭️ Ignoring same symbol from chain: %@ (current: %@)", newSymbol, self.currentSymbol);
        return;
    }
    
    // ✅ USE HANDLER instead of legacy loadSymbol:
    NSLog(@"🔄 Chain: Using handler for symbol change from %@", NSStringFromClass([sender class]));
    [self handleSymbolChange:newSymbol forceReload:NO];
    
    // ✅ Show feedback
    NSString *senderType = NSStringFromClass([sender class]);
    NSString *feedbackMessage = [NSString stringWithFormat:@"📈 Loaded %@ from %@", newSymbol, senderType];
    [self showChainFeedback:feedbackMessage];
    
    NSLog(@"✅ Advanced: Chain symbol change completed via handler");
}


- (void)showChainFeedback:(NSString *)message {
    // Trova il primo panel per mostrare il feedback
    ChartPanelView *mainPanel = [self findMainChartPanel];
    if (!mainPanel) {
        mainPanel = self.chartPanels.firstObject;
    }
    
    if (!mainPanel) {
        NSLog(@"⚠️ No chart panel available for feedback display");
        return;
    }
    
    // Crea un label temporaneo per feedback
    NSTextField *feedbackLabel = [NSTextField labelWithString:message];
    feedbackLabel.backgroundColor = [[NSColor systemBlueColor] colorWithAlphaComponent:0.9];
    feedbackLabel.textColor = [NSColor controlBackgroundColor];
    feedbackLabel.font = [NSFont boldSystemFontOfSize:12];
    feedbackLabel.alignment = NSTextAlignmentCenter;
    feedbackLabel.drawsBackground = YES;
    feedbackLabel.bordered = NO;
    feedbackLabel.editable = NO;
    
    // Posiziona il feedback nell'angolo in basso a sinistra del panel
    feedbackLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [mainPanel addSubview:feedbackLabel];
    
    [NSLayoutConstraint activateConstraints:@[
        [feedbackLabel.bottomAnchor constraintEqualToAnchor:mainPanel.bottomAnchor constant:-15],
        [feedbackLabel.leadingAnchor constraintEqualToAnchor:mainPanel.leadingAnchor constant:15],
        [feedbackLabel.heightAnchor constraintEqualToConstant:25]
    ]];
    
    // Anima la scomparsa dopo 2.5 secondi
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
            context.duration = 0.3;
            [[feedbackLabel animator] setAlphaValue:0.0];
        } completionHandler:^{
            [feedbackLabel removeFromSuperview];
        }];
    });
}

// ============================================================
// HELPER: Find Main Chart Panel
// ============================================================

- (ChartPanelView *)findMainChartPanel {
    for (ChartPanelView *panel in self.chartPanels) {
        if ([panel.panelType isEqualToString:@"security"]) {
            return panel;
        }
    }
    return nil;
}

- (void)updatePanelsWithData:(NSArray<HistoricalBarModel *> *)data {
    if (data.count == 0) return;
    
    // Store data reference
    self.chartData = data;
    NSInteger dataCount = data.count;
    
    // 🔧 FIX: Solo se NON c'è già un visible range valido, imposta il default
    BOOL hasValidVisibleRange = (self.visibleStartIndex >= 0 &&
                                self.visibleEndIndex > 0 &&
                                self.visibleStartIndex < self.visibleEndIndex &&
                                self.visibleEndIndex < dataCount);
    
    if (!hasValidVisibleRange) {
        // ✅ PRIMO CARICAMENTO: Imposta visible range di default
        NSInteger barsToShow = MIN(self.initialBarsToShow, dataCount);
        self.visibleStartIndex = MAX(0, dataCount - barsToShow);
        self.visibleEndIndex = dataCount - 1;
        
        NSLog(@"📊 First load - Setting initial viewport: Data: %ld bars, Showing: [%ld-%ld] (%ld bars visible)",
              (long)dataCount, (long)self.visibleStartIndex, (long)self.visibleEndIndex,
              (long)(self.visibleEndIndex - self.visibleStartIndex + 1));
    } else {
        // ✅ CARICAMENTO SUCCESSIVO: Mantieni visible range esistente, ma aggiusta se fuori bounds
        // ✅ COMPORTAMENTO NUOVO: Sposta SEMPRE all'ultima barra mantenendo l'ampiezza
        NSInteger visibleBars = self.visibleEndIndex - self.visibleStartIndex + 1;
        self.visibleEndIndex = dataCount - 1;  // Sempre all'ultima barra
        self.visibleStartIndex = MAX(0, self.visibleEndIndex - visibleBars + 1);
        
        NSLog(@"📊 Preserving existing viewport: Data: %ld bars, Visible: [%ld-%ld] (%ld bars visible)",
              (long)dataCount, (long)self.visibleStartIndex, (long)self.visibleEndIndex,
              (long)(self.visibleEndIndex - self.visibleStartIndex + 1));
    }

    // Update all panels with new data and viewport
    [self synchronizePanels];
    [self updatePanSlider];
}

// ============================================================
// NUOVO: Public Symbol Access Method
// ============================================================

- (NSString *)getCurrentSymbol {
    return self.currentSymbol;
}


#pragma mark - Preferences Management

- (IBAction)showPreferences:(id)sender {
    self.preferencesWindowController = [[ChartPreferencesWindow alloc] initWithChartWidget:self];
    [self.preferencesWindowController showPreferencesWindow];
    NSLog(@"🛠️ Chart preferences window opened");
}

- (void)preferencesDidChange:(BOOL)needsDataReload {
    NSLog(@"🔄 Advanced: Preferences changed (reload needed: %@)", needsDataReload ? @"YES" : @"NO");
    
    // ✅ Reload preferences
    [self loadDateRangeDefaults];
    
    // ✅ Update UI if not CUSTOM segment
    if (self.selectedDateRangeSegment != 0) {
        NSInteger preferenceDefault = [self getDefaultDaysForTimeframe:self.currentTimeframe];
        if ([self respondsToSelector:@selector(updateCustomSegmentWithDays:)]) {
            [self performSelector:@selector(updateCustomSegmentWithDays:) withObject:@(preferenceDefault)];
        }
    }
    
    // ✅ USE HANDLER for trading hours change if data reload needed
    if (needsDataReload) {
        NSLog(@"🔄 Preferences: Using handler for trading hours change");
        [self handleTradingHoursChange:self.tradingHoursMode];
    } else {
        // ✅ Only UI update needed
        NSLog(@"🔄 Preferences: Only UI update needed");
        [self processUIUpdate:ChartInvalidationUI];
    }
    
    NSLog(@"✅ Advanced: Preferences change completed via handler");
}

- (void)updateAllRenderersContext {
    for (ChartPanelView *panel in self.chartPanels) {
        if (panel.objectRenderer) {
            // Gli object renderer useranno le nuove preferenze per calcolare coordinate X
            [panel.objectRenderer invalidateObjectsLayer];
            NSLog(@"🔄 Updated object renderer context for panel %@", panel.panelType);
        }
    }
}

- (NSInteger)barsPerDayForCurrentTimeframe {
    NSInteger timeframeMinutes = [self getCurrentTimeframeInMinutes];
    
    // ✅ FIX: Gestione speciale per timeframe Daily+
    if (self.currentTimeframe >= BarTimeframeDaily) {
        return 1; // 1 barra per giorno di trading
    }
    
    switch (self.tradingHoursMode) {
        case ChartTradingHoursRegularOnly:
            // Regular hours: 09:30-16:00 = 6.5 ore = 390 minuti
            return 390 / timeframeMinutes;
            
        case ChartTradingHoursWithAfterHours:
            // ✅ FIX: After-hours realistici
            // Pre-market: 04:00-09:30 = 5.5 ore = 330 minuti
            // Regular: 09:30-16:00 = 6.5 ore = 390 minuti
            // After-hours: 16:00-20:00 = 4 ore = 240 minuti
            // Totale: 15 ore = 900 minuti (non 24 ore!)
            return 900 / timeframeMinutes;
    }
}

- (NSInteger)getCurrentTimeframeInMinutes {
    switch (self.currentTimeframe) {
        case BarTimeframe1Min: return 1;
        case BarTimeframe5Min: return 5;
        case BarTimeframe15Min: return 15;
        case BarTimeframe30Min: return 30;
        case BarTimeframe1Hour: return 60;
        case BarTimeframe4Hour: return 240;
        
        // ✅ FIX: Per Daily+ restituisci valori che hanno senso per i calcoli
        case BarTimeframeDaily: return 390;    // Trading minutes in a day
        case BarTimeframeWeekly: return 1950;  // Trading minutes in a week (5 * 390)
        case BarTimeframeMonthly: return 8190; // Trading minutes in a month (~21 * 390)
        
        default: return 390; // Default to daily trading minutes
    }
}

#pragma mark - State Serialization


- (NSDictionary *)serializeState {
    NSMutableDictionary *state = [[super serializeState] mutableCopy];
    
    if (self.currentSymbol) {
        state[@"currentSymbol"] = self.currentSymbol;
    }
    
    state[@"timeframe"] = @(self.currentTimeframe);
    state[@"tradingHoursMode"] = @(self.tradingHoursMode);  // NUOVO
    state[@"initialBarsToShow"] = @(self.initialBarsToShow);
    state[@"visibleStartIndex"] = @(self.visibleStartIndex);
    state[@"visibleEndIndex"] = @(self.visibleEndIndex);

    return state;
}

- (void)restoreState:(NSDictionary *)state {
    [super restoreState:state];
    
    NSString *symbol = state[@"currentSymbol"];
    if (symbol) {
        [self loadSymbol:symbol];
    }
    
    NSNumber *timeframe = state[@"timeframe"];
    if (timeframe) {
        [self setTimeframe:timeframe.integerValue];
    }
    
    // NUOVO: Restore trading hours mode
    NSNumber *tradingHoursMode = state[@"tradingHoursMode"];
    if (tradingHoursMode) {
        self.tradingHoursMode = tradingHoursMode.integerValue;
    }
    
    NSNumber *initialBarsToShow = state[@"initialBarsToShow"];
    if (initialBarsToShow) {
        self.initialBarsToShow = initialBarsToShow.integerValue;
    }

}

- (void)logViewportState {
    NSLog(@"🔍 Viewport State Debug:");
    NSLog(@"   - Data count: %ld", (long)self.chartData.count);
    NSLog(@"   - Visible range: [%ld-%ld]", (long)self.visibleStartIndex, (long)self.visibleEndIndex);
    NSLog(@"   - Visible bars: %ld", (long)(self.visibleEndIndex - self.visibleStartIndex + 1));
    NSLog(@"   - Initial bars to show: %ld", (long)self.initialBarsToShow);
    
    // Validate ranges
    if (self.visibleStartIndex < 0 || self.visibleEndIndex >= self.chartData.count) {
        NSLog(@"❌ INVALID VIEWPORT: Indices out of bounds!");
    }
    if (self.visibleStartIndex >= self.visibleEndIndex) {
        NSLog(@"❌ INVALID VIEWPORT: Start >= End!");
    }
}


#pragma mark - Smart Symbol Processing - VERSIONE SEMPLIFICATA


- (void)processSmartSymbolInput:(NSString *)input {
    NSLog(@"📝 Processing smart symbol input: '%@'", input);
    
    // ✅ Parse parameters from input
    SmartSymbolParameters params = [self parseSmartSymbolInput:input];
    
    // ✅ Validate symbol
    if (!params.symbol || params.symbol.length == 0) {
        NSLog(@"❌ Invalid symbol in input");
        [self showTemporaryMessage:@"❌ Invalid symbol"];
        return;
    }
    
    // ✅ NEW: Use handlers for coordinated changes
    [self processSmartSymbolParametersWithHandlers:params];
    
    NSLog(@"✅ Smart symbol processing completed for: %@", params.symbol);
}

- (void)processSmartSymbolParametersWithHandlers:(SmartSymbolParameters)params {
    NSLog(@"🎯 Processing smart symbol parameters with handlers");
    
    // Determine what changed to call appropriate handlers
    BOOL symbolChanged = ![params.symbol isEqualToString:self.currentSymbol];
    BOOL timeframeChanged = params.hasTimeframe && (params.timeframe != self.currentTimeframe);
    BOOL daysChanged = params.hasDaysSpecified && (params.daysToDownload != self.currentDateRangeDays);
    
    // ✅ FIX CRITICO: Coordina TUTTI i cambiamenti PRIMA di caricare dati
    
    // STEP 1: Aggiorna TUTTI i parametri senza caricare dati
    if (symbolChanged) {
        NSLog(@"📊 Smart input: Symbol change to %@", params.symbol);
        [self updateSymbolWithoutDataLoad:params.symbol];  // ✅ NUOVO: Non carica dati
    }
    
    if (timeframeChanged) {
        NSLog(@"⏰ Smart input: Timeframe change to %ld", (long)params.timeframe);
        [self updateTimeframeWithoutDataLoad:params.timeframe];  // ✅ NUOVO: Non carica dati
    }
    
    if (daysChanged) {
        NSLog(@"📅 Smart input: Data range change to %ld days", (long)params.daysToDownload);
        [self updateDataRangeWithoutDataLoad:params.daysToDownload];  // ✅ NUOVO: Non carica dati
    }
    
    // STEP 2: UNA SOLA chiamata dati con TUTTI i parametri aggiornati
    if (symbolChanged || timeframeChanged || daysChanged) {
        NSLog(@"🔄 Smart input: Loading data with coordinated parameters");
        [self loadDataWithCurrentSettings];  // ✅ UNA SOLA CHIAMATA
    }
    
    // STEP 3: Broadcast to chain se simbolo è cambiato
    if (symbolChanged) {
        if ([self respondsToSelector:@selector(broadcastSymbolToChain:)]) {
            [self performSelector:@selector(broadcastSymbolToChain:) withObject:params.symbol];
        }
    }
    
    NSLog(@"✅ Smart symbol parameters processed via coordinated handlers");
}

- (void)updateSymbolWithoutDataLoad:(NSString *)newSymbol {
    if ([newSymbol isEqualToString:self.currentSymbol]) {
        NSLog(@"🔄 Chain symbol %@ ignored (duplicate within 300s)", newSymbol);
        return;
    }
    
    NSString *previousSymbol = self.currentSymbol;
    
    // ✅ COORDINATE SYMBOL DEPENDENCIES
    [self coordinateSymbolDependencies:newSymbol];
    
    // ✅ UPDATE CURRENT SYMBOL
    self.currentSymbol = newSymbol;
    
    // ✅ UPDATE UI (but don't load data yet)
    [self processUIUpdate:ChartInvalidationSymbolChange];
    
    NSLog(@"✅ Handler: Symbol change from '%@' to '%@' initiated", previousSymbol ?: @"(none)", newSymbol);
}

// ✅ NUOVO: Aggiorna timeframe senza caricare dati
- (void)updateTimeframeWithoutDataLoad:(BarTimeframe)newTimeframe {
    if (newTimeframe == self.currentTimeframe) {
        NSLog(@"⏭️ Same timeframe, skipping");
        return;
    }
    
    BarTimeframe previousTimeframe = self.currentTimeframe;
    
    // ✅ UPDATE TIMEFRAME
    self.currentTimeframe = newTimeframe;
    
    // ✅ UPDATE DATE RANGE PREFERENCES FOR NEW TIMEFRAME
    if ([self respondsToSelector:@selector(updateDateRangeSegmentedForTimeframe:)]) {
        [self updateDateRangeSegmentedForTimeframe:newTimeframe];
    }
    
    // ✅ RESET VISIBLE RANGE FOR NEW TIMEFRAME
    if ([self respondsToSelector:@selector(resetVisibleRangeForTimeframe)]) {
        [self resetVisibleRangeForTimeframe];
    }
    
    // ✅ UPDATE UI (but don't load data yet)
    [self processUIUpdate:ChartInvalidationTimeframeChange];
    
    NSLog(@"✅ Handler: Timeframe change from %ld to %ld initiated",
          (long)previousTimeframe, (long)newTimeframe);
}

// ✅ NUOVO: Aggiorna data range senza caricare dati
- (void)updateDataRangeWithoutDataLoad:(NSInteger)newDays {
    if (newDays == self.currentDateRangeDays) {
        NSLog(@"⏭️ Same data range, skipping");
        return;
    }
    
    NSInteger previousDays = self.currentDateRangeDays;
    
    // ✅ UPDATE DATA RANGE
    self.currentDateRangeDays = newDays;
    
    // ✅ UPDATE CUSTOM SEGMENT
    if ([self respondsToSelector:@selector(updateCustomSegmentWithDays:)]) {
        [self updateCustomSegmentWithDays:newDays];
    }
    
    // ✅ UPDATE UI (but don't load data yet)
    [self processUIUpdate:ChartInvalidationDataRangeChange];
    
    NSLog(@"✅ Handler: Data range change from %ld to %ld days initiated",
          (long)previousDays, (long)newDays);
}

- (void)updateSymbolTextFieldAfterSmartInput:(SmartSymbolParameters)params {
    // Show only the clean symbol in the text field
    if (self.symbolTextField) {
        self.symbolTextField.stringValue = params.symbol;
    }
    
    // Show feedback about what was applied
    NSMutableString *feedback = [NSMutableString stringWithFormat:@"📊 %@", params.symbol];
    
    if (params.hasTimeframe) {
        [feedback appendFormat:@" • %@", [self timeframeToString:params.timeframe]];
    }
    
    if (params.hasDaysSpecified) {
        [feedback appendFormat:@" • %ld days", (long)params.daysToDownload];
    }
    
    if ([self respondsToSelector:@selector(showTemporaryMessage:)]) {
        [self performSelector:@selector(showTemporaryMessage:) withObject:feedback];
    }
    
    NSLog(@"📱 Updated symbol text field: %@", feedback);
}


- (SmartSymbolParameters)parseSmartSymbolInput:(NSString *)input {
    SmartSymbolParameters params = {0};
    
    // Default values
    params.hasTimeframe = NO;
    params.hasDaysSpecified = NO;
    params.timeframe = self.currentTimeframe;           // Dal timeframeSegmented
    params.daysToDownload = self.currentDateRangeDays;  // Dal dateRangeSlider attuale
    // Split input by comma
    NSArray<NSString *> *components = [input componentsSeparatedByString:@","];
    
    // ✅ COMPONENT 1: Symbol (required)
    if (components.count >= 1) {
        params.symbol = [[components[0] stringByTrimmingCharactersInSet:
                         [NSCharacterSet whitespaceAndNewlineCharacterSet]] uppercaseString];
    }
    
    // ✅ COMPONENT 2: Timeframe (optional)
    if (components.count >= 2) {
        NSString *timeframeStr = [components[1] stringByTrimmingCharactersInSet:
                                  [NSCharacterSet whitespaceAndNewlineCharacterSet]];
        BarTimeframe parsedTimeframe = [self parseTimeframeString:timeframeStr];
        if (parsedTimeframe != -1) {
            params.timeframe = parsedTimeframe;
            params.hasTimeframe = YES;
            NSLog(@"📊 Parsed timeframe: %@ -> %ld", timeframeStr, (long)parsedTimeframe);
        }
    }
    
    // ✅ COMPONENT 3: Days to download (optional)
    if (components.count >= 3) {
        NSString *daysStr = [components[2] stringByTrimmingCharactersInSet:
                            [NSCharacterSet whitespaceAndNewlineCharacterSet]];
        NSInteger days = [self parseDaysString:daysStr];
        if (days > 0) {
            params.daysToDownload = days;
            params.hasDaysSpecified = YES;
            NSLog(@"📅 Parsed days: %@ -> %ld days", daysStr, (long)days);
        }
    }
    
    // ✅ CALCOLA LE DATE (sempre usa date per semplicità)
    params.endDate = [[NSDate date] dateByAddingTimeInterval:86400]; // Domani (include oggi)
    params.startDate = [params.endDate dateByAddingTimeInterval:-(params.daysToDownload * 86400)];
    
    NSLog(@"📝 Parsed parameters - Symbol: %@, TF: %ld, Days: %ld, StartDate: %@, EndDate: %@",
          params.symbol, (long)params.timeframe, (long)params.daysToDownload,
          params.startDate, params.endDate);
    
    return params;
}

- (BarTimeframe)parseTimeframeString:(NSString *)timeframeStr {
    if (!timeframeStr || timeframeStr.length == 0) return -1;
    
    NSString *tf = timeframeStr.lowercaseString;
    
    // ✅ NUMERIC FIRST - Se è solo numero, sono minuti
    NSCharacterSet *nonDigits = [[NSCharacterSet decimalDigitCharacterSet] invertedSet];
    if ([tf rangeOfCharacterFromSet:nonDigits].location == NSNotFound) {
        NSInteger minutes = tf.integerValue;
        switch (minutes) {
            case 1: return BarTimeframe1Min;
            case 5: return BarTimeframe5Min;
            case 15: return BarTimeframe15Min;
            case 30: return BarTimeframe30Min;
            case 60: return BarTimeframe1Hour;
            case 240: return BarTimeframe4Hour;
            default:
                NSLog(@"⚠️ Unsupported numeric timeframe: %ld minutes", (long)minutes);
                return -1;
        }
    }
    
    // ✅ MINUTE SUFFIX (es: 5m, 5min)
    if ([tf hasSuffix:@"m"] || [tf hasSuffix:@"min"]) {
        NSString *numberPart = tf;
        if ([tf hasSuffix:@"min"]) {
            numberPart = [tf substringToIndex:tf.length - 3];
        } else if ([tf hasSuffix:@"m"]) {
            numberPart = [tf substringToIndex:tf.length - 1];
        }
        
        NSInteger minutes = numberPart.integerValue;
        switch (minutes) {
            case 1: return BarTimeframe1Min;
            case 5: return BarTimeframe5Min;
            case 15: return BarTimeframe15Min;
            case 30: return BarTimeframe30Min;
            default:
                NSLog(@"⚠️ Unsupported minute timeframe: %ldm", (long)minutes);
                return -1;
        }
    }
    
    // ✅ HOUR SUFFIX (es: 1h, 4h)
    if ([tf hasSuffix:@"h"]) {
        NSString *hourPart = [tf substringToIndex:tf.length - 1];
        NSInteger hours = hourPart.integerValue;
        switch (hours) {
            case 1: return BarTimeframe1Hour;
            case 4: return BarTimeframe4Hour;
            default:
                NSLog(@"⚠️ Unsupported hour timeframe: %ldh", (long)hours);
                return -1;
        }
    }
    
    // ✅ DAILY+ TIMEFRAMES (single letter or full word)
    if ([tf isEqualToString:@"d"] || [tf isEqualToString:@"daily"]) return BarTimeframeDaily;
    if ([tf isEqualToString:@"w"] || [tf isEqualToString:@"weekly"]) return BarTimeframeWeekly;
    if ([tf isEqualToString:@"m"] || [tf isEqualToString:@"monthly"]) return BarTimeframeMonthly;
    
    NSLog(@"⚠️ Unrecognized timeframe: %@", timeframeStr);
    return -1;
}

- (NSInteger)parseDaysString:(NSString *)daysStr {
    if (!daysStr || daysStr.length == 0) return 0;
    
    NSString *cleanStr = daysStr.lowercaseString;
    
    // ✅ CHECK FOR SUFFIXES (w, m, q, y)
    
    // Weeks
    if ([cleanStr hasSuffix:@"w"]) {
        NSString *numberPart = [cleanStr substringToIndex:cleanStr.length - 1];
        NSInteger weeks = numberPart.integerValue;
        return weeks * 7;  // Semplice: 1 settimana = 7 giorni
    }
    
    // Months (nel componente 3, 'm' = sempre mesi)
    if ([cleanStr hasSuffix:@"m"]) {
        NSString *numberPart = [cleanStr substringToIndex:cleanStr.length - 1];
        NSInteger months = numberPart.integerValue;
        return months * 22;  // Approssimazione: 1 mese = 22 giorni trading
    }
    
    // Quarters
    if ([cleanStr hasSuffix:@"q"]) {
        NSString *numberPart = [cleanStr substringToIndex:cleanStr.length - 1];
        NSInteger quarters = numberPart.integerValue;
        return quarters * 66;  // 3 mesi * 22 giorni = 66 giorni trading
    }
    
    // Years
    if ([cleanStr hasSuffix:@"y"]) {
        NSString *numberPart = [cleanStr substringToIndex:cleanStr.length - 1];
        NSInteger years = numberPart.integerValue;
        return years * 252;  // Standard trading days in a year
    }
    
    // ✅ PLAIN NUMBER = giorni
    NSInteger days = cleanStr.integerValue;
    if (days > 0) {
        return days;
    }
    
    return 0;
}



#pragma mark - StaticMode Implementation (NUOVO)

- (void)setStaticMode:(BOOL)staticMode {
    if (_isStaticMode == staticMode) return;
    
    _isStaticMode = staticMode;
    
    NSLog(@"📋 ChartWidget: StaticMode %@ for symbol %@",
          staticMode ? @"ENABLED" : @"DISABLED", self.currentSymbol ?: @"(none)");
    
    [self updateStaticModeUI];
    
    if (staticMode) {
        [self showStaticModeNotification];
    }
}


- (IBAction)toggleStaticMode:(NSButton *)sender {
    NSLog(@"🔄 IBAction: toggleStaticMode");
    
    BOOL newStaticMode = (sender.state == NSControlStateValueOn);
    
    // ✅ USE HANDLER instead of legacy logic
    [self handleStaticModeToggle:newStaticMode];
    
    NSLog(@"✅ IBAction: toggleStaticMode completed via handler");
}

- (void)updateStaticModeUI {
    // Update toggle button state
    if (self.staticModeToggle) {
        self.staticModeToggle.state = self.isStaticMode ? NSControlStateValueOn : NSControlStateValueOff;
        
        // Update button appearance
        if (self.isStaticMode) {
            self.staticModeToggle.layer.borderColor = [NSColor systemBlueColor].CGColor;
            self.staticModeToggle.layer.borderWidth = 2.0;
        } else {
            self.staticModeToggle.layer.borderColor = [NSColor clearColor].CGColor;
            self.staticModeToggle.layer.borderWidth = 0.0;
        }
    }
    
    // Update content view border (blue highlight like microscope)
    if (self.isStaticMode) {
        self.mainSplitView.wantsLayer = YES;
        self.mainSplitView.layer.borderColor = [NSColor systemBlueColor].CGColor;
        self.mainSplitView.layer.borderWidth = 2.0;
        self.mainSplitView.layer.cornerRadius = 4.0;
    } else {
        self.mainSplitView.layer.borderColor = [NSColor clearColor].CGColor;
        self.mainSplitView.layer.borderWidth = 0.0;
    }
    
    [self updateSearchFieldForMode];

}

- (void)showStaticModeNotification {
    // ✅ CHANGED: Updated notification message
    // Trova il primo panel per mostrare il messaggio
    ChartPanelView *targetPanel = self.chartPanels.firstObject;
    if (!targetPanel) return;
    
    // Crea messaggio temporaneo
    NSTextField *notificationLabel = [[NSTextField alloc] init];
    notificationLabel.stringValue = @"📋 STATIC MODE - No Data Updates";
    notificationLabel.font = [NSFont boldSystemFontOfSize:14];
    notificationLabel.textColor = [NSColor systemBlueColor];
    notificationLabel.backgroundColor = [[NSColor systemBlueColor] colorWithAlphaComponent:0.1];
    notificationLabel.bordered = YES;
    notificationLabel.bezeled = YES;
    notificationLabel.editable = NO;
    notificationLabel.selectable = NO;
    notificationLabel.alignment = NSTextAlignmentCenter;
    
    // Posiziona al centro del panel
    notificationLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [targetPanel addSubview:notificationLabel];
    
    [NSLayoutConstraint activateConstraints:@[
        [notificationLabel.centerXAnchor constraintEqualToAnchor:targetPanel.centerXAnchor],
        [notificationLabel.topAnchor constraintEqualToAnchor:targetPanel.topAnchor constant:10],
        [notificationLabel.widthAnchor constraintEqualToConstant:280],
        [notificationLabel.heightAnchor constraintEqualToConstant:30]
    ]];
    
    // Rimuovi dopo 3 secondi
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [notificationLabel removeFromSuperview];
    });
    
    NSLog(@"📋 Showed StaticMode notification to user");
}

#pragma mark - Chart Data Access

- (NSArray<HistoricalBarModel *> *)currentChartData {
    return self.chartData;  // Direct access since we're in the main implementation
}

#pragma mark - New Loading Method with Date Range


- (void)loadSymbolWithDateRange:(SmartSymbolParameters)params {
    
    // Determine if we need extended hours
    BOOL needExtendedHours = (self.tradingHoursMode == ChartTradingHoursWithAfterHours);
    
    NSLog(@"📊 ChartWidget: Loading %@ from %@ to %@ (timeframe: %ld, after-hours: %@)",
          params.symbol, params.startDate, params.endDate,
          (long)params.timeframe, needExtendedHours ? @"YES" : @"NO");
    
    if (self.isStaticMode) {
        NSLog(@"⚠️ Chart in static mode, skipping data load");
        return;
    }
    
    // ✅ USA IL METODO DataHub CON DATE DIRETTE!
    [[DataHub shared] getHistoricalBarsForSymbol:params.symbol
                                       timeframe:params.timeframe
                                       startDate:params.startDate
                                         endDate:params.endDate
                              needExtendedHours:needExtendedHours
                                     completion:^(NSArray<HistoricalBarModel *> *data, BOOL isFresh) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (!data || data.count == 0) {
                NSLog(@"❌ ChartWidget: No data received for %@", params.symbol);
                return;
            }
            
            NSLog(@"✅ ChartWidget: Received %lu bars for %@ (%@)",
                  (unsigned long)data.count, params.symbol, isFresh ? @"FRESH" : @"CACHED");
            
            // ✅ FIX CRITICO: Simula una notification per entrare nel flusso corretto
            NSDictionary *userInfo = @{
                @"symbol": params.symbol,
                @"bars": data,
                @"isFresh": @(isFresh),
                @"source": @"loadSymbolWithDateRange"  // Per debug
            };
            
            NSNotification *syntheticNotification = [NSNotification notificationWithName:DataHubDataLoadedNotification
                                                                                   object:self  // Passiamo self come object
                                                                                 userInfo:userInfo];
            
            NSLog(@"🔄 Calling handleHistoricalDataUpdate via synthetic notification");
            [self handleHistoricalDataUpdate:syntheticNotification];
            
            NSLog(@"✅ Data processing completed via unified pipeline");
        });
    }];
}

#pragma mark - Helper Methods

- (void)loadSymbol:(NSString *)symbol {
    NSLog(@"🔄 Advanced: Public loadSymbol called for '%@'", symbol);
    
    if (!symbol || symbol.length == 0) {
        NSLog(@"⚠️ Cannot load empty symbol");
        return;
    }
    
    // ✅ USE HANDLER with force reload (public method should always reload)
    [self handleSymbolChange:symbol forceReload:YES];
    
    NSLog(@"✅ Advanced: Public loadSymbol completed via handler");
}

- (void)setTimeframe:(BarTimeframe)timeframe {
    NSLog(@"🔄 Advanced: Public setTimeframe called for %ld", (long)timeframe);
    
    // ✅ USE HANDLER instead of legacy logic
    [self handleTimeframeChange:timeframe];
    
    NSLog(@"✅ Advanced: Public setTimeframe completed via handler");
}


- (NSString *)timeframeDisplayName:(BarTimeframe)timeframe {
    switch (timeframe) {
        case BarTimeframe1Min: return @"1min";
        case BarTimeframe5Min: return @"5min";
        case BarTimeframe15Min: return @"15min";
        case BarTimeframe30Min: return @"30min";
        case BarTimeframe1Hour: return @"1H";
        case BarTimeframe4Hour: return @"4H";
        case BarTimeframeDaily: return @"Daily";
        case BarTimeframeWeekly: return @"Weekly";
        case BarTimeframeMonthly: return @"Monthly";
        default: return @"Unknown";
    }
}

#pragma mark - Date Range Management (🆕 NEW)

- (void)loadDateRangeDefaults {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    // Load download defaults (with fallbacks)
    self.defaultDaysFor1Min = [defaults integerForKey:@"ChartWidget_DefaultDays1Min"];
    if (self.defaultDaysFor1Min < 1) self.defaultDaysFor1Min = 20;
    
    self.defaultDaysFor5Min = [defaults integerForKey:@"ChartWidget_DefaultDays5Min"];
    if (self.defaultDaysFor5Min < 1) self.defaultDaysFor5Min = 40;
    
    self.defaultDaysForHourly = [defaults integerForKey:@"ChartWidget_DefaultDaysHourly"];
    if (self.defaultDaysForHourly < 1) self.defaultDaysForHourly = 999999; // max available
    
    self.defaultDaysForDaily = [defaults integerForKey:@"ChartWidget_DefaultDaysDaily"];
    if (self.defaultDaysForDaily < 1) self.defaultDaysForDaily = 180; // 6 months
    
    self.defaultDaysForWeekly = [defaults integerForKey:@"ChartWidget_DefaultDaysWeekly"];
    if (self.defaultDaysForWeekly < 1) self.defaultDaysForWeekly = 365; // 1 year
    
    self.defaultDaysForMonthly = [defaults integerForKey:@"ChartWidget_DefaultDaysMonthly"];
    if (self.defaultDaysForMonthly < 1) self.defaultDaysForMonthly = 1825; // 5 years
    
    // Load visible defaults
    self.defaultVisibleFor1Min = [defaults integerForKey:@"ChartWidget_DefaultVisible1Min"];
    if (self.defaultVisibleFor1Min < 1) self.defaultVisibleFor1Min = 5; // 5 days visible
    
    self.defaultVisibleFor5Min = [defaults integerForKey:@"ChartWidget_DefaultVisible5Min"];
    if (self.defaultVisibleFor5Min < 1) self.defaultVisibleFor5Min = 10; // 10 days visible
    
    self.defaultVisibleForHourly = [defaults integerForKey:@"ChartWidget_DefaultVisibleHourly"];
    if (self.defaultVisibleForHourly < 1) self.defaultVisibleForHourly = 30; // 30 days visible
    
    self.defaultVisibleForDaily = [defaults integerForKey:@"ChartWidget_DefaultVisibleDaily"];
    if (self.defaultVisibleForDaily < 1) self.defaultVisibleForDaily = 90; // 3 months visible
    
    self.defaultVisibleForWeekly = [defaults integerForKey:@"ChartWidget_DefaultVisibleWeekly"];
    if (self.defaultVisibleForWeekly < 1) self.defaultVisibleForWeekly = 180; // 6 months visible
    
    self.defaultVisibleForMonthly = [defaults integerForKey:@"ChartWidget_DefaultVisibleMonthly"];
    if (self.defaultVisibleForMonthly < 1) self.defaultVisibleForMonthly = 365; // 1 year visible
    
    NSLog(@"📂 Loaded date range defaults - 1m:%ld, 5m:%ld, hourly:%ld, daily:%ld, weekly:%ld, monthly:%ld",
          (long)self.defaultDaysFor1Min, (long)self.defaultDaysFor5Min, (long)self.defaultDaysForHourly,
          (long)self.defaultDaysForDaily, (long)self.defaultDaysForWeekly, (long)self.defaultDaysForMonthly);
}

- (void)saveDateRangeDefaults {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    // Save download defaults
    [defaults setInteger:self.defaultDaysFor1Min forKey:@"ChartWidget_DefaultDays1Min"];
    [defaults setInteger:self.defaultDaysFor5Min forKey:@"ChartWidget_DefaultDays5Min"];
    [defaults setInteger:self.defaultDaysForHourly forKey:@"ChartWidget_DefaultDaysHourly"];
    [defaults setInteger:self.defaultDaysForDaily forKey:@"ChartWidget_DefaultDaysDaily"];
    [defaults setInteger:self.defaultDaysForWeekly forKey:@"ChartWidget_DefaultDaysWeekly"];
    [defaults setInteger:self.defaultDaysForMonthly forKey:@"ChartWidget_DefaultDaysMonthly"];
    
    // Save visible defaults
    [defaults setInteger:self.defaultVisibleFor1Min forKey:@"ChartWidget_DefaultVisible1Min"];
    [defaults setInteger:self.defaultVisibleFor5Min forKey:@"ChartWidget_DefaultVisible5Min"];
    [defaults setInteger:self.defaultVisibleForHourly forKey:@"ChartWidget_DefaultVisibleHourly"];
    [defaults setInteger:self.defaultVisibleForDaily forKey:@"ChartWidget_DefaultVisibleDaily"];
    [defaults setInteger:self.defaultVisibleForWeekly forKey:@"ChartWidget_DefaultVisibleWeekly"];
    [defaults setInteger:self.defaultVisibleForMonthly forKey:@"ChartWidget_DefaultVisibleMonthly"];
    
    [defaults synchronize];
    
    NSLog(@"💾 Saved date range defaults to User Defaults");
}

- (NSInteger)getMinDaysForTimeframe:(BarTimeframe)timeframe {
    switch (timeframe) {
        case BarTimeframe1Min:
        case BarTimeframe5Min:
        case BarTimeframe15Min:
        case BarTimeframe30Min:
        case BarTimeframe1Hour:
        case BarTimeframe4Hour:
            return 1; // Minimum 1 day for intraday
            
        case BarTimeframeDaily:
        case BarTimeframeWeekly:
        case BarTimeframeMonthly:
        default:
            return 10; // Minimum 10 days for daily+
    }
}

- (NSInteger)getMaxDaysForTimeframe:(BarTimeframe)timeframe {
    switch (timeframe) {
        case BarTimeframe1Min:
            return 100;
            
        case BarTimeframe5Min:
        case BarTimeframe15Min:
        case BarTimeframe30Min:
        case BarTimeframe1Hour:
        case BarTimeframe4Hour:
            return 370;
            
        case BarTimeframeDaily:
        case BarTimeframeWeekly:
        case BarTimeframeMonthly:
        default:
            return 99999999;
    }
}

- (NSInteger)getDefaultDaysForTimeframe:(BarTimeframe)timeframe {
    switch (timeframe) {
        case BarTimeframe1Min:
            return self.defaultDaysFor1Min;
            
        case BarTimeframe5Min:
        case BarTimeframe15Min:
        case BarTimeframe30Min:
            return self.defaultDaysFor5Min;
            
        case BarTimeframe1Hour:
        case BarTimeframe4Hour:
            return self.defaultDaysForHourly;
            
        case BarTimeframeDaily:
            return self.defaultDaysForDaily;
            
        case BarTimeframeWeekly:
            return self.defaultDaysForWeekly;
            
        case BarTimeframeMonthly:
        default:
            return self.defaultDaysForMonthly;
    }
}

- (NSInteger)getDefaultVisibleDaysForTimeframe:(BarTimeframe)timeframe {
    switch (timeframe) {
        case BarTimeframe1Min:
            return self.defaultVisibleFor1Min;
            
        case BarTimeframe5Min:
        case BarTimeframe15Min:
        case BarTimeframe30Min:
            return self.defaultVisibleFor5Min;
            
        case BarTimeframe1Hour:
        case BarTimeframe4Hour:
            return self.defaultVisibleForHourly;
            
        case BarTimeframeDaily:
            return self.defaultVisibleForDaily;
            
        case BarTimeframeWeekly:
            return self.defaultVisibleForWeekly;
            
        case BarTimeframeMonthly:
        default:
            return self.defaultVisibleForMonthly;
    }
}


- (void)loadDataWithCurrentSettings {
    if (!self.currentSymbol || self.currentSymbol.length == 0) return;
    
    // Calculate date range from slider value
    NSDate *endDate = [[NSDate date] dateByAddingTimeInterval:86400]; // Tomorrow
    NSDate *startDate = [endDate dateByAddingTimeInterval:-(self.currentDateRangeDays * 86400)];
    
    // Create smart symbol parameters
    SmartSymbolParameters params = {0};
    params.symbol = self.currentSymbol;
    params.timeframe = self.currentTimeframe;
    params.daysToDownload = self.currentDateRangeDays;
    params.startDate = startDate;
    params.endDate = endDate;
    params.hasTimeframe = YES;
    params.hasDaysSpecified = YES;
    
    // Load data
    [self loadSymbolWithDateRange:params];
    
    NSLog(@"🔄 Loading data with current settings - Symbol: %@, Days: %ld, Timeframe: %ld",
          self.currentSymbol, (long)self.currentDateRangeDays, (long)self.currentTimeframe);
}

#pragma mark - Symbol Coordination (NEW)

- (void)setCurrentSymbol:(NSString *)currentSymbol {
    // Evita lavoro inutile se è lo stesso symbol
    if ([currentSymbol isEqualToString:_currentSymbol]) {
        return;
    }
    // Aggiorna il symbol
    _currentSymbol = currentSymbol;
    
    // 1. Coordina ObjectsManager se esiste
    if (self.objectsManager) {
        self.objectsManager.currentSymbol = currentSymbol;
        NSLog(@"✅ ChartWidget: Updated ObjectsManager for symbol '%@'", currentSymbol);
    }
    
    // 2. Refresh alerts per il nuovo symbol
    [self refreshAlertsForCurrentSymbol];
    
    // 3. Aggiorna ObjectManagerWindow se aperta
    if (self.objectsPanel && self.objectsPanel.objectManagerWindow) {
        [self.objectsPanel.objectManagerWindow updateForSymbol:currentSymbol];
    }
    
    NSLog(@"✅ ChartWidget: Symbol coordination completed for '%@'", currentSymbol);
}


#pragma mark - Chart Pattern Loading (NUOVO)

- (void)loadChartPatternFromChainData:(NSDictionary *)data fromWidget:(BaseWidget *)sender {
    NSLog(@"🔄 Advanced: Loading chart pattern from chain data");
    
    // ✅ Validation
    if (!data || ![data isKindOfClass:[NSDictionary class]]) {
        NSLog(@"❌ Invalid chart pattern data received from %@", NSStringFromClass([sender class]));
        return;
    }
    
    // ✅ Extract pattern data
    NSString *patternID = data[@"patternID"];
    NSString *symbol = data[@"symbol"];
    NSString *savedDataReference = data[@"savedDataReference"];
    NSDate *patternStartDate = data[@"patternStartDate"];
    NSDate *patternEndDate = data[@"patternEndDate"];
    NSString *patternType = data[@"patternType"];
    
    // ✅ Validate essential data
    if (!patternID || !savedDataReference || !symbol) {
        NSLog(@"❌ Missing essential pattern data - patternID:%@ savedDataRef:%@ symbol:%@",
              patternID, savedDataReference, symbol);
        [self showChartPatternLoadError:@"Missing essential pattern data"];
        return;
    }
    
    NSLog(@"🔗 Loading chart pattern '%@' (%@) from %@",
          patternType ?: @"Unknown", symbol, NSStringFromClass([sender class]));
    
    // ✅ Load SavedChartData
    NSString *directory = [ChartWidget savedChartDataDirectory];
    NSString *filename = [NSString stringWithFormat:@"%@.chartdata", savedDataReference];
    NSString *filePath = [directory stringByAppendingPathComponent:filename];
    
    SavedChartData *savedData = [SavedChartData loadFromFile:filePath];
    if (!savedData || !savedData.isDataValid) {
        NSLog(@"❌ Failed to load SavedChartData for pattern %@", patternID);
        [self showChartPatternLoadError:@"Could not load chart data for this pattern"];
        return;
    }
    
    // ✅ USE HANDLERS for pattern loading instead of manual logic
    [self loadChartPatternWithHandlers:savedData
                       patternStartDate:patternStartDate
                         patternEndDate:patternEndDate
                            patternType:patternType
                             fromSender:sender];
}

- (void)loadChartPatternWithHandlers:(SavedChartData *)savedData
                     patternStartDate:(NSDate *)patternStartDate
                       patternEndDate:(NSDate *)patternEndDate
                          patternType:(NSString *)patternType
                           fromSender:(BaseWidget *)sender {
    
    dispatch_async(dispatch_get_main_queue(), ^{
        NSLog(@"🔄 Pattern: Loading with handler system");
        
        // 1️⃣ ENABLE STATIC MODE using handler
        [self handleStaticModeToggle:YES];
        
        // 2️⃣ UPDATE SYMBOL AND TIMEFRAME using handlers
        [self handleSymbolChange:savedData.symbol forceReload:NO];
        [self handleTimeframeChange:savedData.timeframe];
        
        // 3️⃣ LOAD HISTORICAL DATA using common processing node
        [self processNewHistoricalData:savedData.historicalBars
                         invalidations:ChartInvalidationData | ChartInvalidationIndicators | ChartInvalidationViewport];
        
        // 4️⃣ SET VISIBLE RANGE TO PATTERN DATES
        if (patternStartDate && patternEndDate) {
            [self setVisibleRangeToPatternDates:patternStartDate
                                        endDate:patternEndDate
                                      chartData:savedData.historicalBars];
        }
        
        // 5️⃣ FEEDBACK TO USER
        NSString *senderType = NSStringFromClass([sender class]);
        NSString *feedbackMessage = [NSString stringWithFormat:@"📊 Loaded %@ pattern (%@)",
                                    patternType ?: @"Unknown", senderType];
        [self showTemporaryMessage:feedbackMessage];
        
        NSLog(@"✅ Pattern loaded via handler system: %@", feedbackMessage);
    });
}

- (void)setVisibleRangeToPatternDates:(NSDate *)startDate
                              endDate:(NSDate *)endDate
                            chartData:(NSArray<HistoricalBarModel *> *)chartData {
    
    if (!startDate || !endDate || !chartData || chartData.count == 0) {
        NSLog(@"⚠️ ChartWidget: Cannot set pattern range - invalid parameters");
        return;
    }
    
    // Trova gli indici corrispondenti alle date del pattern
    NSInteger startIndex = -1, endIndex = -1;
    
    for (NSInteger i = 0; i < chartData.count; i++) {
        HistoricalBarModel *bar = chartData[i];
        
        // Trova primo bar >= startDate
        if (startIndex == -1 && [bar.date compare:startDate] != NSOrderedAscending) {
            startIndex = i;
        }
        
        // Trova ultimo bar <= endDate
        if ([bar.date compare:endDate] != NSOrderedDescending) {
            endIndex = i;
        }
    }
    
    // Validazione indici trovati
    if (startIndex == -1 || endIndex == -1 || startIndex > endIndex) {
        NSLog(@"⚠️ ChartWidget: Pattern dates outside chart data range - using full range");
        return;
    }
    
    // Aggiungi padding per migliore visualizzazione (10% su ogni lato)
    NSInteger totalBars = chartData.count;
    NSInteger patternBars = endIndex - startIndex + 1;
    NSInteger padding = MAX(1, patternBars / 10);
    
    NSInteger paddedStartIndex = MAX(0, startIndex - padding);
    NSInteger paddedEndIndex = MIN(totalBars - 1, endIndex + padding);
    
    // Applica il range visibile
    self.visibleStartIndex = paddedStartIndex;
    self.visibleEndIndex = paddedEndIndex;
    
    NSLog(@"📊 ChartWidget: Set visible range to pattern dates - bars [%ld-%ld] with padding (pattern: [%ld-%ld])",
          (long)paddedStartIndex, (long)paddedEndIndex, (long)startIndex, (long)endIndex);
    
    // Aggiorna viewport e sincronizza panel
    [self updateViewport];
    [self synchronizePanels];
}

#pragma mark - Error Handling (NUOVO)

- (void)showChartPatternLoadError:(NSString *)errorMessage {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSAlert *alert = [[NSAlert alloc] init];
        alert.messageText = @"Chart Pattern Load Error";
        alert.informativeText = errorMessage ?: @"An unknown error occurred while loading the chart pattern.";
        alert.alertStyle = NSAlertStyleWarning;
        [alert addButtonWithTitle:@"OK"];
        
        // Mostra l'alert sulla finestra del chart widget se disponibile
        if (self.view.window) {
            [alert beginSheetModalForWindow:self.view.window completionHandler:nil];
        } else {
            [alert runModal];
        }
    });
}


- (void)updateWithHistoricalBars:(NSArray<HistoricalBarModel *> *)bars {
    NSLog(@"🔄 Advanced: updateWithHistoricalBars with %ld bars", (long)bars.count);
    
    if (!bars || bars.count == 0) {
        NSLog(@"⚠️ updateWithHistoricalBars called with no data");
        return;
    }
    
    // ✅ USE COMMON PROCESSING NODE with standard invalidations
    [self processNewHistoricalData:bars
                     invalidations:ChartInvalidationData | ChartInvalidationIndicators | ChartInvalidationViewport];
    
    NSLog(@"✅ Advanced: updateWithHistoricalBars completed via handler system");
}


#pragma mark - 🆕 NEW: Persistence Methods

- (void)loadDateRangeSegmentedDefaults {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    // Carica il segmento selezionato (default: 6M = segmento 3)
    self.selectedDateRangeSegment = [defaults integerForKey:@"ChartWidget_SelectedDateRangeSegment"];
    if (self.selectedDateRangeSegment < 0 || self.selectedDateRangeSegment >= 8) {
        self.selectedDateRangeSegment = 3; // Default: 6M
    }
    
    // Carica il valore custom (default: 100 giorni)
    self.customDateRangeDays = [defaults integerForKey:@"ChartWidget_CustomDateRangeDays"];
    if (self.customDateRangeDays < 1) {
        self.customDateRangeDays = 100;
    }
    
    // Carica il titolo custom
    NSString *savedTitle = [defaults stringForKey:@"ChartWidget_CustomSegmentTitle"];
    if (savedTitle && savedTitle.length > 0) {
        self.customSegmentTitle = savedTitle;
        [self.dateRangeSegmented setLabel:savedTitle forSegment:0];
    } else {
        // Genera il titolo dalla quantità di giorni
        self.customSegmentTitle = [self formatDaysToAbbreviation:self.customDateRangeDays];
        [self.dateRangeSegmented setLabel:self.customSegmentTitle forSegment:0];
    }
    
    // Imposta la selezione corrente
    self.dateRangeSegmented.selectedSegment = self.selectedDateRangeSegment;
    self.currentDateRangeDays = [self getDaysForSegment:self.selectedDateRangeSegment];
    
    NSLog(@"📱 Loaded date range defaults: segment %ld, custom %ld days ('%@')",
          (long)self.selectedDateRangeSegment, (long)self.customDateRangeDays, self.customSegmentTitle);
}

- (void)saveDateRangeSegmentedDefaults {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    [defaults setInteger:self.selectedDateRangeSegment forKey:@"ChartWidget_SelectedDateRangeSegment"];
    [defaults setInteger:self.customDateRangeDays forKey:@"ChartWidget_CustomDateRangeDays"];
    [defaults setObject:self.customSegmentTitle forKey:@"ChartWidget_CustomSegmentTitle"];
    
    [defaults synchronize];
    
    NSLog(@"💾 Saved date range defaults: segment %ld, custom %ld days ('%@')",
          (long)self.selectedDateRangeSegment, (long)self.customDateRangeDays, self.customSegmentTitle ?: @"nil");
}

#pragma mark - 🆕 NEW: Date Range Segmented Actions

- (void)dateRangeSegmentChanged:(id)sender {
    NSInteger selectedSegment = self.dateRangeSegmented.selectedSegment;
    self.selectedDateRangeSegment = selectedSegment;
    
    // Calcola i giorni per il segmento selezionato
    NSInteger days = [self getDaysForSegment:selectedSegment];
    self.currentDateRangeDays = days;
    
    // Salva la selezione
    [self saveDateRangeSegmentedDefaults];
    
    // 🔧 FIX: NON resettare il visible range quando cambia solo il data range
    // L'utente mantiene lo stesso zoom level, ma ottiene più/meno dati storici
    
    // Ricarica i dati se abbiamo un simbolo
    if (self.currentSymbol && self.currentSymbol.length > 0) {
        [self loadDataWithCurrentSettings];
    }
    
    NSLog(@"📅 Date range segment changed to %ld (%ld days) - visible range preserved",
          (long)selectedSegment, (long)days);
}


- (NSInteger)getDaysForSegment:(NSInteger)segment {
    switch (segment) {
        case 0: return self.customDateRangeDays;    // CUSTOM
        case 1: return 30;                          // 1M
        case 2: return 90;                          // 3M
        case 3: return 180;                         // 6M
        case 4: return 365;                         // 1Y
        case 5: return 1825;                        // 5Y
        case 6: return 3650;                        // 10Y
        case 7: return [self getMaxDaysForTimeframe:self.currentTimeframe]; // MAX
        default: return 130; // Default 6M
    }
}

- (void)updateDateRangeSegmentedForTimeframe:(BarTimeframe)timeframe {
    // 🆕 NEW: Ottieni il valore di default dalle preferenze
    NSInteger preferenceDefault = [self getDefaultDaysForTimeframe:timeframe];
    
    // ✅ MANTIENI: Tutta questa logica esistente per disable/enable
    BOOL isIntraday = (timeframe < BarTimeframeDaily);
    NSInteger maxDaysForTimeframe = [self getMaxDaysForTimeframe:timeframe];
    
    for (NSInteger i = 0; i < self.dateRangeSegmented.segmentCount; i++) {
        NSInteger segmentDays = [self getDaysForSegment:i];
        BOOL shouldEnable = (segmentDays <= maxDaysForTimeframe);
        [self.dateRangeSegmented setEnabled:shouldEnable forSegment:i];
        
        if (!shouldEnable && isIntraday) {
            NSLog(@"⚠️ Segment %ld disabled for intraday (needs %ld days, max %ld)",
                  (long)i, (long)segmentDays, (long)maxDaysForTimeframe);
        }
    }
    
    // 🚀 SOSTITUISCI: Solo questa parte - usa sempre CUSTOM
    [self updateCustomSegmentWithDays:preferenceDefault];
    
    NSLog(@"📊 Updated date range segments for timeframe %ld: using preferences default %ld days in CUSTOM segment",
          (long)timeframe, (long)preferenceDefault);
}


#pragma mark - 🆕 NEW: Custom Segment Management

- (void)updateCustomSegmentWithDays:(NSInteger)days {
    // Aggiorna il valore custom
    self.customDateRangeDays = days;
    
    // Formatta il titolo abbreviato
    NSString *abbreviation = [self formatDaysToAbbreviation:days];
    self.customSegmentTitle = abbreviation;
    
    // Aggiorna la label del segmento CUSTOM
    [self.dateRangeSegmented setLabel:abbreviation forSegment:0];
    
    // Imposta il segmento CUSTOM come selezionato
    self.dateRangeSegmented.selectedSegment = 0;
    self.selectedDateRangeSegment = 0;
    self.currentDateRangeDays = days;
    
    // Ri-applica lo styling al segmento CUSTOM
    [self styleCustomSegment];
    
    // Salva le preferenze
    [self saveDateRangeSegmentedDefaults];
    
    NSLog(@"🔵 Custom segment updated: %ld days → '%@'", (long)days, abbreviation);
}

- (NSString *)formatDaysToAbbreviation:(NSInteger)days {
    if (days < 30) {
        return [NSString stringWithFormat:@"%ldD", (long)days];
    } else if (days < 250) {
        NSInteger months = (days + 11) / 22; // Approssimazione mesi trading (22 giorni/mese)
        return [NSString stringWithFormat:@"%ldM", (long)months];
    } else {
        NSInteger years = (days + 124) / 250; // Approssimazione anni trading (250 giorni/anno)
        return [NSString stringWithFormat:@"%ldY", (long)years];
    }
}


#pragma mark - view resize update sharedX coord


- (void)viewDidLayout {
    [super viewDidLayout];
    
    // ✅ Questo viene chiamato ogni volta che il layout del view controller cambia
    if (self.chartData && self.chartData.count > 0) {
        [self updateSharedXContext];
        [self synchronizePanels];
        
        NSLog(@"📐 ChartWidget viewDidLayout - SharedXContext updated");
    }
}

// ✅ FIX 2: In ChartWidget.m - Override viewWillLayout per intercettare PRIMA del layout
- (void)viewWillLayout {
    [super viewWillLayout];
    
    // ✅ Store current width to detect changes
    static CGFloat lastKnownWidth = 0;
    CGFloat currentWidth = self.view.bounds.size.width;
    
    if (lastKnownWidth != 0 && fabs(lastKnownWidth - currentWidth) > 1.0) {
        NSLog(@"📐 ChartWidget width will change: %.1f → %.1f", lastKnownWidth, currentWidth);
    }
    
    lastKnownWidth = currentWidth;
}


- (void)chartViewFrameDidChange:(NSNotification *)notification {
    if (![notification.object isEqualTo:self.panelsSplitView]) {
        return;
    }
    // ✅ Questo viene chiamato quando il frame del view cambia
    if (self.chartData && self.chartData.count > 0) {
        [self updateSharedXContext];
        [self synchronizePanels];
        
        NSLog(@"📐 ChartWidget frame changed via notification - coordinates updated");
    }
}



- (void)splitViewFrameDidChange:(NSNotification *)notification {
    // ✅ Questo viene chiamato quando il split view cambia dimensioni
    if (self.chartData && self.chartData.count > 0) {
        [self updateSharedXContext];
        [self synchronizePanels];
        
        NSLog(@"📐 PanelsSplitView frame changed - coordinates updated");
    }
}



// ✅ MIGLIORE PRATICA: Metodo centralizzato per update coordinate
- (void)updateCoordinatesIfNeeded:(NSString *)source {
    if (!self.chartData || self.chartData.count == 0) {
        return;
    }
    
    CGFloat currentSplitWidth = self.panelsSplitView.bounds.size.width;
    CGFloat contextWidth = self.sharedXContext.containerWidth;
    
    // Solo se c'è una differenza significativa
    if (fabs(currentSplitWidth - contextWidth) > 1.0) {
        NSLog(@"📐 Coordinate update needed from %@ - Split: %.1f, Context: %.1f",
              source, currentSplitWidth, contextWidth);
        
        [self updateSharedXContext];
        [self synchronizePanels];
    } else {
        NSLog(@"📐 No coordinate update needed from %@ - widths match", source);
    }
}
#pragma mark - indicator visibility


- (IBAction)indicatorsVisibilityToggled:(id)sender {
    NSButton *toggle = (NSButton *)sender;
    NSLog(@"🎯 Indicators visibility toggled: %@",
          toggle.state == NSControlStateValueOn ? @"VISIBLE" : @"HIDDEN");
    
    // Simply trigger indicator update - panels will check visibility internally
    if (self.currentChartData) {
        [self updateIndicatorsWithChartData:self.currentChartData];
    }
}


@end
