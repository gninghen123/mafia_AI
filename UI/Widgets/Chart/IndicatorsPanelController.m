//
//  IndicatorsPanelController.m
//  TradingApp
//
//  Floating popup panel for managing chart indicators and templates
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
static const CGFloat kPanelHeight = 500.0;
static const CGFloat kAnimationDuration = 0.3;
static const CGFloat kPanelRowHeight = 60.0;
static const CGFloat kIndicatorRowHeight = 28.0;
static const CGFloat kCornerRadius = 12.0;
static const CGFloat kShadowRadius = 20.0;

@interface IndicatorsPanelController ()
@property (nonatomic, strong) NSMutableArray<NSView *> *panelRowViews;
@property (nonatomic, strong) TemplateManager *templateManager;
@property (nonatomic, strong) NSWindow *popupWindow;

// UI Components
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
    // Create main panel view with modern styling
    self.panelView = [[NSVisualEffectView alloc] init];
    NSVisualEffectView *effectView = (NSVisualEffectView *)self.panelView;
    effectView.material = NSVisualEffectMaterialPopover;
    effectView.blendingMode = NSVisualEffectBlendingModeBehindWindow;
    effectView.state = NSVisualEffectStateActive;
    effectView.wantsLayer = YES;
    effectView.layer.cornerRadius = kCornerRadius;
    effectView.layer.masksToBounds = YES;
    
    self.panelView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.panelView];
    
    [self createHeader];
    [self createTemplateSection];
    [self createPanelsSection];
    [self createIndicatorsSection];
}

- (void)createHeader {
    // Header label
    self.headerLabel = [[NSTextField alloc] init];
    self.headerLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.headerLabel.stringValue = @"Chart Indicators";
    self.headerLabel.font = [NSFont boldSystemFontOfSize:16];
    self.headerLabel.textColor = [NSColor labelColor];
    self.headerLabel.editable = NO;
    self.headerLabel.bordered = NO;
    self.headerLabel.backgroundColor = [NSColor clearColor];
    [self.panelView addSubview:self.headerLabel];
    
    // Close button with modern styling
    self.closeButton = [[NSButton alloc] init];
    self.closeButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.closeButton.buttonType = NSButtonTypeMomentaryPushIn;
    self.closeButton.bordered = NO;
    self.closeButton.title = @"✕";
    self.closeButton.font = [NSFont systemFontOfSize:14];
    self.closeButton.target = self;
    self.closeButton.action = @selector(closeButtonClicked:);
    
    // Style close button
    self.closeButton.wantsLayer = YES;
    self.closeButton.layer.cornerRadius = 12;
    self.closeButton.layer.backgroundColor = [[NSColor controlAccentColor] colorWithAlphaComponent:0.1].CGColor;
    [self.panelView addSubview:self.closeButton];
}

- (void)createTemplateSection {
    // Template section label
    self.templateLabel = [[NSTextField alloc] init];
    self.templateLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.templateLabel.stringValue = @"Templates";
    self.templateLabel.font = [NSFont boldSystemFontOfSize:13];
    self.templateLabel.textColor = [NSColor secondaryLabelColor];
    self.templateLabel.editable = NO;
    self.templateLabel.bordered = NO;
    self.templateLabel.backgroundColor = [NSColor clearColor];
    [self.panelView addSubview:self.templateLabel];
    
    // Template combo box
    self.templateComboBox = [[NSComboBox alloc] init];
    self.templateComboBox.translatesAutoresizingMaskIntoConstraints = NO;
    self.templateComboBox.editable = NO;
    [self.templateComboBox addItemsWithObjectValues:self.savedTemplates];
    [self.templateComboBox selectItemAtIndex:0];
    [self.panelView addSubview:self.templateComboBox];
    
    // Save template button
    self.saveTemplateButton = [[NSButton alloc] init];
    self.saveTemplateButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.saveTemplateButton.buttonType = NSButtonTypeMomentaryPushIn;
    self.saveTemplateButton.title = @"💾";
    self.saveTemplateButton.target = self;
    self.saveTemplateButton.action = @selector(saveTemplateButtonClicked:);
    self.saveTemplateButton.toolTip = @"Save current layout as template";
    [self.panelView addSubview:self.saveTemplateButton];
    
    // Load template button
    self.loadTemplateButton = [[NSButton alloc] init];
    self.loadTemplateButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.loadTemplateButton.buttonType = NSButtonTypeMomentaryPushIn;
    self.loadTemplateButton.title = @"📁";
    self.loadTemplateButton.target = self;
    self.loadTemplateButton.action = @selector(loadTemplateButtonClicked:);
    self.loadTemplateButton.toolTip = @"Load selected template";
    [self.panelView addSubview:self.loadTemplateButton];
}

- (void)createPanelsSection {
    // Panels label
    NSTextField *panelsLabel = [[NSTextField alloc] init];
    panelsLabel.translatesAutoresizingMaskIntoConstraints = NO;
    panelsLabel.stringValue = @"Chart Panels";
    panelsLabel.font = [NSFont boldSystemFontOfSize:13];
    panelsLabel.textColor = [NSColor secondaryLabelColor];
    panelsLabel.editable = NO;
    panelsLabel.bordered = NO;
    panelsLabel.backgroundColor = [NSColor clearColor];
    [self.panelView addSubview:panelsLabel];
    
    // Panels scroll view
    self.panelsScrollView = [[NSScrollView alloc] init];
    self.panelsScrollView.translatesAutoresizingMaskIntoConstraints = NO;
    self.panelsScrollView.hasVerticalScroller = YES;
    self.panelsScrollView.hasHorizontalScroller = NO;
    self.panelsScrollView.autohidesScrollers = YES;
    self.panelsScrollView.borderType = NSLineBorder;
    self.panelsScrollView.wantsLayer = YES;
    self.panelsScrollView.layer.cornerRadius = 6;
    [self.panelView addSubview:self.panelsScrollView];
    
    // Panels stack view (document view)
    self.panelsStackView = [[NSStackView alloc] init];
    self.panelsStackView.translatesAutoresizingMaskIntoConstraints = NO;
    self.panelsStackView.orientation = NSUserInterfaceLayoutOrientationVertical;
    self.panelsStackView.alignment = NSLayoutAttributeLeading;
    self.panelsStackView.distribution = NSStackViewDistributionFill;
    self.panelsStackView.spacing = 2;
    self.panelsScrollView.documentView = self.panelsStackView;
    
    // Add panel button
    self.addPanelButton = [[NSButton alloc] init];
    self.addPanelButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.addPanelButton.buttonType = NSButtonTypeMomentaryPushIn;
    self.addPanelButton.title = @"+ Add Panel";
    self.addPanelButton.target = self;
    self.addPanelButton.action = @selector(addPanelButtonClicked:);
    [self.panelView addSubview:self.addPanelButton];
    
    // Set constraints for panels label
    [NSLayoutConstraint activateConstraints:@[
        [panelsLabel.topAnchor constraintEqualToAnchor:self.templateComboBox.bottomAnchor constant:20],
        [panelsLabel.leadingAnchor constraintEqualToAnchor:self.panelView.leadingAnchor constant:16]
    ]];
}

- (void)createIndicatorsSection {
    // Available indicators label
    self.availableLabel = [[NSTextField alloc] init];
    self.availableLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.availableLabel.stringValue = @"Available Indicators";
    self.availableLabel.font = [NSFont boldSystemFontOfSize:13];
    self.availableLabel.textColor = [NSColor secondaryLabelColor];
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
    self.availableScrollView.wantsLayer = YES;
    self.availableScrollView.layer.cornerRadius = 6;
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
        // Panel view - centered in parent with fixed size
        [self.panelView.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.panelView.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor],
        [self.panelView.widthAnchor constraintEqualToConstant:kPanelWidth],
        [self.panelView.heightAnchor constraintEqualToConstant:kPanelHeight],
        
        // Header
        [self.headerLabel.topAnchor constraintEqualToAnchor:self.panelView.topAnchor constant:16],
        [self.headerLabel.leadingAnchor constraintEqualToAnchor:self.panelView.leadingAnchor constant:16],
        
        [self.closeButton.topAnchor constraintEqualToAnchor:self.panelView.topAnchor constant:12],
        [self.closeButton.trailingAnchor constraintEqualToAnchor:self.panelView.trailingAnchor constant:-12],
        [self.closeButton.widthAnchor constraintEqualToConstant:24],
        [self.closeButton.heightAnchor constraintEqualToConstant:24],
        
        // Template section
        [self.templateLabel.topAnchor constraintEqualToAnchor:self.headerLabel.bottomAnchor constant:20],
        [self.templateLabel.leadingAnchor constraintEqualToAnchor:self.panelView.leadingAnchor constant:16],
        
        [self.templateComboBox.topAnchor constraintEqualToAnchor:self.templateLabel.bottomAnchor constant:6],
        [self.templateComboBox.leadingAnchor constraintEqualToAnchor:self.panelView.leadingAnchor constant:16],
        [self.templateComboBox.widthAnchor constraintEqualToConstant:180],
        
        [self.saveTemplateButton.centerYAnchor constraintEqualToAnchor:self.templateComboBox.centerYAnchor],
        [self.saveTemplateButton.leadingAnchor constraintEqualToAnchor:self.templateComboBox.trailingAnchor constant:8],
        [self.saveTemplateButton.widthAnchor constraintEqualToConstant:30],
        
        [self.loadTemplateButton.centerYAnchor constraintEqualToAnchor:self.templateComboBox.centerYAnchor],
        [self.loadTemplateButton.leadingAnchor constraintEqualToAnchor:self.saveTemplateButton.trailingAnchor constant:4],
        [self.loadTemplateButton.widthAnchor constraintEqualToConstant:30],
        
        // Panels section
        [self.panelsScrollView.topAnchor constraintEqualToAnchor:self.templateComboBox.bottomAnchor constant:40],
        [self.panelsScrollView.leadingAnchor constraintEqualToAnchor:self.panelView.leadingAnchor constant:16],
        [self.panelsScrollView.trailingAnchor constraintEqualToAnchor:self.panelView.trailingAnchor constant:-16],
        [self.panelsScrollView.heightAnchor constraintEqualToConstant:120],
        
        [self.addPanelButton.topAnchor constraintEqualToAnchor:self.panelsScrollView.bottomAnchor constant:8],
        [self.addPanelButton.leadingAnchor constraintEqualToAnchor:self.panelView.leadingAnchor constant:16],
        [self.addPanelButton.trailingAnchor constraintEqualToAnchor:self.panelView.trailingAnchor constant:-16],
        
        // Available indicators section
        [self.availableLabel.topAnchor constraintEqualToAnchor:self.addPanelButton.bottomAnchor constant:20],
        [self.availableLabel.leadingAnchor constraintEqualToAnchor:self.panelView.leadingAnchor constant:16],
        
        [self.availableScrollView.topAnchor constraintEqualToAnchor:self.availableLabel.bottomAnchor constant:8],
        [self.availableScrollView.leadingAnchor constraintEqualToAnchor:self.panelView.leadingAnchor constant:16],
        [self.availableScrollView.trailingAnchor constraintEqualToAnchor:self.panelView.trailingAnchor constant:-16],
        [self.availableScrollView.bottomAnchor constraintEqualToAnchor:self.panelView.bottomAnchor constant:-16]
    ]];
}

#pragma mark - Popup Window Management

- (void)showPanel {
    if (self.isVisible) return;
    
    NSWindow *parentWindow = self.chartWidget.view.window;
    if (!parentWindow) {
        NSLog(@"⚠️ IndicatorsPanelController: No parent window");
        return;
    }
    
    // Create popup window
    NSRect popupRect = NSMakeRect(0, 0, kPanelWidth + 40, kPanelHeight + 40);
    self.popupWindow = [[NSWindow alloc] initWithContentRect:popupRect
                                                   styleMask:NSWindowStyleMaskBorderless
                                                     backing:NSBackingStoreBuffered
                                                       defer:NO];
    
    self.popupWindow.backgroundColor = [NSColor clearColor];
    self.popupWindow.opaque = NO;
    self.popupWindow.hasShadow = YES;
    self.popupWindow.level = NSFloatingWindowLevel;
    self.popupWindow.contentView = self.view;
    
    // Position popup near the indicators button
    NSRect chartFrame = [self.chartWidget.view convertRect:self.chartWidget.view.bounds toView:nil];
    NSRect screenFrame = [parentWindow convertRectToScreen:chartFrame];
    
    // Position at top-right of chart widget
    CGFloat popupX = screenFrame.origin.x + screenFrame.size.width - kPanelWidth - 20;
    CGFloat popupY = screenFrame.origin.y + screenFrame.size.height - kPanelHeight - 20;
    
    NSRect finalFrame = NSMakeRect(popupX, popupY, kPanelWidth + 40, kPanelHeight + 40);
    [self.popupWindow setFrame:finalFrame display:NO];
    
    // Add shadow effect
    self.popupWindow.contentView.wantsLayer = YES;
    self.popupWindow.contentView.shadow = [[NSShadow alloc] init];
    self.popupWindow.contentView.shadow.shadowOffset = NSMakeSize(0, -8);
    self.popupWindow.contentView.shadow.shadowBlurRadius = kShadowRadius;
    self.popupWindow.contentView.shadow.shadowColor = [[NSColor blackColor] colorWithAlphaComponent:0.3];
    
    // Show with animation
    self.popupWindow.alphaValue = 0.0;
    NSRect startFrame = finalFrame;
    startFrame.origin.y += 20; // Start slightly lower
    [self.popupWindow setFrame:startFrame display:NO];
    
    [parentWindow addChildWindow:self.popupWindow ordered:NSWindowAbove];
    [self.popupWindow makeKeyAndOrderFront:nil];
    
    [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
        context.duration = kAnimationDuration;
        context.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut];
        
        self.popupWindow.animator.alphaValue = 1.0;
        [self.popupWindow.animator setFrame:finalFrame display:YES];
        
    } completionHandler:^{
        self.isVisible = YES;
        [self refreshPanelsList];
        NSLog(@"✅ IndicatorsPanelController: Popup shown");
    }];
}

- (void)hidePanel {
    if (!self.isVisible || !self.popupWindow) return;
    
    [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
        context.duration = kAnimationDuration;
        context.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseIn];
        
        self.popupWindow.animator.alphaValue = 0.0;
        
        // Animate out slightly upward
        NSRect currentFrame = self.popupWindow.frame;
        currentFrame.origin.y += 20;
        [self.popupWindow.animator setFrame:currentFrame display:YES];
        
    } completionHandler:^{
        [self.popupWindow.parentWindow removeChildWindow:self.popupWindow];
        [self.popupWindow orderOut:nil];
        self.popupWindow = nil;
        self.isVisible = NO;
        NSLog(@"✅ IndicatorsPanelController: Popup hidden");
    }];
}

- (void)togglePanel {
    if (self.isVisible) {
        [self hidePanel];
    } else {
        [self showPanel];
    }
}

#pragma mark - Panel Management

- (void)refreshPanelsList {
    // Clear existing rows
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
    
    NSLog(@"🔄 IndicatorsPanelController: Refreshed panels list (%ld panels)", self.chartWidget.panelModels.count);
}

- (NSView *)createPanelRowForModel:(ChartPanelModel *)panelModel atIndex:(NSInteger)index {
    NSView *rowView = [[NSView alloc] init];
    rowView.translatesAutoresizingMaskIntoConstraints = NO;
    rowView.wantsLayer = YES;
    rowView.layer.backgroundColor = [[NSColor controlBackgroundColor] colorWithAlphaComponent:0.5].CGColor;
    rowView.layer.cornerRadius = 6;
    
    // Panel title
    NSTextField *titleLabel = [[NSTextField alloc] init];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.stringValue = panelModel.title;
    titleLabel.font = [NSFont boldSystemFontOfSize:12];
    titleLabel.editable = NO;
    titleLabel.bordered = NO;
    titleLabel.backgroundColor = [NSColor clearColor];
    titleLabel.textColor = [NSColor labelColor];
    [rowView addSubview:titleLabel];
    
    // Delete button (only for deletable panels)
    NSButton *deleteButton = nil;
    if (panelModel.canBeDeleted) {
        deleteButton = [[NSButton alloc] init];
        deleteButton.translatesAutoresizingMaskIntoConstraints = NO;
        deleteButton.buttonType = NSButtonTypeMomentaryPushIn;
        deleteButton.bordered = NO;
        deleteButton.title = @"🗑";
        deleteButton.font = [NSFont systemFontOfSize:12];
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
        
        [titleLabel.topAnchor constraintEqualToAnchor:rowView.topAnchor constant:6],
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

#pragma mark - Table View Data Source & Delegate

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    return self.availableIndicatorTypes.count;
}

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    NSTableCellView *cellView = [tableView makeViewWithIdentifier:@"IndicatorCell" owner:self];
    
    if (!cellView) {
        cellView = [[NSTableCellView alloc] init];
        cellView.identifier = @"IndicatorCell";
        
        NSTextField *textField = [[NSTextField alloc] init];
        textField.editable = NO;
        textField.bordered = NO;
        textField.backgroundColor = [NSColor clearColor];
        textField.font = [NSFont systemFontOfSize:12];
        textField.translatesAutoresizingMaskIntoConstraints = NO;
        [cellView addSubview:textField];
        cellView.textField = textField;
        
        [NSLayoutConstraint activateConstraints:@[
            [textField.leadingAnchor constraintEqualToAnchor:cellView.leadingAnchor constant:8],
            [textField.trailingAnchor constraintEqualToAnchor:cellView.trailingAnchor constant:-8],
            [textField.centerYAnchor constraintEqualToAnchor:cellView.centerYAnchor]
        ]];
    }
    
    NSString *indicatorType = self.availableIndicatorTypes[row];
    NSString *icon = [self iconForIndicatorType:indicatorType];
    cellView.textField.stringValue = [NSString stringWithFormat:@"%@ %@", icon, indicatorType];
    
    return cellView;
}

- (void)tableView:(NSTableView *)tableView didSelectRowAtIndexOfColumn:(NSInteger)column {
    // Handle selection
    NSInteger selectedRow = tableView.selectedRow;
    if (selectedRow >= 0 && selectedRow < self.availableIndicatorTypes.count) {
        [self addIndicatorToSelectedPanel:self.availableIndicatorTypes[selectedRow]];
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
    
    [alert beginSheetModalForWindow:self.popupWindow completionHandler:^(NSModalResponse returnCode) {
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
            if (panel.panelType == ChartPanelTypeMain) {
                return panel;
            }
        }
    }
    
    // Other indicators can go to any secondary panel
    for (ChartPanelModel *panel in self.chartWidget.panelModels) {
        if (panel.panelType == ChartPanelTypeSecondary) {
            return panel;
        }
    }
    
    return nil; // Will create new panel
}

- (NSString *)titleForIndicatorType:(NSString *)indicatorType {
    if ([indicatorType isEqualToString:@"Volume"]) {
        return @"Volume";
    } else if ([indicatorType isEqualToString:@"RSI"]) {
        return @"RSI";
    } else if ([indicatorType isEqualToString:@"MACD"]) {
        return @"MACD";
    } else if ([indicatorType isEqualToString:@"SMA"]) {
        return @"Moving Averages";
    } else if ([indicatorType isEqualToString:@"Bollinger Bands"]) {
        return @"Bollinger Bands";
    }
    
    return @"Indicators";
}

#pragma mark - Template Management

- (void)saveTemplateWithName:(NSString *)templateName {
    // TODO: Implement template saving
    if (![self.savedTemplates containsObject:templateName]) {
        [self.savedTemplates addObject:templateName];
        [self.templateComboBox removeAllItems];
        [self.templateComboBox addItemsWithObjectValues:self.savedTemplates];
        [self.templateComboBox selectItemWithObjectValue:templateName];
        
        NSLog(@"💾 IndicatorsPanelController: Saved template '%@'", templateName);
    }
}

- (void)loadTemplateWithName:(NSString *)templateName {
    // TODO: Implement template loading
    NSLog(@"📁 IndicatorsPanelController: Loading template '%@'", templateName);
}

#pragma mark - Window Delegate

- (void)windowWillClose:(NSNotification *)notification {
    if (notification.object == self.popupWindow) {
        self.isVisible = NO;
        self.popupWindow = nil;
    }
}

@end
