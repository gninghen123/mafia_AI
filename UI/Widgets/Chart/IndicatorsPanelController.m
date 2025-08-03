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
    
    // IMPORTANTE: Imposta hugging priority per permettere espansione orizzontale
    [self setContentHuggingPriority:NSLayoutPriorityDefaultLow forOrientation:NSLayoutConstraintOrientationHorizontal];
    [self setContentCompressionResistancePriority:NSLayoutPriorityDefaultLow forOrientation:NSLayoutConstraintOrientationHorizontal];
    
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
    self.tableScrollView.borderType = NSLineBorder;
    self.tableScrollView.wantsLayer = YES;
    self.tableScrollView.layer.cornerRadius = 4;
    [self addSubview:self.tableScrollView];
    
    // Table view
    self.tableView = [[NSTableView alloc] init];
    self.tableView.translatesAutoresizingMaskIntoConstraints = NO;
    self.tableView.rowHeight = 20;
    self.tableView.headerView = nil;
    self.tableView.dataSource = self.controller;
    self.tableView.delegate = self.controller;
    
    // Enable drag & drop
    [self.tableView setDraggingSourceOperationMask:NSDragOperationMove forLocal:YES];
    [self.tableView registerForDraggedTypes:@[kAvailableIndicatorPasteboardType]];
    
    // Add column
    NSTableColumn *column = [[NSTableColumn alloc] initWithIdentifier:@"indicators"];
    column.title = @"Indicators";
    column.resizingMask = NSTableColumnAutoresizingMask;
    [self.tableView addTableColumn:column];
    
    self.tableScrollView.documentView = self.tableView;
}

- (void)setupConstraints {
    [NSLayoutConstraint activateConstraints:@[
        // Title label
        [self.titleLabel.topAnchor constraintEqualToAnchor:self.topAnchor constant:8],
        [self.titleLabel.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:8],
        [self.titleLabel.heightAnchor constraintEqualToConstant:20],
        
        // Add button
        [self.addIndicatorButton.centerYAnchor constraintEqualToAnchor:self.titleLabel.centerYAnchor],
        [self.addIndicatorButton.trailingAnchor constraintEqualToAnchor:self.deleteButton ? self.deleteButton.leadingAnchor : self.trailingAnchor constant:self.deleteButton ? -4 : -8],
        [self.addIndicatorButton.widthAnchor constraintEqualToConstant:20],
        [self.addIndicatorButton.heightAnchor constraintEqualToConstant:20],
        
        // Table scroll view - CORREZIONE: Si espande completamente
        [self.tableScrollView.topAnchor constraintEqualToAnchor:self.titleLabel.bottomAnchor constant:8],
        [self.tableScrollView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:8],
        [self.tableScrollView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-8],
        [self.tableScrollView.bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:-8],
        
        // Height minimo per garantire visibilità
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
    // Panel view - contenitore principale con corner radius e shadow
    self.panelView = [[NSView alloc] init];
    self.panelView.translatesAutoresizingMaskIntoConstraints = NO;
    self.panelView.wantsLayer = YES;
    self.panelView.layer.backgroundColor = [[NSColor windowBackgroundColor] colorWithAlphaComponent:0.95].CGColor;
    self.panelView.layer.cornerRadius = kCornerRadius;
    self.panelView.layer.shadowColor = [NSColor blackColor].CGColor;
    self.panelView.layer.shadowOffset = NSMakeSize(0, -2);
    self.panelView.layer.shadowRadius = kShadowRadius;
    self.panelView.layer.shadowOpacity = 0.3;
    [self.view addSubview:self.panelView];
    
    // Header
    [self setupHeader];
    
    // Template section
    [self setupTemplateSection];
    
    // CORREZIONE: Main split view con proporzioni corrette
    self.mainSplitView = [[NSSplitView alloc] init];
    self.mainSplitView.translatesAutoresizingMaskIntoConstraints = NO;
    self.mainSplitView.vertical = NO; // Horizontal split (pannelli sopra, available sotto)
    self.mainSplitView.dividerStyle = NSSplitViewDividerStyleThin;
    self.mainSplitView.delegate = self;
    [self.panelView addSubview:self.mainSplitView];
    
    // Create top and bottom sections
    NSView *topSection = [self createTopSection];    // Pannelli esistenti
    NSView *bottomSection = [self createBottomSection]; // Available indicators
    
    [self.mainSplitView addSubview:topSection];
    [self.mainSplitView addSubview:bottomSection];
    
    // IMPORTANTE: Imposta le proporzioni del split view dopo che il layout è completato
    dispatch_async(dispatch_get_main_queue(), ^{
        CGFloat totalHeight = self.mainSplitView.frame.size.height;
        if (totalHeight > 0) {
            [self.mainSplitView setPosition:totalHeight * 0.7 ofDividerAtIndex:0];
        }
    });
}

- (void)setupHeader {
    // Header label
    self.headerLabel = [[NSTextField alloc] init];
    self.headerLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.headerLabel.stringValue = @"Chart Indicators";
    self.headerLabel.font = [NSFont boldSystemFontOfSize:18];
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
    self.closeButton.toolTip = @"Close";
    self.closeButton.target = self;
    self.closeButton.action = @selector(closeButtonClicked:);
    [self.panelView addSubview:self.closeButton];
}

- (void)setupTemplateSection {
    // Template label
    self.templateLabel = [[NSTextField alloc] init];
    self.templateLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.templateLabel.stringValue = @"Templates:";
    self.templateLabel.font = [NSFont systemFontOfSize:13];
    self.templateLabel.textColor = [NSColor secondaryLabelColor];
    self.templateLabel.editable = NO;
    self.templateLabel.bordered = NO;
    self.templateLabel.backgroundColor = [NSColor clearColor];
    [self.panelView addSubview:self.templateLabel];
    
    // Template combo box
    self.templateComboBox = [[NSComboBox alloc] init];
    self.templateComboBox.translatesAutoresizingMaskIntoConstraints = NO;
    [self.templateComboBox addItemsWithObjectValues:self.savedTemplates];
    self.templateComboBox.target = self;
    self.templateComboBox.action = @selector(templateSelected:);
    [self.panelView addSubview:self.templateComboBox];
    
    // Save template button
    self.saveTemplateButton = [[NSButton alloc] init];
    self.saveTemplateButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.saveTemplateButton.buttonType = NSButtonTypeMomentaryPushIn;
    self.saveTemplateButton.title = @"💾";
    self.saveTemplateButton.toolTip = @"Save Template";
    self.saveTemplateButton.target = self;
    self.saveTemplateButton.action = @selector(saveTemplateButtonClicked:);
    [self.panelView addSubview:self.saveTemplateButton];
    
    // Load template button
    self.loadTemplateButton = [[NSButton alloc] init];
    self.loadTemplateButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.loadTemplateButton.buttonType = NSButtonTypeMomentaryPushIn;
    self.loadTemplateButton.title = @"📁";
    self.loadTemplateButton.toolTip = @"Load Template";
    self.loadTemplateButton.target = self;
    self.loadTemplateButton.action = @selector(loadTemplateButtonClicked:);
    [self.panelView addSubview:self.loadTemplateButton];
}

- (NSView *)createTopSection {
    NSView *containerView = [[NSView alloc] init];
    containerView.translatesAutoresizingMaskIntoConstraints = NO;
    
    // Title
    NSTextField *titleLabel = [[NSTextField alloc] init];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.stringValue = @"Chart Panels";
    titleLabel.font = [NSFont boldSystemFontOfSize:16];
    titleLabel.textColor = [NSColor labelColor];
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
    self.panelsStackView.alignment = NSLayoutAttributeWidth; // CAMBIATO: per espansione completa
    self.panelsStackView.distribution = NSStackViewDistributionFill;
    self.panelsStackView.spacing = 8;
    
    // CORREZIONE: Assicura che lo stack view si espanda orizzontalmente
    [self.panelsStackView setContentHuggingPriority:NSLayoutPriorityDefaultLow forOrientation:NSLayoutConstraintOrientationHorizontal];
    [self.panelsStackView setContentCompressionResistancePriority:NSLayoutPriorityDefaultLow forOrientation:NSLayoutConstraintOrientationHorizontal];
    
    self.panelsScrollView.documentView = self.panelsStackView;
    
    // CORREZIONE: Constraints per espansione orizzontale completa
    [NSLayoutConstraint activateConstraints:@[
        [titleLabel.topAnchor constraintEqualToAnchor:containerView.topAnchor constant:8],
        [titleLabel.leadingAnchor constraintEqualToAnchor:containerView.leadingAnchor constant:8],
        
        [addPanelButton.centerYAnchor constraintEqualToAnchor:titleLabel.centerYAnchor],
        [addPanelButton.trailingAnchor constraintEqualToAnchor:containerView.trailingAnchor constant:-8],
        
        [self.panelsScrollView.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:8],
        [self.panelsScrollView.leadingAnchor constraintEqualToAnchor:containerView.leadingAnchor constant:8],
        [self.panelsScrollView.trailingAnchor constraintEqualToAnchor:containerView.trailingAnchor constant:-8],
        [self.panelsScrollView.bottomAnchor constraintEqualToAnchor:containerView.bottomAnchor constant:-8],
        
        // IMPORTANTE: Stack view deve riempire tutto lo scroll view
        [self.panelsStackView.topAnchor constraintEqualToAnchor:self.panelsScrollView.topAnchor],
        [self.panelsStackView.leadingAnchor constraintEqualToAnchor:self.panelsScrollView.leadingAnchor],
        [self.panelsStackView.trailingAnchor constraintEqualToAnchor:self.panelsScrollView.trailingAnchor],
        [self.panelsStackView.bottomAnchor constraintGreaterThanOrEqualToAnchor:self.panelsScrollView.bottomAnchor],
        
        // CRUCIALE: Width constraint per forzare espansione orizzontale
        [self.panelsStackView.widthAnchor constraintEqualToAnchor:self.panelsScrollView.widthAnchor]
    ]];
    
    return containerView;
}

- (NSView *)createBottomSection {
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
    
    // Add column - CORREZIONE: Colonna si adatta al container
    NSTableColumn *column = [[NSTableColumn alloc] initWithIdentifier:@"available"];
    column.title = @"Available";
    column.resizingMask = NSTableColumnAutoresizingMask;
    [self.availableIndicatorsTable addTableColumn:column];
    
    self.availableIndicatorsScrollView.documentView = self.availableIndicatorsTable;
    
    // CORREZIONE: Constraints per assicurare visibilità completa
    [NSLayoutConstraint activateConstraints:@[
        // Label in alto
        [self.availableLabel.topAnchor constraintEqualToAnchor:containerView.topAnchor constant:8],
        [self.availableLabel.leadingAnchor constraintEqualToAnchor:containerView.leadingAnchor constant:8],
        [self.availableLabel.trailingAnchor constraintEqualToAnchor:containerView.trailingAnchor constant:-8],
        
        // Table view occupa tutto lo spazio restante
        [self.availableIndicatorsScrollView.topAnchor constraintEqualToAnchor:self.availableLabel.bottomAnchor constant:8],
        [self.availableIndicatorsScrollView.leadingAnchor constraintEqualToAnchor:containerView.leadingAnchor constant:8],
        [self.availableIndicatorsScrollView.trailingAnchor constraintEqualToAnchor:containerView.trailingAnchor constant:-8],
        [self.availableIndicatorsScrollView.bottomAnchor constraintEqualToAnchor:containerView.bottomAnchor constant:-8],
        
        // IMPORTANTE: Height minimo per garantire visibilità
        [self.availableIndicatorsScrollView.heightAnchor constraintGreaterThanOrEqualToConstant:100]
    ]];
    
    return containerView;
}

- (void)setupConstraints {
    [NSLayoutConstraint activateConstraints:@[
        // Panel view - contenitore principale centrato
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
        
        // CORREZIONE: Main split view occupa tutto lo spazio rimanente
        [self.mainSplitView.topAnchor constraintEqualToAnchor:self.templateComboBox.bottomAnchor constant:16],
        [self.mainSplitView.leadingAnchor constraintEqualToAnchor:self.panelView.leadingAnchor constant:8],
        [self.mainSplitView.trailingAnchor constraintEqualToAnchor:self.panelView.trailingAnchor constant:-8],
        [self.mainSplitView.bottomAnchor constraintEqualToAnchor:self.panelView.bottomAnchor constant:-8]
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
    NSRect popupRect = NSMakeRect(0, 0, kPanelWidth, kPanelHeight);
    self.popupWindow = [[NSWindow alloc] initWithContentRect:popupRect
                                                   styleMask:NSWindowStyleMaskBorderless
                                                     backing:NSBackingStoreBuffered
                                                       defer:NO];
    
    self.popupWindow.backgroundColor = [NSColor clearColor];
    self.popupWindow.opaque = NO;
    self.popupWindow.hasShadow = YES;
    self.popupWindow.level = NSFloatingWindowLevel;
    self.popupWindow.contentView = self.view;
    
    // Position popup - controlla bordi schermo
    NSRect chartFrame = [self.chartWidget.view convertRect:self.chartWidget.view.bounds toView:nil];
    NSRect screenFrame = [parentWindow convertRectToScreen:chartFrame];
    
    CGFloat popupX = screenFrame.origin.x + screenFrame.size.width - kPanelWidth - 20;
    CGFloat popupY = screenFrame.origin.y + screenFrame.size.height - kPanelHeight - 20;
    
    // Controlla se il popup esce dai bordi dello schermo
    NSRect screenBounds = [[NSScreen mainScreen] visibleFrame];
    if (popupX < screenBounds.origin.x) {
        popupX = screenBounds.origin.x + 10;
    }
    if (popupY < screenBounds.origin.y) {
        popupY = screenBounds.origin.y + 10;
    }
    
    NSRect finalFrame = NSMakeRect(popupX, popupY, kPanelWidth, kPanelHeight);
    [self.popupWindow setFrame:finalFrame display:NO];
    
    [parentWindow addChildWindow:self.popupWindow ordered:NSWindowAbove];
    [self.popupWindow makeKeyAndOrderFront:nil];
    
    self.isVisible = YES;
    
    [self refreshPanelsList];
    
    // CORREZIONE: Imposta proporzioni split dopo che la finestra è visibile
    dispatch_async(dispatch_get_main_queue(), ^{
        CGFloat totalHeight = self.mainSplitView.frame.size.height;
        if (totalHeight > 0) {
            // 70% per pannelli, 30% per available indicators
            [self.mainSplitView setPosition:totalHeight * 0.7 ofDividerAtIndex:0];
            NSLog(@"✅ Split view position set: %.0f of %.0f", totalHeight * 0.7, totalHeight);
        }
    });
    
    NSLog(@"✅ IndicatorsPanelController: Interactive popup shown (%.0fx%.0f)", kPanelWidth, kPanelHeight);
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

- (void)togglePanel {
    if (self.isVisible) {
        [self hidePanel];
    } else {
        [self showPanel];
    }
}

- (void)showPanelIfNotVisible {
    if (!self.isVisible) {
        [self showPanel];
    }
}

#pragma mark - Panel Management

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
        
        // CORREZIONE: Width constraint per espansione orizzontale completa - NESSUN CONSTANT NEGATIVO
        NSLayoutConstraint *widthConstraint = [container.widthAnchor constraintEqualToAnchor:self.panelsStackView.widthAnchor];
        widthConstraint.priority = NSLayoutPriorityRequired;
        widthConstraint.active = YES;
        
        // IMPORTANTE: Imposta content hugging priority per permettere espansione
        [container setContentHuggingPriority:NSLayoutPriorityDefaultLow forOrientation:NSLayoutConstraintOrientationHorizontal];
        [container setContentCompressionResistancePriority:NSLayoutPriorityDefaultLow forOrientation:NSLayoutConstraintOrientationHorizontal];
        
        // Height constraint flessibile
        NSLayoutConstraint *heightConstraint = [container.heightAnchor constraintGreaterThanOrEqualToConstant:80];
        heightConstraint.priority = NSLayoutPriorityDefaultHigh;
        heightConstraint.active = YES;
    }
    
    // Force layout
    [self.view layoutSubtreeIfNeeded];
    [self.panelsStackView layoutSubtreeIfNeeded];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        for (PanelTableViewContainer *container in self.panelContainers) {
            [container.tableView reloadData];
        }
        [self.availableIndicatorsTable reloadData];
        NSLog(@"🔄 REFRESH COMPLETE - Available indicators table reloaded");
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

#pragma mark - Action Methods

- (void)closeButtonClicked:(id)sender {
    [self hidePanel];
}

- (void)addPanelButtonClicked:(id)sender {
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"Add New Panel";
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

- (void)templateSelected:(id)sender {
    NSString *selectedTemplate = self.templateComboBox.stringValue;
    NSLog(@"📋 Template selected: %@", selectedTemplate);
    // TODO: Implement template loading logic
}

- (void)saveTemplateButtonClicked:(id)sender {
    NSString *templateName = self.templateComboBox.stringValue;
    if (templateName && templateName.length > 0) {
        // TODO: Implement template saving logic
        if (![self.savedTemplates containsObject:templateName]) {
            [self.savedTemplates addObject:templateName];
            [self.templateComboBox addItemWithObjectValue:templateName];
        }
        NSLog(@"💾 Template saved: %@", templateName);
    }
}

- (void)loadTemplateButtonClicked:(id)sender {
    NSString *templateName = self.templateComboBox.stringValue;
    if (templateName && templateName.length > 0) {
        NSLog(@"📁 Loading template: %@", templateName);
        // TODO: Implement template loading logic
    }
}

#pragma mark - Utility Methods

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

- (void)tableView:(NSTableView *)tableView didSelectRowAtIndex:(NSInteger)row {
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
                    [pboard declareTypes:@[kIndicatorPasteboardType] owner:self];
                    [pboard setString:[indicator indicatorType] forType:kIndicatorPasteboardType];
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
        return NSDragOperationNone; // Can't drop on available indicators
    }
    
    NSPasteboard *pboard = [info draggingPasteboard];
    if ([pboard.types containsObject:kAvailableIndicatorPasteboardType]) {
        return NSDragOperationCopy;
    }
    if ([pboard.types containsObject:kIndicatorPasteboardType]) {
        return NSDragOperationMove;
    }
    
    return NSDragOperationNone;
}

- (BOOL)tableView:(NSTableView *)tableView acceptDrop:(id<NSDraggingInfo>)info row:(NSInteger)row dropOperation:(NSTableViewDropOperation)dropOperation {
    NSPasteboard *pboard = [info draggingPasteboard];
    
    // Find which panel this table belongs to
    PanelTableViewContainer *targetContainer = nil;
    for (PanelTableViewContainer *container in self.panelContainers) {
        if (container.tableView == tableView) {
            targetContainer = container;
            break;
        }
    }
    
    if (!targetContainer) return NO;
    
    if ([pboard.types containsObject:kAvailableIndicatorPasteboardType]) {
        // Dropping from available indicators
        NSString *indicatorType = [pboard stringForType:kAvailableIndicatorPasteboardType];
        [self addIndicatorType:indicatorType toPanel:targetContainer.panelModel];
        return YES;
    }
    
    // TODO: Handle moving indicators between panels
    return NO;
}

#pragma mark - NSSplitViewDelegate

- (BOOL)splitView:(NSSplitView *)splitView canCollapseSubview:(NSView *)subview {
    return NO; // Non permettere il collasso delle sezioni
}

- (CGFloat)splitView:(NSSplitView *)splitView constrainMinCoordinate:(CGFloat)proposedMinimumPosition ofSubviewAt:(NSInteger)dividerIndex {
    // La sezione superiore (pannelli) deve avere almeno 200px
    return 200;
}

- (CGFloat)splitView:(NSSplitView *)splitView constrainMaxCoordinate:(CGFloat)proposedMaximumPosition ofSubviewAt:(NSInteger)dividerIndex {
    // La sezione inferiore (available indicators) deve avere almeno 150px
    CGFloat totalHeight = splitView.frame.size.height;
    return totalHeight - 150;
}

- (void)splitViewDidResizeSubviews:(NSNotification *)notification {
    // Force reload della table degli available indicators quando il split cambia
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.availableIndicatorsTable reloadData];
    });
}

@end
