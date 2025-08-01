//
//  ConnectionEditController.m
//  mafia_AI
//

#import "ConnectionEditController.h"
#import "ConnectionModel.h"
#import "DataHub+Connections.h"
#import <objc/runtime.h>

@interface ConnectionEditController ()

// UI Elements - Tab 1: Basic
@property (nonatomic, strong) NSTextField *titleField;
@property (nonatomic, strong) NSTextField *symbolsField;
@property (nonatomic, strong) NSComboBox *typeComboBox;
@property (nonatomic, strong) NSSegmentedControl *directionSegmented;

// UI Elements - Tab 2: Strength
@property (nonatomic, strong) NSSlider *initialSlider;
@property (nonatomic, strong) NSTextField *initialValueLabel;
@property (nonatomic, strong) NSButton *enableDecayCheckbox;
@property (nonatomic, strong) NSSlider *decaySlider;
@property (nonatomic, strong) NSDatePicker *horizonPicker;
@property (nonatomic, strong) NSButton *autoDeleteCheckbox;

// UI Elements - Tab 3: Content
@property (nonatomic, strong) NSTextField *urlField;
@property (nonatomic, strong) NSScrollView *descScrollView;
@property (nonatomic, strong) NSScrollView *notesScrollView;

// UI Elements - Tab 4: Advanced
@property (nonatomic, strong) NSTextField *tagsField;

// Main containers
@property (nonatomic, strong) NSTabView *tabView;

@end

@implementation ConnectionEditController

#pragma mark - Factory Methods

+ (instancetype)controllerForCreating {
    ConnectionEditController *controller = [[self alloc] init];
    controller.connectionModel = nil; // Create mode
    return controller;
}

+ (instancetype)controllerForEditing:(ConnectionModel *)connectionModel {
    ConnectionEditController *controller = [[self alloc] init];
    controller.connectionModel = connectionModel; // Edit mode
    return controller;
}

#pragma mark - Lifecycle

- (instancetype)init {
    // Create window
    NSWindow *window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 500, 450)
                                                   styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable
                                                     backing:NSBackingStoreBuffered
                                                       defer:NO];
    
    self = [super initWithWindow:window];
    if (self) {
        [self setupWindow];
        [self setupUI];
    }
    return self;
}

- (BOOL)isEditing {
    return self.connectionModel != nil;
}

#pragma mark - Setup

- (void)setupWindow {
    NSWindow *window = self.window;
    window.title = self.isEditing ? @"Edit Connection" : @"Create New Connection";
    window.level = NSFloatingWindowLevel;
    [window center];
}

- (void)setupUI {
    NSView *containerView = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 500, 450)];
    
    // Create tab view
    self.tabView = [[NSTabView alloc] initWithFrame:NSMakeRect(20, 60, 460, 350)];
    
    [self setupBasicTab];
    [self setupStrengthTab];
    [self setupContentTab];
    [self setupAdvancedTab];
    
    [containerView addSubview:self.tabView];
    
    // Bottom buttons
    [self setupBottomButtons:containerView];
    
    self.window.contentView = containerView;
    
    // Populate fields if editing
    if (self.isEditing) {
        [self populateFieldsFromConnection];
    }
}

- (void)setupBasicTab {
    NSTabViewItem *basicTab = [[NSTabViewItem alloc] initWithIdentifier:@"basic"];
    basicTab.label = @"Basic";
    NSView *basicView = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 440, 320)];
    
    CGFloat yPos = 280;
    
    // Title section
    NSTextField *titleLabel = [self createLabel:@"Connection Title:" at:NSMakePoint(20, yPos)];
    [basicView addSubview:titleLabel];
    
    yPos -= 25;
    self.titleField = [[NSTextField alloc] initWithFrame:NSMakeRect(20, yPos, 400, 24)];
    self.titleField.placeholderString = @"e.g., Apple-Microsoft AI Partnership";
    [basicView addSubview:self.titleField];
    
    // Symbols section
    yPos -= 40;
    NSTextField *symbolsLabel = [self createLabel:@"Symbols:" at:NSMakePoint(20, yPos)];
    [basicView addSubview:symbolsLabel];
    
    yPos -= 25;
    self.symbolsField = [[NSTextField alloc] initWithFrame:NSMakeRect(20, yPos, 300, 24)];
    self.symbolsField.placeholderString = @"AAPL, MSFT, GOOGL";
    [basicView addSubview:self.symbolsField];
    
    // Validate symbols button
    NSButton *validateButton = [[NSButton alloc] initWithFrame:NSMakeRect(330, yPos, 90, 24)];
    validateButton.title = @"Validate";
    validateButton.bezelStyle = NSBezelStyleRounded;
    validateButton.target = self;
    validateButton.action = @selector(validateSymbols:);
    [basicView addSubview:validateButton];
    
    // Connection type
    yPos -= 40;
    NSTextField *typeLabel = [self createLabel:@"Connection Type:" at:NSMakePoint(20, yPos)];
    [basicView addSubview:typeLabel];
    
    yPos -= 25;
    self.typeComboBox = [[NSComboBox alloc] initWithFrame:NSMakeRect(20, yPos, 200, 24)];
    self.typeComboBox.editable = NO;
    [self populateTypeComboBox];
    [basicView addSubview:self.typeComboBox];
    
    // Template selector
    NSButton *templateButton = [[NSButton alloc] initWithFrame:NSMakeRect(240, yPos, 100, 24)];
    templateButton.title = @"Templates ▼";
    templateButton.bezelStyle = NSBezelStyleRounded;
    templateButton.target = self;
    templateButton.action = @selector(showTemplates:);
    [basicView addSubview:templateButton];
    
    // Direction - NSSegmentedControl
    yPos -= 40;
    NSTextField *directionLabel = [self createLabel:@"Direction:" at:NSMakePoint(20, yPos)];
    [basicView addSubview:directionLabel];
    
    yPos -= 35;
    self.directionSegmented = [[NSSegmentedControl alloc] initWithFrame:NSMakeRect(20, yPos, 400, 28)];
    self.directionSegmented.segmentCount = 3;
    
    [self.directionSegmented setLabel:@"↔ Bidirectional" forSegment:0];
    [self.directionSegmented setWidth:130 forSegment:0];
    
    [self.directionSegmented setLabel:@"→ Directional" forSegment:1];
    [self.directionSegmented setWidth:130 forSegment:1];
    
    [self.directionSegmented setLabel:@"⟶ Chain" forSegment:2];
    [self.directionSegmented setWidth:130 forSegment:2];
    
    self.directionSegmented.selectedSegment = 0;
    self.directionSegmented.segmentStyle = NSSegmentStyleRounded;
    [basicView addSubview:self.directionSegmented];
    
    // Help text
    yPos -= 25;
    NSTextField *helpLabel = [self createLabel:@"↔ All symbols affect each other • → First affects others • ⟶ Sequential chain A→B→C"
                                            at:NSMakePoint(20, yPos)];
    helpLabel.font = [NSFont systemFontOfSize:10];
    helpLabel.textColor = [NSColor secondaryLabelColor];
    [basicView addSubview:helpLabel];
    
    basicTab.view = basicView;
    [self.tabView addTabViewItem:basicTab];
}

- (void)setupStrengthTab {
    NSTabViewItem *strengthTab = [[NSTabViewItem alloc] initWithIdentifier:@"strength"];
    strengthTab.label = @"Strength";
    NSView *strengthView = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 440, 320)];
    
    CGFloat yPos = 280;
    
    // Initial strength
    NSTextField *initialLabel = [self createLabel:@"Initial Strength:" at:NSMakePoint(20, yPos)];
    [strengthView addSubview:initialLabel];
    
    yPos -= 25;
    self.initialSlider = [[NSSlider alloc] initWithFrame:NSMakeRect(20, yPos, 300, 24)];
    self.initialSlider.minValue = 0.1;
    self.initialSlider.maxValue = 1.0;
    self.initialSlider.doubleValue = 1.0;
    self.initialSlider.target = self;
    self.initialSlider.action = @selector(initialStrengthChanged:);
    [strengthView addSubview:self.initialSlider];
    
    self.initialValueLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(330, yPos, 60, 24)];
    self.initialValueLabel.editable = NO;
    self.initialValueLabel.bordered = NO;
    self.initialValueLabel.backgroundColor = [NSColor clearColor];
    self.initialValueLabel.stringValue = @"100%";
    [strengthView addSubview:self.initialValueLabel];
    
    // Decay settings
    yPos -= 50;
    NSTextField *decayLabel = [self createLabel:@"Decay Settings:" at:NSMakePoint(20, yPos)];
    [strengthView addSubview:decayLabel];
    
    yPos -= 25;
    self.enableDecayCheckbox = [NSButton checkboxWithTitle:@"Enable strength decay over time" target:self action:@selector(enableDecayChanged:)];
    self.enableDecayCheckbox.frame = NSMakeRect(20, yPos, 250, 24);
    [strengthView addSubview:self.enableDecayCheckbox];
    
    yPos -= 30;
    NSTextField *decayRateLabel = [self createLabel:@"Decay Rate:" at:NSMakePoint(40, yPos)];
    [strengthView addSubview:decayRateLabel];
    
    yPos -= 25;
    self.decaySlider = [[NSSlider alloc] initWithFrame:NSMakeRect(40, yPos, 250, 24)];
    self.decaySlider.minValue = 0.0;
    self.decaySlider.maxValue = 1.0;
    self.decaySlider.doubleValue = 0.1;
    self.decaySlider.enabled = NO;
    [strengthView addSubview:self.decaySlider];
    
    // Horizon date
    yPos -= 40;
    NSTextField *horizonLabel = [self createLabel:@"Strength Horizon (optional):" at:NSMakePoint(40, yPos)];
    [strengthView addSubview:horizonLabel];
    
    yPos -= 25;
    self.horizonPicker = [[NSDatePicker alloc] initWithFrame:NSMakeRect(40, yPos, 200, 24)];
    self.horizonPicker.datePickerStyle = NSDatePickerStyleTextFieldAndStepper;
    self.horizonPicker.dateValue = [[NSDate date] dateByAddingTimeInterval:365*24*60*60];
    self.horizonPicker.enabled = NO;
    [strengthView addSubview:self.horizonPicker];
    
    // Auto-delete
    yPos -= 40;
    self.autoDeleteCheckbox = [NSButton checkboxWithTitle:@"Auto-delete when strength drops below 10%" target:nil action:nil];
    self.autoDeleteCheckbox.frame = NSMakeRect(40, yPos, 300, 24);
    self.autoDeleteCheckbox.enabled = NO;
    [strengthView addSubview:self.autoDeleteCheckbox];
    
    strengthTab.view = strengthView;
    [self.tabView addTabViewItem:strengthTab];
}

- (void)setupContentTab {
    NSTabViewItem *contentTab = [[NSTabViewItem alloc] initWithIdentifier:@"content"];
    contentTab.label = @"Content";
    NSView *contentView = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 440, 320)];
    
    CGFloat yPos = 280;
    
    // Source URL
    NSTextField *urlLabel = [self createLabel:@"Source URL:" at:NSMakePoint(20, yPos)];
    [contentView addSubview:urlLabel];
    
    yPos -= 25;
    self.urlField = [[NSTextField alloc] initWithFrame:NSMakeRect(20, yPos, 300, 24)];
    self.urlField.placeholderString = @"https://...";
    [contentView addSubview:self.urlField];
    
    NSButton *aiSummaryButton = [[NSButton alloc] initWithFrame:NSMakeRect(330, yPos, 90, 24)];
    aiSummaryButton.title = @"AI Summary";
    aiSummaryButton.bezelStyle = NSBezelStyleRounded;
    aiSummaryButton.target = self;
    aiSummaryButton.action = @selector(generateAISummary:);
    [contentView addSubview:aiSummaryButton];
    
    // Description
    yPos -= 40;
    NSTextField *descLabel = [self createLabel:@"Description:" at:NSMakePoint(20, yPos)];
    [contentView addSubview:descLabel];
    
    yPos -= 80;
    self.descScrollView = [[NSScrollView alloc] initWithFrame:NSMakeRect(20, yPos, 400, 75)];
    NSTextView *descTextView = [[NSTextView alloc] init];
    descTextView.font = [NSFont systemFontOfSize:12];
    self.descScrollView.documentView = descTextView;
    self.descScrollView.hasVerticalScroller = YES;
    [contentView addSubview:self.descScrollView];
    
    // Notes
    yPos -= 40;
    NSTextField *notesLabel = [self createLabel:@"Notes:" at:NSMakePoint(20, yPos)];
    [contentView addSubview:notesLabel];
    
    yPos -= 80;
    self.notesScrollView = [[NSScrollView alloc] initWithFrame:NSMakeRect(20, yPos, 400, 75)];
    NSTextView *notesTextView = [[NSTextView alloc] init];
    notesTextView.font = [NSFont systemFontOfSize:12];
    self.notesScrollView.documentView = notesTextView;
    self.notesScrollView.hasVerticalScroller = YES;
    [contentView addSubview:self.notesScrollView];
    
    contentTab.view = contentView;
    [self.tabView addTabViewItem:contentTab];
}

- (void)setupAdvancedTab {
    NSTabViewItem *advancedTab = [[NSTabViewItem alloc] initWithIdentifier:@"advanced"];
    advancedTab.label = @"Advanced";
    NSView *advancedView = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 440, 320)];
    
    CGFloat yPos = 280;
    
    // Tags
    NSTextField *tagsLabel = [self createLabel:@"Tags (comma separated):" at:NSMakePoint(20, yPos)];
    [advancedView addSubview:tagsLabel];
    
    yPos -= 25;
    self.tagsField = [[NSTextField alloc] initWithFrame:NSMakeRect(20, yPos, 400, 24)];
    self.tagsField.placeholderString = @"ai, partnership, tech, bullish";
    [advancedView addSubview:self.tagsField];
    
    // Metadata preview
    yPos -= 50;
    NSTextField *metaLabel = [self createLabel:@"Metadata:" at:NSMakePoint(20, yPos)];
    [advancedView addSubview:metaLabel];
    
    yPos -= 100;
    NSScrollView *metaScrollView = [[NSScrollView alloc] initWithFrame:NSMakeRect(20, yPos, 400, 95)];
    NSTextView *metaTextView = [[NSTextView alloc] init];
    metaTextView.editable = NO;
    metaTextView.font = [NSFont fontWithName:@"Monaco" size:10];
    metaTextView.string = self.isEditing ?
        [NSString stringWithFormat:@"Connection ID: %@\nCreation Date: %@\nLast Modified: Will be updated\nStrength Update: Now",
         self.connectionModel.connectionID, self.connectionModel.creationDate] :
        @"Connection ID: Will be auto-generated\nCreation Date: Now\nLast Modified: Now\nStrength Update: Now";
    metaScrollView.documentView = metaTextView;
    metaScrollView.hasVerticalScroller = YES;
    [advancedView addSubview:metaScrollView];
    
    advancedTab.view = advancedView;
    [self.tabView addTabViewItem:advancedTab];
}

- (void)setupBottomButtons:(NSView *)containerView {
    NSButton *cancelButton = [[NSButton alloc] initWithFrame:NSMakeRect(320, 20, 80, 32)];
    cancelButton.title = @"Cancel";
    cancelButton.bezelStyle = NSBezelStyleRounded;
    cancelButton.target = self;
    cancelButton.action = @selector(cancel:);
    [containerView addSubview:cancelButton];
    
    NSButton *saveButton = [[NSButton alloc] initWithFrame:NSMakeRect(410, 20, 80, 32)];
    saveButton.title = self.isEditing ? @"Update" : @"Create";
    saveButton.bezelStyle = NSBezelStyleRounded;
    saveButton.keyEquivalent = @"\r";
    saveButton.target = self;
    saveButton.action = @selector(save:);
    [containerView addSubview:saveButton];
    
    NSButton *previewButton = [[NSButton alloc] initWithFrame:NSMakeRect(220, 20, 90, 32)];
    previewButton.title = @"Preview";
    previewButton.bezelStyle = NSBezelStyleRounded;
    previewButton.target = self;
    previewButton.action = @selector(preview:);
    [containerView addSubview:previewButton];
}

#pragma mark - Helper Methods

- (NSTextField *)createLabel:(NSString *)text at:(NSPoint)point {
    NSTextField *label = [[NSTextField alloc] initWithFrame:NSMakeRect(point.x, point.y, 200, 20)];
    label.stringValue = text;
    label.editable = NO;
    label.bordered = NO;
    label.backgroundColor = [NSColor clearColor];
    label.font = [NSFont systemFontOfSize:12 weight:NSFontWeightMedium];
    return label;
}

- (void)populateTypeComboBox {
    NSArray *connectionTypes = @[
        @"News", @"Personal Note", @"Sympathy Move", @"Collaboration",
        @"Merger/Acquisition", @"Partnership", @"Supplier Relationship", @"Competitor",
        @"Correlation", @"Same Sector", @"Custom"
    ];
    
    for (NSString *type in connectionTypes) {
        [self.typeComboBox addItemWithObjectValue:type];
    }
    [self.typeComboBox selectItemAtIndex:0];
}

- (void)populateFieldsFromConnection {
    if (!self.connectionModel) return;
    
    // Basic fields
    self.titleField.stringValue = self.connectionModel.title ?: @"";
    
    // Symbols - usa allInvolvedSymbols per ottenere tutti i simboli
    NSArray *allSymbols = [self.connectionModel allInvolvedSymbols];
    if (allSymbols && allSymbols.count > 0) {
        self.symbolsField.stringValue = [allSymbols componentsJoinedByString:@", "];
    }
    
    self.urlField.stringValue = self.connectionModel.url ?: @"";
    
    // Connection type
    NSString *typeString = [self connectionTypeToString:self.connectionModel.connectionType];
    [self.typeComboBox selectItemWithObjectValue:typeString];
    
    // Direction
    if (self.connectionModel.bidirectional) {
        self.directionSegmented.selectedSegment = 0; // Bidirectional
    } else {
        self.directionSegmented.selectedSegment = 1; // Directional
    }
    
    // Content
    NSTextView *descTextView = (NSTextView *)self.descScrollView.documentView;
    descTextView.string = self.connectionModel.connectionDescription ?: @"";
    
    NSTextView *notesTextView = (NSTextView *)self.notesScrollView.documentView;
    notesTextView.string = self.connectionModel.notes ?: @"";
    
    // Tags
    if (self.connectionModel.tags && self.connectionModel.tags.count > 0) {
        self.tagsField.stringValue = [self.connectionModel.tags componentsJoinedByString:@", "];
    }
    
    // Strength
    self.initialSlider.doubleValue = self.connectionModel.currentStrength;
    [self initialStrengthChanged:self.initialSlider];
}
- (NSString *)connectionTypeToString:(StockConnectionType)type {
    switch (type) {
        case StockConnectionTypeNews: return @"News";
        case StockConnectionTypePersonalNote: return @"Personal Note";
        case StockConnectionTypeSympathy: return @"Sympathy Move";
        case StockConnectionTypeCollaboration: return @"Collaboration";
        case StockConnectionTypeMerger: return @"Merger/Acquisition";
        case StockConnectionTypePartnership: return @"Partnership";
        case StockConnectionTypeSupplier: return @"Supplier Relationship";
        case StockConnectionTypeCompetitor: return @"Competitor";
        case StockConnectionTypeCorrelation: return @"Correlation";
        case StockConnectionTypeSector: return @"Same Sector";
        case StockConnectionTypeCustom: return @"Custom";
        default: return @"News";
    }
}

- (StockConnectionType)stringToConnectionType:(NSString *)typeString {
    if ([typeString isEqualToString:@"News"]) return StockConnectionTypeNews;
    if ([typeString isEqualToString:@"Personal Note"]) return StockConnectionTypePersonalNote;
    if ([typeString isEqualToString:@"Sympathy Move"]) return StockConnectionTypeSympathy;
    if ([typeString isEqualToString:@"Collaboration"]) return StockConnectionTypeCollaboration;
    if ([typeString isEqualToString:@"Merger/Acquisition"]) return StockConnectionTypeMerger;
    if ([typeString isEqualToString:@"Partnership"]) return StockConnectionTypePartnership;
    if ([typeString isEqualToString:@"Supplier Relationship"]) return StockConnectionTypeSupplier;
    if ([typeString isEqualToString:@"Competitor"]) return StockConnectionTypeCompetitor;
    if ([typeString isEqualToString:@"Correlation"]) return StockConnectionTypeCorrelation;
    if ([typeString isEqualToString:@"Same Sector"]) return StockConnectionTypeSector;
    if ([typeString isEqualToString:@"Custom"]) return StockConnectionTypeCustom;
    
    return StockConnectionTypeNews; // Default
}

#pragma mark - Actions

- (void)validateSymbols:(id)sender {
    NSString *symbols = self.symbolsField.stringValue;
    // TODO: Implement symbol validation
    NSLog(@"Validating symbols: %@", symbols);
}

- (void)showTemplates:(id)sender {
    // TODO: Show template selection
    NSLog(@"Show templates");
}

- (void)initialStrengthChanged:(NSSlider *)slider {
    self.initialValueLabel.stringValue = [NSString stringWithFormat:@"%.0f%%", slider.doubleValue * 100];
}

- (void)enableDecayChanged:(NSButton *)checkbox {
    BOOL enabled = checkbox.state == NSControlStateValueOn;
    self.decaySlider.enabled = enabled;
    self.horizonPicker.enabled = enabled;
    self.autoDeleteCheckbox.enabled = enabled;
}

- (void)generateAISummary:(id)sender {
    NSString *url = self.urlField.stringValue;
    if (url.length == 0) {
        [self showAlert:@"AI Summary" message:@"Please enter a URL first."];
        return;
    }
    
    NSButton *button = (NSButton *)sender;
    button.title = @"Generating...";
    button.enabled = NO;
    
    // TODO: Implement AI summary generation via DataHub
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        button.title = @"AI Summary";
        button.enabled = YES;
        
        NSTextView *descTextView = (NSTextView *)self.descScrollView.documentView;
        descTextView.string = @"[AI Generated] This article discusses strategic partnerships and market implications for the mentioned companies.";
        
        [self showAlert:@"AI Summary" message:@"AI summary generated and added to description field."];
    });
}

- (void)preview:(id)sender {
    // TODO: Show preview of connection
    NSLog(@"Preview connection");
}
- (void)save:(id)sender {
    // Validate and save
    if (![self validateFields]) return;
    
    ConnectionModel *connectionToSave;
    
    if (self.isEditing) {
        // Update existing connection
        connectionToSave = self.connectionModel;
        [self updateConnectionModelFromFields:connectionToSave];
        
        // Save via DataHub
        DataHub *hub = [DataHub shared];
        [hub updateConnection:connectionToSave];
    } else {
        // Create new connection
        connectionToSave = [self createConnectionModelFromFields];
        
        // Save via DataHub usando i metodi factory esistenti
        DataHub *hub = [DataHub shared];
        
        // Usa i metodi factory del DataHub+Connections
        BOOL isBidirectional = (self.directionSegmented.selectedSegment == 0);
        
        if (isBidirectional) {
            connectionToSave = [hub createBidirectionalConnectionWithSymbols:connectionToSave.symbols
                                                                        type:connectionToSave.connectionType
                                                                       title:connectionToSave.title];
        } else {
            connectionToSave = [hub createDirectionalConnectionFromSymbol:connectionToSave.sourceSymbol
                                                                toSymbols:connectionToSave.targetSymbols
                                                                     type:connectionToSave.connectionType
                                                                    title:connectionToSave.title];
        }
        
        // Aggiorna con i campi aggiuntivi
        if (connectionToSave) {
            connectionToSave.url = self.urlField.stringValue;
            NSTextView *descTextView = (NSTextView *)self.descScrollView.documentView;
            connectionToSave.connectionDescription = descTextView.string;
            NSTextView *notesTextView = (NSTextView *)self.notesScrollView.documentView;
            connectionToSave.notes = notesTextView.string;
            // Altri campi...
            
            [hub updateConnection:connectionToSave];
        }
    }
    
    // Call success callback
    if (self.onSave) {
        self.onSave(connectionToSave);
    }
    
    [self.window close];
}

- (void)cancel:(id)sender {
    if (self.onCancel) {
        self.onCancel();
    }
    [self.window close];
}

- (void)showWindow:(id)sender {
    [self.window makeKeyAndOrderFront:sender];
    [self.window center];
}


#pragma mark - Data Processing

- (BOOL)validateFields {
    if (self.symbolsField.stringValue.length == 0) {
        [self showAlert:@"Validation Error" message:@"Please enter at least one symbol."];
        return NO;
    }
    return YES;
}

- (ConnectionModel *)createConnectionModelFromFields {
    // Symbols
    NSArray *symbolsArray = [self.symbolsField.stringValue componentsSeparatedByString:@","];
    NSMutableArray *cleanSymbols = [NSMutableArray array];
    for (NSString *symbol in symbolsArray) {
        NSString *clean = [symbol stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]].uppercaseString;
        if (clean.length > 0) [cleanSymbols addObject:clean];
    }
    
    // Usa il factory method appropriato del ConnectionModel esistente
    BOOL isBidirectional = (self.directionSegmented.selectedSegment == 0);
    
    ConnectionModel *model;
    if (isBidirectional) {
        model = [[ConnectionModel alloc] initBidirectionalWithSymbols:cleanSymbols
                                                                 type:[self stringToConnectionType:self.typeComboBox.stringValue]
                                                                title:self.titleField.stringValue];
    } else {
        // Per directional, usa il primo simbolo come source e il resto come target
        NSString *sourceSymbol = cleanSymbols.count > 0 ? cleanSymbols[0] : @"";
        NSArray *targetSymbols = cleanSymbols.count > 1 ? [cleanSymbols subarrayWithRange:NSMakeRange(1, cleanSymbols.count - 1)] : @[];
        
        model = [[ConnectionModel alloc] initDirectionalFromSymbol:sourceSymbol
                                                         toSymbols:targetSymbols
                                                              type:[self stringToConnectionType:self.typeComboBox.stringValue]
                                                             title:self.titleField.stringValue];
    }
    
    // Popola altri campi
    model.url = self.urlField.stringValue;
    
    NSTextView *descTextView = (NSTextView *)self.descScrollView.documentView;
    model.connectionDescription = descTextView.string;
    
    NSTextView *notesTextView = (NSTextView *)self.notesScrollView.documentView;
    model.notes = notesTextView.string;
    
    // Tags
    NSArray *tagsArray = [self.tagsField.stringValue componentsSeparatedByString:@","];
    NSMutableArray *cleanTags = [NSMutableArray array];
    for (NSString *tag in tagsArray) {
        NSString *clean = [tag stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        if (clean.length > 0) [cleanTags addObject:clean];
    }
    model.tags = cleanTags;
    
    // Strength
    model.currentStrength = self.initialSlider.doubleValue;
    model.initialStrength = self.initialSlider.doubleValue;
    
    return model;
}

- (void)updateConnectionModelFromFields:(ConnectionModel *)model {
    // Aggiorna il RuntimeModel esistente
    model.title = self.titleField.stringValue;
    model.connectionType = [self stringToConnectionType:self.typeComboBox.stringValue];
    model.url = self.urlField.stringValue;
    
    // Symbols
    NSArray *symbolsArray = [self.symbolsField.stringValue componentsSeparatedByString:@","];
    NSMutableArray *cleanSymbols = [NSMutableArray array];
    for (NSString *symbol in symbolsArray) {
        NSString *clean = [symbol stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]].uppercaseString;
        if (clean.length > 0) [cleanSymbols addObject:clean];
    }
    
    // Update bidirectional flag
    model.bidirectional = (self.directionSegmented.selectedSegment == 0);
    
    if (model.bidirectional) {
        model.symbols = cleanSymbols;
    } else {
        model.sourceSymbol = cleanSymbols.count > 0 ? cleanSymbols[0] : @"";
        model.targetSymbols = cleanSymbols.count > 1 ? [cleanSymbols subarrayWithRange:NSMakeRange(1, cleanSymbols.count - 1)] : @[];
        
        // Update legacy symbols array
        NSMutableArray *allSymbols = [NSMutableArray arrayWithObject:model.sourceSymbol];
        [allSymbols addObjectsFromArray:model.targetSymbols];
        model.symbols = allSymbols;
    }
    
    // Content
    NSTextView *descTextView = (NSTextView *)self.descScrollView.documentView;
    model.connectionDescription = descTextView.string;
    
    NSTextView *notesTextView = (NSTextView *)self.notesScrollView.documentView;
    model.notes = notesTextView.string;
    
    // Tags
    NSArray *tagsArray = [self.tagsField.stringValue componentsSeparatedByString:@","];
    NSMutableArray *cleanTags = [NSMutableArray array];
    for (NSString *tag in tagsArray) {
        NSString *clean = [tag stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        if (clean.length > 0) [cleanTags addObject:clean];
    }
    model.tags = cleanTags;
    
    // Strength
    model.currentStrength = self.initialSlider.doubleValue;
    model.initialStrength = self.initialSlider.doubleValue;
    
    // Update timestamp
    model.lastModified = [NSDate date];
}

- (void)showAlert:(NSString *)title message:(NSString *)message {
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = title;
    alert.informativeText = message;
    [alert runModal];
}

@end
