//
//  IndicatorsPanelController.m
//  TradingApp
//
//  Slide-out panel for managing chart indicators and templates
//

#import "IndicatorsPanelController.h"
#import "ChartWidget.h"
#import "ChartPanelModel.h"
#import "IndicatorRenderer.h"
#import "RuntimeModels.h"
#import <QuartzCore/QuartzCore.h>

// Renderers imports
#import "VolumeRenderer.h"

static const CGFloat kPanelWidth = 300.0;
static const CGFloat kAnimationDuration = 0.25;
static const CGFloat kPanelRowHeight = 60.0;
static const CGFloat kIndicatorRowHeight = 28.0;

@interface IndicatorsPanelController ()
@property (nonatomic, strong) NSMutableArray<NSView *> *panelRowViews;
@property (nonatomic, strong) TemplateManager *templateManager;
@property (nonatomic, strong) NSLayoutConstraint *panelTrailingConstraint;
@property (nonatomic, strong) NSLayoutConstraint *panelLeadingConstraint;

// UI Components not in header - internal use only
@property (nonatomic, strong) NSTableView *indicatorsTableView;
@property (nonatomic, strong) NSScrollView *indicatorsScrollView;
@end

@implementation IndicatorsPanelController

#pragma mark - Initialization

- (instancetype)initWithChartWidget:(ChartWidget *)chartWidget {
    self = [super init];
    if (self) {
        _chartWidget = chartWidget;
        _isVisible = NO;
        _panelRowViews = [NSMutableArray array];
        
        // Initialize available indicator types
        _availableIndicatorTypes = @[
            @"Volume",
            @"RSI",
            @"MACD",
            @"SMA",
            @"Bollinger Bands"
        ];
        
        _savedTemplates = [NSMutableArray arrayWithArray:@[@"Default"]];
        
        NSLog(@"✅ IndicatorsPanelController: Initialized with chart widget");
    }
    return self;
}

- (void)loadView {
    self.view = [[NSView alloc] init];
    [self setupUI];
    [self setupConstraints];
    
    NSLog(@"✅ IndicatorsPanelController: View loaded");
}

#pragma mark - UI Setup

- (void)setupUI {
    // Create main panel view with backdrop
    self.backdropView = [[NSVisualEffectView alloc] init];
    self.backdropView.translatesAutoresizingMaskIntoConstraints = NO;
    self.backdropView.material = NSVisualEffectMaterialSidebar;
    self.backdropView.blendingMode = NSVisualEffectBlendingModeBehindWindow;
    self.backdropView.state = NSVisualEffectStateActive;
    [self.view addSubview:self.backdropView];
    
    self.panelView = [[NSView alloc] init];
    self.panelView.translatesAutoresizingMaskIntoConstraints = NO;
    self.panelView.wantsLayer = YES;
    self.panelView.layer.borderWidth = 1.0;
    self.panelView.layer.borderColor = [NSColor separatorColor].CGColor;
    [self.backdropView addSubview:self.panelView];
    
    // Create sections
    [self createHeader];
    [self createTemplateSection];
    [self createPanelsSection];
    [self createAvailableIndicatorsSection];
}

- (void)createHeader {
    // Header label
    self.headerLabel = [[NSTextField alloc] init];
    self.headerLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.headerLabel.stringValue = @"INDICATORS MANAGEMENT";
    self.headerLabel.font = [NSFont boldSystemFontOfSize:12];
    self.headerLabel.textColor = [NSColor secondaryLabelColor];
    self.headerLabel.editable = NO;
    self.headerLabel.bordered = NO;
    self.headerLabel.backgroundColor = [NSColor clearColor];
    [self.panelView addSubview:self.headerLabel];
    
    // Close button
    self.closeButton = [[NSButton alloc] init];
    self.closeButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.closeButton.title = @"✕";
    self.closeButton.font = [NSFont systemFontOfSize:14];
    self.closeButton.buttonType = NSButtonTypeMomentaryPushIn;
    self.closeButton.bordered = NO;
    self.closeButton.target = self;
    self.closeButton.action = @selector(closeButtonClicked:);
    [self.panelView addSubview:self.closeButton];
}

- (void)createTemplateSection {
    // Template label
    self.templateLabel = [[NSTextField alloc] init];
    self.templateLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.templateLabel.stringValue = @"Template:";
    self.templateLabel.font = [NSFont systemFontOfSize:11];
    self.templateLabel.editable = NO;
    self.templateLabel.bordered = NO;
    self.templateLabel.backgroundColor = [NSColor clearColor];
    [self.panelView addSubview:self.templateLabel];
    
    // Template combo box
    self.templateComboBox = [[NSComboBox alloc] init];
    self.templateComboBox.translatesAutoresizingMaskIntoConstraints = NO;
    self.templateComboBox.font = [NSFont systemFontOfSize:11];
    [self.templateComboBox addItemsWithObjectValues:self.savedTemplates];
    [self.templateComboBox selectItemAtIndex:0];
    [self.panelView addSubview:self.templateComboBox];
    
    // Save button
    self.saveTemplateButton = [[NSButton alloc] init];
    self.saveTemplateButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.saveTemplateButton.title = @"💾";
    self.saveTemplateButton.font = [NSFont systemFontOfSize:14];
    self.saveTemplateButton.buttonType = NSButtonTypeMomentaryPushIn;
    self.saveTemplateButton.bordered = YES;
    self.saveTemplateButton.target = self;
    self.saveTemplateButton.action = @selector(saveTemplateButtonClicked:);
    [self.panelView addSubview:self.saveTemplateButton];
    
    // Load button
    self.loadTemplateButton = [[NSButton alloc] init];
    self.loadTemplateButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.loadTemplateButton.title = @"📁";
    self.loadTemplateButton.font = [NSFont systemFontOfSize:14];
    self.loadTemplateButton.buttonType = NSButtonTypeMomentaryPushIn;
    self.loadTemplateButton.bordered = YES;
    self.loadTemplateButton.target = self;
    self.loadTemplateButton.action = @selector(loadTemplateButtonClicked:);
    [self.panelView addSubview:self.loadTemplateButton];
}

- (void)createPanelsSection {
    // Panels scroll view
    self.panelsScrollView = [[NSScrollView alloc] init];
    self.panelsScrollView.translatesAutoresizingMaskIntoConstraints = NO;
    self.panelsScrollView.hasVerticalScroller = YES;
    self.panelsScrollView.hasHorizontalScroller = NO;
    self.panelsScrollView.autohidesScrollers = YES;
    self.panelsScrollView.borderType = NSLineBorder;
    [self.panelView addSubview:self.panelsScrollView];
    
    // Panels stack view
    self.panelsStackView = [[NSStackView alloc] init];
    self.panelsStackView.translatesAutoresizingMaskIntoConstraints = NO;
    self.panelsStackView.orientation = NSUserInterfaceLayoutOrientationVertical;
    self.panelsStackView.spacing = 1;
    self.panelsStackView.distribution = NSStackViewDistributionFill;
    self.panelsStackView.alignment = NSLayoutAttributeLeading;
    self.panelsScrollView.documentView = self.panelsStackView;
    
    // Add panel button
    self.addPanelButton = [[NSButton alloc] init];
    self.addPanelButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.addPanelButton.title = @"➕ ADD PANEL";
    self.addPanelButton.font = [NSFont systemFontOfSize:11];
    self.addPanelButton.buttonType = NSButtonTypeMomentaryPushIn;
    self.addPanelButton.bordered = YES;
    self.addPanelButton.target = self;
    self.addPanelButton.action = @selector(addPanelButtonClicked:);
    [self.panelView addSubview:self.addPanelButton];
}

- (void)createAvailableIndicatorsSection {
    // Available indicators label
    self.availableLabel = [[NSTextField alloc] init];
    self.availableLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.availableLabel.stringValue = @"Available Indicators:";
    self.availableLabel.font = [NSFont systemFontOfSize:11];
    self.availableLabel.editable = NO;
    self.availableLabel.bordered = NO;
    self.availableLabel.backgroundColor = [NSColor clearColor];
    [self.panelView addSubview:self.availableLabel];
    
    // Available indicators scroll view
    self.availableScrollView = [[NSScrollView alloc] init];
    self.availableScrollView.translatesAutoresizingMaskIntoConstraints = NO;
    self.availableScrollView.hasVerticalScroller = YES;
    self.availableScrollView.hasHorizontalScroller = NO;
    self.availableScrollView.autohidesScrollers = YES;
    self.availableScrollView.borderType = NSLineBorder;
    [self.panelView addSubview:self.availableScrollView];
    
    // Available indicators table
    self.indicatorsTableView = [[NSTableView alloc] init];
    self.indicatorsTableView.translatesAutoresizingMaskIntoConstraints = NO;
    self.indicatorsTableView.rowHeight = kIndicatorRowHeight;
    self.indicatorsTableView.headerView = nil;
    self.indicatorsTableView.dataSource = self;
    self.indicatorsTableView.delegate = self;
    self.indicatorsTableView.doubleAction = @selector(indicatorDoubleClicked:);
    self.indicatorsTableView.target = self;
    
    // Add column for indicator names
    NSTableColumn *column = [[NSTableColumn alloc] initWithIdentifier:@"indicator"];
    column.title = @"Indicator";
    column.width = kPanelWidth - 40;
    [self.indicatorsTableView addTableColumn:column];
    
    self.availableScrollView.documentView = self.indicatorsTableView;
}

- (void)setupConstraints {
    [NSLayoutConstraint activateConstraints:@[
        // Backdrop view fills entire view
        [self.backdropView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [self.backdropView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.backdropView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.backdropView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        
        // Panel view
        [self.panelView.topAnchor constraintEqualToAnchor:self.backdropView.topAnchor],
        [self.panelView.leadingAnchor constraintEqualToAnchor:self.backdropView.leadingAnchor],
        [self.panelView.trailingAnchor constraintEqualToAnchor:self.backdropView.trailingAnchor],
        [self.panelView.bottomAnchor constraintEqualToAnchor:self.backdropView.bottomAnchor],
        
        // Header
        [self.headerLabel.topAnchor constraintEqualToAnchor:self.panelView.topAnchor constant:12],
        [self.headerLabel.leadingAnchor constraintEqualToAnchor:self.panelView.leadingAnchor constant:12],
        
        [self.closeButton.topAnchor constraintEqualToAnchor:self.panelView.topAnchor constant:8],
        [self.closeButton.trailingAnchor constraintEqualToAnchor:self.panelView.trailingAnchor constant:-8],
        [self.closeButton.widthAnchor constraintEqualToConstant:24],
        [self.closeButton.heightAnchor constraintEqualToConstant:24],
        
        // Template section
        [self.templateLabel.topAnchor constraintEqualToAnchor:self.headerLabel.bottomAnchor constant:16],
        [self.templateLabel.leadingAnchor constraintEqualToAnchor:self.panelView.leadingAnchor constant:12],
        
        [self.templateComboBox.topAnchor constraintEqualToAnchor:self.templateLabel.bottomAnchor constant:4],
        [self.templateComboBox.leadingAnchor constraintEqualToAnchor:self.panelView.leadingAnchor constant:12],
        [self.templateComboBox.widthAnchor constraintEqualToConstant:180],
        
        [self.saveTemplateButton.centerYAnchor constraintEqualToAnchor:self.templateComboBox.centerYAnchor],
        [self.saveTemplateButton.leadingAnchor constraintEqualToAnchor:self.templateComboBox.trailingAnchor constant:8],
        [self.saveTemplateButton.widthAnchor constraintEqualToConstant:30],
        
        [self.loadTemplateButton.centerYAnchor constraintEqualToAnchor:self.templateComboBox.centerYAnchor],
        [self.loadTemplateButton.leadingAnchor constraintEqualToAnchor:self.saveTemplateButton.trailingAnchor constant:4],
        [self.loadTemplateButton.widthAnchor constraintEqualToConstant:30],
        
        // Panels section
        [self.panelsScrollView.topAnchor constraintEqualToAnchor:self.templateComboBox.bottomAnchor constant:16],
        [self.panelsScrollView.leadingAnchor constraintEqualToAnchor:self.panelView.leadingAnchor constant:12],
        [self.panelsScrollView.trailingAnchor constraintEqualToAnchor:self.panelView.trailingAnchor constant:-12],
        [self.panelsScrollView.heightAnchor constraintEqualToConstant:200],
        
        [self.addPanelButton.topAnchor constraintEqualToAnchor:self.panelsScrollView.bottomAnchor constant:8],
        [self.addPanelButton.leadingAnchor constraintEqualToAnchor:self.panelView.leadingAnchor constant:12],
        [self.addPanelButton.trailingAnchor constraintEqualToAnchor:self.panelView.trailingAnchor constant:-12],
        
        // Available indicators section
        [self.availableLabel.topAnchor constraintEqualToAnchor:self.addPanelButton.bottomAnchor constant:16],
        [self.availableLabel.leadingAnchor constraintEqualToAnchor:self.panelView.leadingAnchor constant:12],
        
        [self.availableScrollView.topAnchor constraintEqualToAnchor:self.availableLabel.bottomAnchor constant:8],
        [self.availableScrollView.leadingAnchor constraintEqualToAnchor:self.panelView.leadingAnchor constant:12],
        [self.availableScrollView.trailingAnchor constraintEqualToAnchor:self.panelView.trailingAnchor constant:-12],
        [self.availableScrollView.bottomAnchor constraintEqualToAnchor:self.panelView.bottomAnchor constant:-12]
    ]];
    
    // Fixed width for the view
    [self.view.widthAnchor constraintEqualToConstant:kPanelWidth].active = YES;
}

#pragma mark - Show/Hide Panel

- (void)showPanel {
    if (self.isVisible) return;
    
    NSView *parentView = self.chartWidget.contentView;
    if (!parentView) {
        NSLog(@"⚠️ IndicatorsPanelController: No parent view");
        return;
    }
    
    // Add to parent view
    [parentView addSubview:self.view];
    
    // CORREZIONE: Setup constraints stabili
    NSLayoutConstraint *topConstraint = [self.view.topAnchor constraintEqualToAnchor:parentView.topAnchor];
    NSLayoutConstraint *bottomConstraint = [self.view.bottomAnchor constraintEqualToAnchor:parentView.bottomAnchor];
    NSLayoutConstraint *widthConstraint = [self.view.widthAnchor constraintEqualToConstant:kPanelWidth];
    
    // Start off-screen
    self.panelLeadingConstraint = [self.view.leadingAnchor constraintEqualToAnchor:parentView.trailingAnchor];
    
    [NSLayoutConstraint activateConstraints:@[topConstraint, bottomConstraint, widthConstraint, self.panelLeadingConstraint]];
    [parentView layoutSubtreeIfNeeded];
    
    // Animate in
    [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
        context.duration = kAnimationDuration;
        context.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
        
        // CORREZIONE: sostituisci il constraint invece di modificarlo
        [self.panelLeadingConstraint setActive:NO];
        self.panelTrailingConstraint = [self.view.trailingAnchor constraintEqualToAnchor:parentView.trailingAnchor];
        [self.panelTrailingConstraint setActive:YES];
        
        [parentView.animator layoutSubtreeIfNeeded];
        
    } completionHandler:^{
        self.isVisible = YES;
        [self refreshPanelsList];
        NSLog(@"✅ IndicatorsPanelController: Panel shown");
    }];
}

- (void)hidePanel {
    if (!self.isVisible) return;
    
    NSView *parentView = self.view.superview;
    if (!parentView) return;
    
    [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
        context.duration = kAnimationDuration;
        context.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
        
        // CORREZIONE: animazione stabile per nascondere
        [self.panelTrailingConstraint setActive:NO];
        self.panelLeadingConstraint = [self.view.leadingAnchor constraintEqualToAnchor:parentView.trailingAnchor];
        [self.panelLeadingConstraint setActive:YES];
        
        [parentView.animator layoutSubtreeIfNeeded];
        
    } completionHandler:^{
        [self.view removeFromSuperview];
        self.isVisible = NO;
        self.panelTrailingConstraint = nil;
        self.panelLeadingConstraint = nil;
        NSLog(@"✅ IndicatorsPanelController: Panel hidden");
    }];
}

- (void)togglePanel {
    if (self.isVisible) {
        [self hidePanel];
    } else {
        [self showPanel];
    }
}

#pragma mark - Actions

- (IBAction)closeButtonClicked:(id)sender {
    [self hidePanel];
}

- (IBAction)addPanelButtonClicked:(id)sender {
    // Create new secondary panel
    ChartPanelModel *newPanel = [ChartPanelModel secondaryPanelWithTitle:@"New Panel"];
    [self.chartWidget addPanelWithModel:newPanel];
    [self refreshPanelsList];
}

- (IBAction)saveTemplateButtonClicked:(id)sender {
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"Save Template";
    alert.informativeText = @"Enter a name for this template:";
    alert.alertStyle = NSAlertStyleInformational;
    [alert addButtonWithTitle:@"Save"];
    [alert addButtonWithTitle:@"Cancel"];
    
    NSTextField *input = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 200, 24)];
    input.stringValue = @"My Template";
    alert.accessoryView = input;
    
    [alert beginSheetModalForWindow:self.chartWidget.view.window completionHandler:^(NSModalResponse returnCode) {
        if (returnCode == NSAlertFirstButtonReturn) {
            NSString *templateName = input.stringValue;
            if (templateName.length > 0) {
                [self saveTemplateWithName:templateName];
            }
        }
    }];
}

- (IBAction)loadTemplateButtonClicked:(id)sender {
    NSString *selectedTemplate = self.templateComboBox.stringValue;
    if (selectedTemplate.length > 0) {
        [self loadTemplateWithName:selectedTemplate];
    }
}

- (void)indicatorDoubleClicked:(id)sender {
    NSInteger selectedRow = self.indicatorsTableView.selectedRow;
    if (selectedRow >= 0 && selectedRow < self.availableIndicatorTypes.count) {
        [self addIndicatorToSelectedPanel:self.availableIndicatorTypes[selectedRow]];
    }
}

- (void)deletePanelButtonClicked:(NSButton *)sender {
    NSInteger index = sender.tag;
    if (index < self.chartWidget.panelModels.count) {
        ChartPanelModel *panelModel = self.chartWidget.panelModels[index];
        [self.chartWidget requestDeletePanel:panelModel];
        [self refreshPanelsList];
    }
}

#pragma mark - Data Updates

- (void)refreshPanelsList {
    // Clear existing panel rows
    for (NSView *rowView in self.panelRowViews) {
        [self.panelsStackView removeArrangedSubview:rowView];
        [rowView removeFromSuperview];
    }
    [self.panelRowViews removeAllObjects];
    
    // Add rows for each panel
    for (NSInteger i = 0; i < self.chartWidget.panelModels.count; i++) {
        ChartPanelModel *panelModel = self.chartWidget.panelModels[i];
        NSView *rowView = [self createPanelRowForModel:panelModel atIndex:i];
        [self.panelRowViews addObject:rowView];
        [self.panelsStackView addArrangedSubview:rowView];
    }
    
    NSLog(@"📊 IndicatorsPanelController: Refreshed %lu panels", (unsigned long)self.chartWidget.panelModels.count);
}

- (void)refreshTemplatesList {
    [self.templateComboBox removeAllItems];
    [self.templateComboBox addItemsWithObjectValues:self.savedTemplates];
    if (self.savedTemplates.count > 0) {
        [self.templateComboBox selectItemAtIndex:0];
    }
}

#pragma mark - Panel Row Creation

- (NSView *)createPanelRowForModel:(ChartPanelModel *)panelModel atIndex:(NSInteger)index {
    NSView *rowView = [[NSView alloc] init];
    rowView.translatesAutoresizingMaskIntoConstraints = NO;
    rowView.wantsLayer = YES;
    rowView.layer.backgroundColor = [NSColor controlBackgroundColor].CGColor;
    rowView.layer.borderWidth = 0.5;
    rowView.layer.borderColor = [NSColor separatorColor].CGColor;
    
    // Panel title
    NSString *panelTitle = [NSString stringWithFormat:@"PANEL %ld: %@", (long)(index + 1), panelModel.title];
    if (panelModel.panelType == ChartPanelTypeMain) {
        panelTitle = [panelTitle stringByAppendingString:@" (Main)"];
    }
    
    NSTextField *titleLabel = [[NSTextField alloc] init];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.stringValue = panelTitle;
    titleLabel.font = [NSFont boldSystemFontOfSize:10];
    titleLabel.editable = NO;
    titleLabel.bordered = NO;
    titleLabel.backgroundColor = [NSColor clearColor];
    [rowView addSubview:titleLabel];
    
    // Delete button (if deletable)
    NSButton *deleteButton = nil;
    if (panelModel.canBeDeleted) {
        deleteButton = [[NSButton alloc] init];
        deleteButton.translatesAutoresizingMaskIntoConstraints = NO;
        deleteButton.title = @"❌";
        deleteButton.font = [NSFont systemFontOfSize:12];
        deleteButton.buttonType = NSButtonTypeMomentaryPushIn;
        deleteButton.bordered = NO;
        deleteButton.tag = index;
        deleteButton.target = self;
        deleteButton.action = @selector(deletePanelButtonClicked:);
        [rowView addSubview:deleteButton];
    }
    
    // Indicators list
    NSMutableString *indicatorsText = [NSMutableString string];
    for (id<IndicatorRenderer> indicator in panelModel.indicators) {
        if (indicatorsText.length > 0) {
            [indicatorsText appendString:@"\n"];
        }
        
        NSString *icon = [self iconForIndicatorType:[indicator indicatorType]];
        [indicatorsText appendFormat:@"└ %@ %@ (%@)", icon, [indicator displayName], [indicator indicatorType]];
    }
    
    if (indicatorsText.length == 0) {
        [indicatorsText appendString:@"└ No indicators"];
    }
    
    NSTextField *indicatorsLabel = [[NSTextField alloc] init];
    indicatorsLabel.translatesAutoresizingMaskIntoConstraints = NO;
    indicatorsLabel.stringValue = indicatorsText;
    indicatorsLabel.font = [NSFont systemFontOfSize:9];
    indicatorsLabel.editable = NO;
    indicatorsLabel.bordered = NO;
    indicatorsLabel.backgroundColor = [NSColor clearColor];
    indicatorsLabel.textColor = [NSColor secondaryLabelColor];
    [rowView addSubview:indicatorsLabel];
    
    // Constraints
    [NSLayoutConstraint activateConstraints:@[
        [rowView.heightAnchor constraintEqualToConstant:kPanelRowHeight],
        
        [titleLabel.topAnchor constraintEqualToAnchor:rowView.topAnchor constant:4],
        [titleLabel.leadingAnchor constraintEqualToAnchor:rowView.leadingAnchor constant:8],
        
        [indicatorsLabel.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:2],
        [indicatorsLabel.leadingAnchor constraintEqualToAnchor:rowView.leadingAnchor constant:16],
        [indicatorsLabel.trailingAnchor constraintEqualToAnchor:rowView.trailingAnchor constant:-8],
    ]];
    
    if (deleteButton) {
        [NSLayoutConstraint activateConstraints:@[
            [deleteButton.centerYAnchor constraintEqualToAnchor:rowView.centerYAnchor],
            [deleteButton.trailingAnchor constraintEqualToAnchor:rowView.trailingAnchor constant:-8],
            [deleteButton.widthAnchor constraintEqualToConstant:20],
            [deleteButton.heightAnchor constraintEqualToConstant:20]
        ]];
    }
    
    return rowView;
}

- (NSString *)iconForIndicatorType:(NSString *)indicatorType {
    NSDictionary *icons = @{
        @"Security": @"📊",
        @"Volume": @"📈",
        @"RSI": @"📉",
        @"MACD": @"📊",
        @"SMA": @"〰️",
        @"Bollinger Bands": @"📏"
    };
    
    return icons[indicatorType] ?: @"📊";
}

#pragma mark - Template Management

- (void)saveTemplateWithName:(NSString *)templateName {
    // TODO: Implement template saving
    if (![self.savedTemplates containsObject:templateName]) {
        [self.savedTemplates addObject:templateName];
        [self refreshTemplatesList];
        [self.templateComboBox setStringValue:templateName];
        
        NSLog(@"💾 IndicatorsPanelController: Saved template '%@'", templateName);
    }
}

- (void)loadTemplateWithName:(NSString *)templateName {
    // TODO: Implement template loading
    NSLog(@"📁 IndicatorsPanelController: Loading template '%@'", templateName);
}

#pragma mark - NSTableViewDataSource

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    return self.availableIndicatorTypes.count;
}

#pragma mark - NSTableViewDelegate

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    NSString *identifier = @"IndicatorCell";
    NSTableCellView *cellView = [tableView makeViewWithIdentifier:identifier owner:self];
    
    if (!cellView) {
        cellView = [[NSTableCellView alloc] init];
        cellView.identifier = identifier;
        
        NSTextField *textField = [[NSTextField alloc] init];
        textField.translatesAutoresizingMaskIntoConstraints = NO;
        textField.bordered = NO;
        textField.backgroundColor = [NSColor clearColor];
        textField.editable = NO;
        
        cellView.textField = textField;
        [cellView addSubview:textField];
        
        [NSLayoutConstraint activateConstraints:@[
            [textField.centerYAnchor constraintEqualToAnchor:cellView.centerYAnchor],
            [textField.leadingAnchor constraintEqualToAnchor:cellView.leadingAnchor constant:8],
            [textField.trailingAnchor constraintEqualToAnchor:cellView.trailingAnchor constant:-8]
        ]];
    }
    
    cellView.textField.stringValue = self.availableIndicatorTypes[row];
    return cellView;
}

- (void)tableView:(NSTableView *)tableView didSelectRowAtIndexOfColumn:(NSInteger)column {
    // Handle double-click to add indicator
    NSInteger selectedRow = tableView.selectedRow;
    if (selectedRow >= 0 && selectedRow < self.availableIndicatorTypes.count) {
        [self addIndicatorToSelectedPanel:self.availableIndicatorTypes[selectedRow]];
    }
}

#pragma mark - Indicator Management

- (void)addIndicatorToSelectedPanel:(NSString *)indicatorType {
    // For now, add to the last panel (or create a new one if needed)
    ChartPanelModel *targetPanel = nil;
    
    if (self.chartWidget.panelModels.count > 0) {
        // Find a suitable panel for this indicator
        targetPanel = [self findSuitablePanelForIndicatorType:indicatorType];
    }
    
    // If no suitable panel found, create a new one
    if (!targetPanel) {
        targetPanel = [ChartPanelModel secondaryPanelWithTitle:[self titleForIndicatorType:indicatorType]];
        [self.chartWidget addPanelWithModel:targetPanel];
    }
    
    // Create the indicator renderer
    id<IndicatorRenderer> indicator = [self.chartWidget createIndicatorOfType:indicatorType];
    if (indicator) {
        [targetPanel addIndicator:indicator];
        [self.chartWidget refreshAllPanels];
        [self refreshPanelsList];
        
        NSLog(@"✅ IndicatorsPanelController: Added %@ to panel '%@'", indicatorType, targetPanel.title);
    }
}

- (ChartPanelModel *)findSuitablePanelForIndicatorType:(NSString *)indicatorType {
    // Volume indicators should go to volume panels
    if ([indicatorType isEqualToString:@"Volume"]) {
        for (ChartPanelModel *panel in self.chartWidget.panelModels) {
            if ([panel hasIndicatorOfType:@"Volume"]) {
                return panel;
            }
        }
    }
    
    // Oscillators (RSI, MACD) can share panels
    NSArray *oscillators = @[@"RSI", @"MACD"];
    if ([oscillators containsObject:indicatorType]) {
        for (ChartPanelModel *panel in self.chartWidget.panelModels) {
            if (panel.panelType == ChartPanelTypeSecondary) {
                // Check if panel has compatible indicators
                BOOL hasCompatibleIndicator = NO;
                for (id<IndicatorRenderer> existingIndicator in panel.indicators) {
                    if ([oscillators containsObject:[existingIndicator indicatorType]]) {
                        hasCompatibleIndicator = YES;
                        break;
                    }
                }
                if (hasCompatibleIndicator || panel.indicators.count == 0) {
                    return panel;
                }
            }
        }
    }
    
    // Price-based indicators (SMA, Bollinger Bands) go to main panel
    NSArray *priceIndicators = @[@"SMA", @"Bollinger Bands"];
    if ([priceIndicators containsObject:indicatorType]) {
        for (ChartPanelModel *panel in self.chartWidget.panelModels) {
            if (panel.panelType == ChartPanelTypeMain) {
                return panel;
            }
        }
    }
    
    return nil; // Will create new panel
}

- (NSString *)titleForIndicatorType:(NSString *)indicatorType {
    NSDictionary *titles = @{
        @"Volume": @"Volume",
        @"RSI": @"RSI",
        @"MACD": @"MACD",
        @"SMA": @"Moving Averages",
        @"Bollinger Bands": @"Bollinger Bands"
    };
    
    return titles[indicatorType] ?: indicatorType;
}

#pragma mark - Cleanup

- (void)dealloc {
    NSLog(@"🧹 IndicatorsPanelController: Deallocated");
}

@end
