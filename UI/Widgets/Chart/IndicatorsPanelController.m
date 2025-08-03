//
//  IndicatorsPanelController.m
//  TradingApp
//
//  Interactive indicators panel with split view and table views for each panel
//

#import "IndicatorsPanelController.h"
#import "ChartWidget.h"
#import "ChartPanelModel.h"
#import "IndicatorRenderer.h"
#import "RuntimeModels.h"
#import <QuartzCore/QuartzCore.h>

// Renderers imports
#import "VolumeRenderer.h"

static const CGFloat kPanelWidth = 350;
static const CGFloat kPanelHeight = 600;
static const CGFloat kAnimationDuration = 0.3;
static const CGFloat kCornerRadius = 12.0;
static const CGFloat kShadowRadius = 20.0;

// Drag & Drop
static NSString * const kIndicatorPasteboardType = @"com.tradingapp.indicator";
static NSString * const kAvailableIndicatorPasteboardType = @"com.tradingapp.available-indicator";

@class IndicatorsPanelController;

@interface PanelTableViewContainer : NSView
@property (nonatomic, strong) NSTextField *titleLabel;
@property (nonatomic, strong) NSButton *deleteButton;
@property (nonatomic, strong) NSButton *addIndicatorButton;
@property (nonatomic, strong) NSScrollView *tableScrollView;
@property (nonatomic, strong) NSTableView *tableView;
@property (nonatomic, strong) ChartPanelModel *panelModel;
@property (nonatomic, weak) IndicatorsPanelController *controller;

- (instancetype)initWithPanelModel:(ChartPanelModel *)panelModel controller:(IndicatorsPanelController *)controller;
@end

@interface IndicatorsPanelController ()
@property (nonatomic, strong) NSMutableArray<PanelTableViewContainer *> *panelContainers;
@property (nonatomic, strong) NSWindow *popupWindow;
@property (nonatomic, strong) NSSplitView *mainSplitView;

// Available indicators table
@property (nonatomic, strong) NSTableView *availableIndicatorsTable;
@property (nonatomic, strong) NSScrollView *availableIndicatorsScrollView;
@end

@implementation PanelTableViewContainer

- (instancetype)initWithPanelModel:(ChartPanelModel *)panelModel controller:(IndicatorsPanelController *)controller {
    self = [super init];
    if (self) {
        _panelModel = panelModel;
        _controller = controller;
        [self setupUI];
        [self setupConstraints];
    }
    return self;
}

- (void)setupUI {
    self.translatesAutoresizingMaskIntoConstraints = NO;
    self.wantsLayer = YES;
    self.layer.backgroundColor = [[NSColor controlBackgroundColor] colorWithAlphaComponent:0.3].CGColor;
    self.layer.cornerRadius = 8;
    self.layer.borderWidth = 1;
    self.layer.borderColor = [[NSColor separatorColor] colorWithAlphaComponent:0.5].CGColor;
    
    // Title label
    self.titleLabel = [[NSTextField alloc] init];
    self.titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.titleLabel.stringValue = self.panelModel.title;
    self.titleLabel.font = [NSFont boldSystemFontOfSize:13];
    self.titleLabel.editable = NO;
    self.titleLabel.bordered = NO;
    self.titleLabel.backgroundColor = [NSColor clearColor];
    self.titleLabel.textColor = [NSColor labelColor];
    [self addSubview:self.titleLabel];
    
    // Delete button (only for deletable panels)
    if (self.panelModel.canBeDeleted) {
        self.deleteButton = [[NSButton alloc] init];
        self.deleteButton.translatesAutoresizingMaskIntoConstraints = NO;
        self.deleteButton.buttonType = NSButtonTypeMomentaryPushIn;
        self.deleteButton.bordered = NO;
        self.deleteButton.title = @"🗑";
        self.deleteButton.font = [NSFont systemFontOfSize:12];
        self.deleteButton.toolTip = @"Delete Panel";
        self.deleteButton.target = self;
        self.deleteButton.action = @selector(deleteButtonClicked:);
        [self addSubview:self.deleteButton];
    }
    
    // Add indicator button
    self.addIndicatorButton = [[NSButton alloc] init];
    self.addIndicatorButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.addIndicatorButton.buttonType = NSButtonTypeMomentaryPushIn;
    self.addIndicatorButton.bordered = NO;
    self.addIndicatorButton.title = @"➕";
    self.addIndicatorButton.font = [NSFont systemFontOfSize:10];
    self.addIndicatorButton.toolTip = @"Add Indicator to Panel";
    self.addIndicatorButton.target = self;
    self.addIndicatorButton.action = @selector(addIndicatorButtonClicked:);
    [self addSubview:self.addIndicatorButton];
    
    // Table scroll view
    self.tableScrollView = [[NSScrollView alloc] init];
    self.tableScrollView.translatesAutoresizingMaskIntoConstraints = NO;
    self.tableScrollView.hasVerticalScroller = YES;
    self.tableScrollView.hasHorizontalScroller = NO;
    self.tableScrollView.autohidesScrollers = YES;
    self.tableScrollView.borderType = NSNoBorder;
    [self addSubview:self.tableScrollView];
    
    // Table view
    self.tableView = [[NSTableView alloc] init];
    self.tableView.translatesAutoresizingMaskIntoConstraints = NO;
    self.tableView.rowHeight = 24;
    self.tableView.headerView = nil;
    self.tableView.dataSource = self.controller;
    self.tableView.delegate = self.controller;
    self.tableView.allowsMultipleSelection = NO;
    self.tableView.intercellSpacing = NSMakeSize(0, 1);
    
    // Enable drag & drop
    [self.tableView registerForDraggedTypes:@[kAvailableIndicatorPasteboardType, kIndicatorPasteboardType]];
    
    // Add column
    NSTableColumn *column = [[NSTableColumn alloc] initWithIdentifier:@"indicator"];
    column.title = @"Indicators";
    column.width = 250;
    [self.tableView addTableColumn:column];
    
    self.tableScrollView.documentView = self.tableView;
}


- (void)setupConstraints {
    [NSLayoutConstraint activateConstraints:@[
        // Title
        [self.titleLabel.topAnchor constraintEqualToAnchor:self.topAnchor constant:8],
        [self.titleLabel.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:12],
        [self.titleLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.addIndicatorButton.leadingAnchor constant:-8],
        
        // Add button
        [self.addIndicatorButton.centerYAnchor constraintEqualToAnchor:self.titleLabel.centerYAnchor],
        [self.addIndicatorButton.trailingAnchor constraintEqualToAnchor:self.deleteButton ? self.deleteButton.leadingAnchor : self.trailingAnchor constant:self.deleteButton ? -4 : -8],
        [self.addIndicatorButton.widthAnchor constraintEqualToConstant:20],
        [self.addIndicatorButton.heightAnchor constraintEqualToConstant:20],
        
        // Table scroll view - CORREZIONE: Assicura che occupi tutto lo spazio
        [self.tableScrollView.topAnchor constraintEqualToAnchor:self.titleLabel.bottomAnchor constant:8],
        [self.tableScrollView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:8],
        [self.tableScrollView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-8],
        [self.tableScrollView.bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:-8],
        
        // AGGIUNTA: Constraint minimo per l'altezza della table
        [self.tableScrollView.heightAnchor constraintGreaterThanOrEqualToConstant:60]
    ]];
    
    if (self.deleteButton) {
        [NSLayoutConstraint activateConstraints:@[
            [self.deleteButton.centerYAnchor constraintEqualToAnchor:self.titleLabel.centerYAnchor],
            [self.deleteButton.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-8],
            [self.deleteButton.widthAnchor constraintEqualToConstant:20],
            [self.deleteButton.heightAnchor constraintEqualToConstant:20]
        ]];
    }
    
    // CORREZIONE: Force layout subito dopo i constraints
    [self layoutSubtreeIfNeeded];
}

- (void)deleteButtonClicked:(id)sender {
    [self.controller deletePanelModel:self.panelModel];
}

- (void)addIndicatorButtonClicked:(id)sender {
    [self.controller showAddIndicatorPopupForPanel:self.panelModel sourceButton:sender];
}

@end

@implementation IndicatorsPanelController

#pragma mark - Initialization

- (instancetype)initWithChartWidget:(ChartWidget *)chartWidget {
    self = [super init];
    if (self) {
        _chartWidget = chartWidget;
        _isVisible = NO;
        _panelContainers = [NSMutableArray array];
        
        // Initialize available indicator types
        _availableIndicatorTypes = @[
            @"Volume",
            @"RSI",
            @"MACD",
            @"SMA",
            @"EMA",
            @"Bollinger Bands",
            @"Stochastic",
            @"CCI",
            @"Williams %R"
        ];
        
        _savedTemplates = [NSMutableArray arrayWithArray:@[@"Default", @"Technical", @"Volume Analysis"]];
        
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
    [self createMainSplitView];
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
    
    // Close button
    self.closeButton = [[NSButton alloc] init];
    self.closeButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.closeButton.buttonType = NSButtonTypeMomentaryPushIn;
    self.closeButton.bordered = NO;
    self.closeButton.title = @"✕";
    self.closeButton.font = [NSFont systemFontOfSize:14];
    self.closeButton.target = self;
    self.closeButton.action = @selector(closeButtonClicked:);
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
    
    // Save/Load buttons
    self.saveTemplateButton = [[NSButton alloc] init];
    self.saveTemplateButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.saveTemplateButton.buttonType = NSButtonTypeMomentaryPushIn;
    self.saveTemplateButton.title = @"💾";
    self.saveTemplateButton.target = self;
    self.saveTemplateButton.action = @selector(saveTemplateButtonClicked:);
    self.saveTemplateButton.toolTip = @"Save current layout as template";
    [self.panelView addSubview:self.saveTemplateButton];
    
    self.loadTemplateButton = [[NSButton alloc] init];
    self.loadTemplateButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.loadTemplateButton.buttonType = NSButtonTypeMomentaryPushIn;
    self.loadTemplateButton.title = @"📁";
    self.loadTemplateButton.target = self;
    self.loadTemplateButton.action = @selector(loadTemplateButtonClicked:);
    self.loadTemplateButton.toolTip = @"Load selected template";
    [self.panelView addSubview:self.loadTemplateButton];
}

- (void)createMainSplitView {
    // Main split view
    self.mainSplitView = [[NSSplitView alloc] init];
    self.mainSplitView.translatesAutoresizingMaskIntoConstraints = NO;
    self.mainSplitView.vertical = NO; // Horizontal split
    self.mainSplitView.dividerStyle = NSSplitViewDividerStyleThin;
    [self.panelView addSubview:self.mainSplitView];
    
    // Top part: Panels with their indicators
    NSView *panelsContainerView = [self createPanelsContainerView];
    [self.mainSplitView addSubview:panelsContainerView];
    
    // Bottom part: Available indicators
    NSView *availableIndicatorsView = [self createAvailableIndicatorsView];
    [self.mainSplitView addSubview:availableIndicatorsView];
    
    // Set initial split proportions (70% panels, 30% available)
    [self.mainSplitView setPosition:(kPanelHeight - 140) * 0.65 ofDividerAtIndex:0];
}

- (NSView *)createPanelsContainerView {
    NSView *containerView = [[NSView alloc] init];
    containerView.translatesAutoresizingMaskIntoConstraints = NO;
    
    // Title
    NSTextField *titleLabel = [[NSTextField alloc] init];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.stringValue = @"Chart Panels";
    titleLabel.font = [NSFont boldSystemFontOfSize:13];
    titleLabel.textColor = [NSColor secondaryLabelColor];
    titleLabel.editable = NO;
    titleLabel.bordered = NO;
    titleLabel.backgroundColor = [NSColor clearColor];
    [containerView addSubview:titleLabel];
    
    // Add panel button
    NSButton *addPanelButton = [[NSButton alloc] init];
    addPanelButton.translatesAutoresizingMaskIntoConstraints = NO;
    addPanelButton.buttonType = NSButtonTypeMomentaryPushIn;
    addPanelButton.title = @"+ Add Panel";
    addPanelButton.target = self;
    addPanelButton.action = @selector(addPanelButtonClicked:);
    [containerView addSubview:addPanelButton];
    
    // Scroll view for panels
    self.panelsScrollView = [[NSScrollView alloc] init];
    self.panelsScrollView.translatesAutoresizingMaskIntoConstraints = NO;
    self.panelsScrollView.hasVerticalScroller = YES;
    self.panelsScrollView.hasHorizontalScroller = NO;
    self.panelsScrollView.autohidesScrollers = YES;
    self.panelsScrollView.borderType = NSNoBorder;
    [containerView addSubview:self.panelsScrollView];
    
    // Stack view for panel containers
    self.panelsStackView = [[NSStackView alloc] init];
    self.panelsStackView.translatesAutoresizingMaskIntoConstraints = NO;
    self.panelsStackView.orientation = NSUserInterfaceLayoutOrientationVertical;
    self.panelsStackView.alignment = NSLayoutAttributeLeading;
    self.panelsStackView.distribution = NSStackViewDistributionFill;
    self.panelsStackView.spacing = 8;
    self.panelsScrollView.documentView = self.panelsStackView;
    
    // Constraints
    [NSLayoutConstraint activateConstraints:@[
        [titleLabel.topAnchor constraintEqualToAnchor:containerView.topAnchor constant:8],
        [titleLabel.leadingAnchor constraintEqualToAnchor:containerView.leadingAnchor constant:12],
        
        [addPanelButton.centerYAnchor constraintEqualToAnchor:titleLabel.centerYAnchor],
        [addPanelButton.trailingAnchor constraintEqualToAnchor:containerView.trailingAnchor constant:-12],
        
        [self.panelsScrollView.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:8],
        [self.panelsScrollView.leadingAnchor constraintEqualToAnchor:containerView.leadingAnchor constant:8],
        [self.panelsScrollView.trailingAnchor constraintEqualToAnchor:containerView.trailingAnchor constant:-8],
        [self.panelsScrollView.bottomAnchor constraintEqualToAnchor:containerView.bottomAnchor constant:-8]
    ]];
    
    return containerView;
}

- (NSView *)createAvailableIndicatorsView {
    NSView *containerView = [[NSView alloc] init];
    containerView.translatesAutoresizingMaskIntoConstraints = NO;
    
    // Title
    self.availableLabel = [[NSTextField alloc] init];
    self.availableLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.availableLabel.stringValue = @"Available Indicators (drag to panels above)";
    self.availableLabel.font = [NSFont boldSystemFontOfSize:13];
    self.availableLabel.textColor = [NSColor secondaryLabelColor];
    self.availableLabel.editable = NO;
    self.availableLabel.bordered = NO;
    self.availableLabel.backgroundColor = [NSColor clearColor];
    [containerView addSubview:self.availableLabel];
    
    // Available indicators scroll view
    self.availableIndicatorsScrollView = [[NSScrollView alloc] init];
    self.availableIndicatorsScrollView.translatesAutoresizingMaskIntoConstraints = NO;
    self.availableIndicatorsScrollView.hasVerticalScroller = YES;
    self.availableIndicatorsScrollView.hasHorizontalScroller = NO;
    self.availableIndicatorsScrollView.autohidesScrollers = YES;
    self.availableIndicatorsScrollView.borderType = NSLineBorder;
    self.availableIndicatorsScrollView.wantsLayer = YES;
    self.availableIndicatorsScrollView.layer.cornerRadius = 6;
    [containerView addSubview:self.availableIndicatorsScrollView];
    
    // Available indicators table
    self.availableIndicatorsTable = [[NSTableView alloc] init];
    self.availableIndicatorsTable.translatesAutoresizingMaskIntoConstraints = NO;
    self.availableIndicatorsTable.rowHeight = 24;
    self.availableIndicatorsTable.headerView = nil;
    self.availableIndicatorsTable.dataSource = self;
    self.availableIndicatorsTable.delegate = self;
    self.availableIndicatorsTable.allowsMultipleSelection = NO;
    
    // Enable drag from available indicators
    [self.availableIndicatorsTable setDraggingSourceOperationMask:NSDragOperationCopy forLocal:NO];
    
    // Add column
    NSTableColumn *column = [[NSTableColumn alloc] initWithIdentifier:@"available"];
    column.title = @"Available";
    column.width = 280;
    [self.availableIndicatorsTable addTableColumn:column];
    
    self.availableIndicatorsScrollView.documentView = self.availableIndicatorsTable;
    
    // Constraints
    [NSLayoutConstraint activateConstraints:@[
        [self.availableLabel.topAnchor constraintEqualToAnchor:containerView.topAnchor constant:8],
        [self.availableLabel.leadingAnchor constraintEqualToAnchor:containerView.leadingAnchor constant:12],
        
        [self.availableIndicatorsScrollView.topAnchor constraintEqualToAnchor:self.availableLabel.bottomAnchor constant:8],
        [self.availableIndicatorsScrollView.leadingAnchor constraintEqualToAnchor:containerView.leadingAnchor constant:8],
        [self.availableIndicatorsScrollView.trailingAnchor constraintEqualToAnchor:containerView.trailingAnchor constant:-8],
        [self.availableIndicatorsScrollView.bottomAnchor constraintEqualToAnchor:containerView.bottomAnchor constant:-8]
    ]];
    
    return containerView;
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
        [self.templateLabel.topAnchor constraintEqualToAnchor:self.headerLabel.bottomAnchor constant:16],
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
        
        // Main split view
        [self.mainSplitView.topAnchor constraintEqualToAnchor:self.templateComboBox.bottomAnchor constant:16],
        [self.mainSplitView.leadingAnchor constraintEqualToAnchor:self.panelView.leadingAnchor constant:12],
        [self.mainSplitView.trailingAnchor constraintEqualToAnchor:self.panelView.trailingAnchor constant:-12],
        [self.mainSplitView.bottomAnchor constraintEqualToAnchor:self.panelView.bottomAnchor constant:-12]
    ]];
}

#pragma mark - Popup Window Management

- (void)showPanel {
    if (self.isVisible) return;
    
    NSWindow *parentWindow = self.chartWidget.view.window;
    if (!parentWindow) {
        NSLog(@"⚠️ No parent window found");
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
    
    // Position popup
    NSRect chartFrame = [self.chartWidget.view convertRect:self.chartWidget.view.bounds toView:nil];
    NSRect screenFrame = [parentWindow convertRectToScreen:chartFrame];
    
    CGFloat popupX = screenFrame.origin.x + screenFrame.size.width - kPanelWidth - 20;
    CGFloat popupY = screenFrame.origin.y + screenFrame.size.height - kPanelHeight - 20;
    
    NSRect finalFrame = NSMakeRect(popupX, popupY, kPanelWidth + 40, kPanelHeight + 40);
    [self.popupWindow setFrame:finalFrame display:NO];
    
    [parentWindow addChildWindow:self.popupWindow ordered:NSWindowAbove];
    [self.popupWindow makeKeyAndOrderFront:nil];
    
    self.isVisible = YES;
    
    // CORREZIONE: Chiama refresh subito dopo aver mostrato il panel
    [self refreshPanelsList];
    
    NSLog(@"✅ IndicatorsPanelController: Interactive popup shown and refreshed");
}


- (void)hidePanel {
    if (!self.isVisible || !self.popupWindow) return;
    
    [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
        context.duration = kAnimationDuration;
        context.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseIn];
        
        self.popupWindow.animator.alphaValue = 0.0;
        
        NSRect currentFrame = self.popupWindow.frame;
        currentFrame.origin.y += 20;
        [self.popupWindow.animator setFrame:currentFrame display:YES];
        
    } completionHandler:^{
        [self.popupWindow.parentWindow removeChildWindow:self.popupWindow];
        [self.popupWindow orderOut:nil];
        self.popupWindow = nil;
        self.isVisible = NO;
        NSLog(@"✅ IndicatorsPanelController: Interactive popup hidden");
    }];
}

- (void)showPanelIfNotVisible {
    if (!self.isVisible) {
        [self showPanel];
    }
}

#pragma mark - Panel Management

// CORREZIONE nel metodo refreshPanelsList - usa priorità diverse
- (void)refreshPanelsList {
    NSLog(@"🔄 REFRESH START - ChartWidget: %@", self.chartWidget);
    NSLog(@"🔄 Panel models count: %ld", self.chartWidget.panelModels.count);
    
    // Clear existing containers
    for (PanelTableViewContainer *container in self.panelContainers) {
        [self.panelsStackView removeArrangedSubview:container];
        [container removeFromSuperview];
    }
    [self.panelContainers removeAllObjects];
    
    // Create containers for each panel
    for (ChartPanelModel *panelModel in self.chartWidget.panelModels) {
        NSLog(@"🔄 Creating container for panel: %@", panelModel.title);
        
        PanelTableViewContainer *container = [[PanelTableViewContainer alloc] initWithPanelModel:panelModel controller:self];
        [self.panelContainers addObject:container];
        [self.panelsStackView addArrangedSubview:container];
        
        // CORREZIONE: Usa hugging priority invece di fixed height
        [container setContentHuggingPriority:NSLayoutPriorityDefaultLow forOrientation:NSLayoutConstraintOrientationVertical];
        [container setContentCompressionResistancePriority:NSLayoutPriorityDefaultHigh forOrientation:NSLayoutConstraintOrientationVertical];
        
        // Height constraint più flessibile
        NSLayoutConstraint *heightConstraint = [container.heightAnchor constraintEqualToConstant:120];
        heightConstraint.priority = NSLayoutPriorityDefaultHigh; // Non Required
        heightConstraint.active = YES;
        
        // Width constraint
        NSLayoutConstraint *widthConstraint = [container.widthAnchor constraintEqualToAnchor:self.panelsStackView.widthAnchor];
        widthConstraint.active = YES;
    }
    
    // CORREZIONE: Force layout prima di reload
    [self.view layoutSubtreeIfNeeded];
    [self.panelsStackView layoutSubtreeIfNeeded];
    
    // Delay leggermente il reload per dare tempo ai constraints
    dispatch_async(dispatch_get_main_queue(), ^{
        // Refresh all table views
        for (PanelTableViewContainer *container in self.panelContainers) {
            NSLog(@"🔄 Reloading table for panel: %@ (frame: %@)",
                  container.panelModel.title, NSStringFromRect(container.frame));
            [container.tableView reloadData];
        }
        
        [self.availableIndicatorsTable reloadData];
        NSLog(@"🔄 REFRESH COMPLETE - %ld panels, %ld containers",
              self.chartWidget.panelModels.count, self.panelContainers.count);
    });
}


- (void)deletePanelModel:(ChartPanelModel *)panelModel {
    [self.chartWidget requestDeletePanel:panelModel];
    [self refreshPanelsList];
}

- (void)showAddIndicatorPopupForPanel:(ChartPanelModel *)panel sourceButton:(NSButton *)button {
    NSMenu *menu = [[NSMenu alloc] init];
    
    for (NSString *indicatorType in self.availableIndicatorTypes) {
        NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:[self displayNameForIndicatorType:indicatorType]
                                                      action:@selector(addIndicatorToPanel:)
                                               keyEquivalent:@""];
        item.target = self;
        item.representedObject = @{@"panel": panel, @"indicator": indicatorType};
        [menu addItem:item];
    }
    
    [menu popUpMenuPositioningItem:nil atLocation:NSMakePoint(0, button.frame.size.height) inView:button];
}

- (void)addIndicatorToPanel:(NSMenuItem *)menuItem {
    NSDictionary *info = menuItem.representedObject;
    ChartPanelModel *panel = info[@"panel"];
    NSString *indicatorType = info[@"indicator"];
    
    [self addIndicatorType:indicatorType toPanel:panel];
}

- (void)addIndicatorType:(NSString *)indicatorType toPanel:(ChartPanelModel *)panel {
    // Create the indicator renderer
    id<IndicatorRenderer> indicator = [self.chartWidget createIndicatorOfType:indicatorType];
    if (indicator) {
        [panel addIndicator:indicator];
        [self.chartWidget refreshAllPanels];
        [self refreshPanelsList];
        
        NSLog(@"✅ IndicatorsPanelController: Added %@ to panel '%@'", indicatorType, panel.title);
    }
}
#pragma mark - Utility Methods - CORREZIONE

- (NSString *)displayNameForIndicatorType:(NSString *)indicatorType {
    NSDictionary *displayNames = @{
        @"Volume": @"📈 Volume",
        @"RSI": @"📉 RSI (Relative Strength Index)",
        @"MACD": @"📊 MACD",
        @"SMA": @"〰️ Simple Moving Average",
        @"EMA": @"〰️ Exponential Moving Average",
        @"Bollinger Bands": @"📏 Bollinger Bands",
        @"Stochastic": @"🔄 Stochastic Oscillator",
        @"CCI": @"📈 Commodity Channel Index",
        @"Williams %R": @"📉 Williams %R"
    };
    
    return displayNames[indicatorType] ?: [NSString stringWithFormat:@"📊 %@", indicatorType];
}

- (NSString *)iconForIndicatorType:(NSString *)indicatorType {
    NSDictionary *icons = @{
        @"Security": @"📊",
        @"Volume": @"📈",
        @"RSI": @"📉",
        @"MACD": @"📊",
        @"SMA": @"〰️",
        @"EMA": @"〰️",
        @"Bollinger Bands": @"📏",
        @"Stochastic": @"🔄",
        @"CCI": @"📈",
        @"Williams %R": @"📉"
    };
    
    return icons[indicatorType] ?: @"📊";
}

#pragma mark - Table View Data Source & Delegate
- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    if (tableView == self.availableIndicatorsTable) {
        NSLog(@"📊 Available indicators table: %ld rows", self.availableIndicatorTypes.count);
        return self.availableIndicatorTypes.count;
    }
    
    // Find which panel table this is
    for (PanelTableViewContainer *container in self.panelContainers) {
        if (container.tableView == tableView) {
            NSInteger count = container.panelModel.indicators.count;
            NSLog(@"📊 Panel '%@' table: %ld rows", container.panelModel.title, count);
            return count;
        }
    }
    
    NSLog(@"⚠️ Unknown table view - returning 0 rows");
    return 0;
}

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    NSString *identifier = tableColumn.identifier;
    NSTableCellView *cellView = [tableView makeViewWithIdentifier:identifier owner:self];
    
    if (!cellView) {
        cellView = [[NSTableCellView alloc] init];
        cellView.identifier = identifier;
        
        NSTextField *textField = [[NSTextField alloc] init];
        textField.editable = NO;
        textField.bordered = NO;
        textField.backgroundColor = [NSColor clearColor];
        textField.font = [NSFont systemFontOfSize:11];
        textField.translatesAutoresizingMaskIntoConstraints = NO;
        [cellView addSubview:textField];
        cellView.textField = textField;
        
        [NSLayoutConstraint activateConstraints:@[
            [textField.leadingAnchor constraintEqualToAnchor:cellView.leadingAnchor constant:8],
            [textField.trailingAnchor constraintEqualToAnchor:cellView.trailingAnchor constant:-8],
            [textField.centerYAnchor constraintEqualToAnchor:cellView.centerYAnchor]
        ]];
    }
    
    if (tableView == self.availableIndicatorsTable) {
        // Available indicators table
        if (row < self.availableIndicatorTypes.count) {
            NSString *indicatorType = self.availableIndicatorTypes[row];
            cellView.textField.stringValue = [self displayNameForIndicatorType:indicatorType];
            NSLog(@"📊 Available indicator row %ld: %@", row, indicatorType);
        }
    } else {
        // Panel indicators table
        for (PanelTableViewContainer *container in self.panelContainers) {
            if (container.tableView == tableView) {
                if (row < container.panelModel.indicators.count) {
                    id<IndicatorRenderer> indicator = container.panelModel.indicators[row];
                    NSString *icon = [self iconForIndicatorType:[indicator indicatorType]];
                    NSString *displayText = [NSString stringWithFormat:@"%@ %@", icon, [indicator displayName]];
                    cellView.textField.stringValue = displayText;
                    NSLog(@"📊 Panel indicator row %ld: %@", row, displayText);
                }
                break;
            }
        }
    }
    
    return cellView;
}

- (void)tableView:(NSTableView *)tableView didSelectRowAtIndexOfColumn:(NSInteger)column {
    // Handle selection for context menu or double-click
}

- (NSMenu *)tableView:(NSTableView *)tableView menuForRows:(NSIndexSet *)rows {
    if (tableView == self.availableIndicatorsTable) {
        return nil; // No context menu for available indicators
    }
    
    // Context menu for panel indicators
    NSMenu *menu = [[NSMenu alloc] init];
    
    NSMenuItem *removeItem = [[NSMenuItem alloc] initWithTitle:@"Remove Indicator"
                                                        action:@selector(removeIndicatorFromPanel:)
                                                 keyEquivalent:@""];
    removeItem.target = self;
    removeItem.representedObject = @{@"tableView": tableView, @"rows": rows};
    [menu addItem:removeItem];
    
    NSMenuItem *configureItem = [[NSMenuItem alloc] initWithTitle:@"Configure..."
                                                           action:@selector(configureIndicator:)
                                                    keyEquivalent:@""];
    configureItem.target = self;
    configureItem.representedObject = @{@"tableView": tableView, @"rows": rows};
    [menu addItem:configureItem];
    
    return menu;
}

- (void)removeIndicatorFromPanel:(NSMenuItem *)menuItem {
    NSDictionary *info = menuItem.representedObject;
    NSTableView *tableView = info[@"tableView"];
    NSIndexSet *rows = info[@"rows"];
    
    // Find the panel container
    for (PanelTableViewContainer *container in self.panelContainers) {
        if (container.tableView == tableView) {
            [rows enumerateIndexesWithOptions:NSEnumerationReverse usingBlock:^(NSUInteger idx, BOOL *stop) {
                if (idx < container.panelModel.indicators.count) {
                    [container.panelModel removeIndicatorAtIndex:idx];
                }
            }];
            
            [self.chartWidget refreshAllPanels];
            [self refreshPanelsList];
            break;
        }
    }
}

- (void)configureIndicator:(NSMenuItem *)menuItem {
    // TODO: Implement indicator configuration
    NSLog(@"🔧 Configure indicator - to be implemented");
}

#pragma mark - Drag & Drop Support

- (BOOL)tableView:(NSTableView *)tableView writeRowsWithIndexes:(NSIndexSet *)rowIndexes toPasteboard:(NSPasteboard *)pboard {
    if (tableView == self.availableIndicatorsTable) {
        // Dragging from available indicators
        NSUInteger index = [rowIndexes firstIndex];
        if (index < self.availableIndicatorTypes.count) {
            NSString *indicatorType = self.availableIndicatorTypes[index];
            [pboard declareTypes:@[kAvailableIndicatorPasteboardType] owner:self];
            [pboard setString:indicatorType forType:kAvailableIndicatorPasteboardType];
            return YES;
        }
    } else {
        // Dragging from panel indicators
        for (PanelTableViewContainer *container in self.panelContainers) {
            if (container.tableView == tableView) {
                NSUInteger index = [rowIndexes firstIndex];
                if (index < container.panelModel.indicators.count) {
                    id<IndicatorRenderer> indicator = container.panelModel.indicators[index];
                    NSString *indicatorInfo = [NSString stringWithFormat:@"%@|%@",
                                             container.panelModel.panelId, [indicator indicatorType]];
                    [pboard declareTypes:@[kIndicatorPasteboardType] owner:self];
                    [pboard setString:indicatorInfo forType:kIndicatorPasteboardType];
                    return YES;
                }
                break;
            }
        }
    }
    
    return NO;
}

- (NSDragOperation)tableView:(NSTableView *)tableView validateDrop:(id<NSDraggingInfo>)info proposedRow:(NSInteger)row proposedDropOperation:(NSTableViewDropOperation)dropOperation {
    if (tableView == self.availableIndicatorsTable) {
        return NSDragOperationNone; // Can't drop into available indicators
    }
    
    // Check if we have valid drag data
    NSPasteboard *pboard = [info draggingPasteboard];
    if ([pboard availableTypeFromArray:@[kAvailableIndicatorPasteboardType]] ||
        [pboard availableTypeFromArray:@[kIndicatorPasteboardType]]) {
        return NSDragOperationMove;
    }
    
    return NSDragOperationNone;
}

- (BOOL)tableView:(NSTableView *)tableView acceptDrop:(id<NSDraggingInfo>)info row:(NSInteger)row dropOperation:(NSTableViewDropOperation)dropOperation {
    NSPasteboard *pboard = [info draggingPasteboard];
    
    // Find target panel
    ChartPanelModel *targetPanel = nil;
    for (PanelTableViewContainer *container in self.panelContainers) {
        if (container.tableView == tableView) {
            targetPanel = container.panelModel;
            break;
        }
    }
    
    if (!targetPanel) return NO;
    
    if ([pboard availableTypeFromArray:@[kAvailableIndicatorPasteboardType]]) {
        // Dragging from available indicators
        NSString *indicatorType = [pboard stringForType:kAvailableIndicatorPasteboardType];
        [self addIndicatorType:indicatorType toPanel:targetPanel];
        return YES;
        
    } else if ([pboard availableTypeFromArray:@[kIndicatorPasteboardType]]) {
        // Moving indicator between panels
        NSString *indicatorInfo = [pboard stringForType:kIndicatorPasteboardType];
        NSArray *components = [indicatorInfo componentsSeparatedByString:@"|"];
        
        if (components.count == 2) {
            NSString *sourcePanelId = components[0];
            NSString *indicatorType = components[1];
            
            // Find source panel and remove indicator
            ChartPanelModel *sourcePanel = nil;
            id<IndicatorRenderer> indicatorToMove = nil;
            
            for (ChartPanelModel *panel in self.chartWidget.panelModels) {
                if ([panel.panelId isEqualToString:sourcePanelId]) {
                    sourcePanel = panel;
                    for (id<IndicatorRenderer> indicator in panel.indicators) {
                        if ([[indicator indicatorType] isEqualToString:indicatorType]) {
                            indicatorToMove = indicator;
                            break;
                        }
                    }
                    break;
                }
            }
            
            if (sourcePanel && indicatorToMove && sourcePanel != targetPanel) {
                [sourcePanel removeIndicator:indicatorToMove];
                [targetPanel addIndicator:indicatorToMove];
                
                [self.chartWidget refreshAllPanels];
                [self refreshPanelsList];
                return YES;
            }
        }
    }
    
    return NO;
}

#pragma mark - Actions

- (IBAction)closeButtonClicked:(id)sender {
    [self hidePanel];
}

- (IBAction)addPanelButtonClicked:(id)sender {
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"New Panel";
    alert.informativeText = @"Enter a name for the new panel:";
    alert.alertStyle = NSAlertStyleInformational;
    [alert addButtonWithTitle:@"Create"];
    [alert addButtonWithTitle:@"Cancel"];
    
    NSTextField *input = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 200, 24)];
    input.stringValue = @"New Panel";
    alert.accessoryView = input;
    
    [alert beginSheetModalForWindow:self.popupWindow completionHandler:^(NSModalResponse returnCode) {
        if (returnCode == NSAlertFirstButtonReturn) {
            NSString *panelName = input.stringValue;
            if (panelName.length > 0) {
                ChartPanelModel *newPanel = [ChartPanelModel secondaryPanelWithTitle:panelName];
                [self.chartWidget addPanelWithModel:newPanel];
                [self refreshPanelsList];
            }
        }
    }];
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

#pragma mark - Template Management

- (void)saveTemplateWithName:(NSString *)templateName {
    if (![self.savedTemplates containsObject:templateName]) {
        [self.savedTemplates addObject:templateName];
        [self.templateComboBox removeAllItems];
        [self.templateComboBox addItemsWithObjectValues:self.savedTemplates];
        [self.templateComboBox selectItemWithObjectValue:templateName];
        
        NSLog(@"💾 IndicatorsPanelController: Saved template '%@'", templateName);
    }
}

- (void)loadTemplateWithName:(NSString *)templateName {
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
