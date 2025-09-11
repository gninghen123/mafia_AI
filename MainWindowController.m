//
//  MainWindowController.m
//  TradingApp
//

#import "MainWindowController.h"
#import "ToolbarController.h"
#import "PanelController.h"
#import "LayoutManager.h"

@interface MainWindowController ()
@property (nonatomic, strong) NSSplitView *mainSplitView;
@property (nonatomic, strong) NSSplitView *centerSplitView;
@property (nonatomic, strong) NSView *leftPanelView;
@property (nonatomic, strong) NSView *centerPanelView;
@property (nonatomic, strong) NSView *rightPanelView;

@end

@implementation MainWindowController

- (instancetype)init {
    self = [super initWithWindowNibName:@""];
    if (self) {
        [self createWindow];
        [self setupControllers];
        [self setupViews];
        [self setupNotifications];
        
        self.layoutManager = [[LayoutManager alloc] init];
    }
    return self;
}

- (void)createWindow {
    NSRect frame = NSMakeRect(0, 0, 1400, 900);
    NSUInteger styleMask = NSWindowStyleMaskTitled |
                           NSWindowStyleMaskClosable |
                           NSWindowStyleMaskMiniaturizable |
                           NSWindowStyleMaskResizable;
    
    NSWindow *window = [[NSWindow alloc] initWithContentRect:frame
                                                    styleMask:styleMask
                                                      backing:NSBackingStoreBuffered
                                                        defer:NO];
    
    [window setTitle:@"Mafia AI"];
    [window center];
    [window setMinSize:NSMakeSize(800, 600)];
    
    // Disable automatic window restoration to avoid warnings
    window.restorable = NO;
    
    self.window = window;
}

- (void)setupControllers {
    // Initialize toolbar
    self.toolbarController = [[ToolbarController alloc] init];
    self.toolbarController.mainWindowController = self;
    [self.toolbarController setupToolbarForWindow:self.window];
    
    [self.toolbarController refreshLayoutMenu];

    
    // Initialize panel controllers
    self.leftPanelController = [[PanelController alloc] initWithPanelType:PanelTypeLeft];
    self.centerPanelController = [[PanelController alloc] initWithPanelType:PanelTypeCenter];
    self.rightPanelController = [[PanelController alloc] initWithPanelType:PanelTypeRight];
}

- (void)setupViews {
    // Create main split view (horizontal)
    self.mainSplitView = [[NSSplitView alloc] init];
    self.mainSplitView.vertical = YES;
    self.mainSplitView.dividerStyle = NSSplitViewDividerStyleThin;
    self.mainSplitView.delegate = self;
    
    // Create panel views
    self.leftPanelView = self.leftPanelController.view;
    self.centerPanelView = self.centerPanelController.view;
    self.rightPanelView = self.rightPanelController.view;
    
    // Set minimum widths
    [self.leftPanelView setFrameSize:NSMakeSize(250, 0)];
    [self.rightPanelView setFrameSize:NSMakeSize(250, 0)];
    
    // Add panels to split view
    [self.mainSplitView addSubview:self.leftPanelView];
    [self.mainSplitView addSubview:self.centerPanelView];
    [self.mainSplitView addSubview:self.rightPanelView];
    
    // Configure split view constraints
    [self.leftPanelView setContentHuggingPriority:NSLayoutPriorityDefaultHigh
                                   forOrientation:NSLayoutConstraintOrientationHorizontal];
    [self.rightPanelView setContentHuggingPriority:NSLayoutPriorityDefaultHigh
                                    forOrientation:NSLayoutConstraintOrientationHorizontal];
    
    // Set as window content
    [self.window setContentView:self.mainSplitView];
    
    // Initially hide side panels
    [self toggleLeftPanel:NO];
    [self toggleRightPanel:NO];
}

- (void)setupNotifications {
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(toggleLeftPanelNotification:)
                                                 name:@"ToggleLeftPanel"
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(toggleRightPanelNotification:)
                                                 name:@"ToggleRightPanel"
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(saveCurrentLayoutNotification:)
                                                 name:@"SaveCurrentLayout"
                                               object:nil];
}

#pragma mark - Panel Toggle Methods

- (void)toggleLeftPanel:(BOOL)show {
    if (show && [self.mainSplitView isSubviewCollapsed:self.leftPanelView]) {
        [self.mainSplitView setPosition:250 ofDividerAtIndex:0];
    } else if (!show && ![self.mainSplitView isSubviewCollapsed:self.leftPanelView]) {
        [self.mainSplitView setPosition:0 ofDividerAtIndex:0];
    }
}

- (void)toggleRightPanel:(BOOL)show {
    NSInteger dividerIndex = [self.mainSplitView.subviews count] - 2;
    CGFloat windowWidth = self.window.frame.size.width;
    
    if (show && [self.mainSplitView isSubviewCollapsed:self.rightPanelView]) {
        [self.mainSplitView setPosition:(windowWidth - 250) ofDividerAtIndex:dividerIndex];
    } else if (!show && ![self.mainSplitView isSubviewCollapsed:self.rightPanelView]) {
        [self.mainSplitView setPosition:windowWidth ofDividerAtIndex:dividerIndex];
    }
}

#pragma mark - Notification Handlers

- (void)toggleLeftPanelNotification:(NSNotification *)notification {
    BOOL isCollapsed = [self.mainSplitView isSubviewCollapsed:self.leftPanelView];
    [self toggleLeftPanel:isCollapsed];
}

- (void)toggleRightPanelNotification:(NSNotification *)notification {
    BOOL isCollapsed = [self.mainSplitView isSubviewCollapsed:self.rightPanelView];
    [self toggleRightPanel:isCollapsed];
}

- (void)saveCurrentLayoutNotification:(NSNotification *)notification {
    [self saveLayoutWithName:@"LastUsedLayout"];
}

#pragma mark - Layout Management

- (void)saveLayoutWithName:(NSString *)layoutName {
    NSLog(@"Saving layout with name: %@", layoutName);
    
    NSDictionary *layoutData = @{
        @"leftPanel": [self.leftPanelController serializeLayout],
        @"centerPanel": [self.centerPanelController serializeLayout],
        @"rightPanel": [self.rightPanelController serializeLayout],
        @"leftPanelVisible": @(![self.mainSplitView isSubviewCollapsed:self.leftPanelView]),
        @"rightPanelVisible": @(![self.mainSplitView isSubviewCollapsed:self.rightPanelView]),
        @"splitViewPositions": [self getSplitViewPositions]
    };
    
    NSLog(@"Layout data to save: %@", layoutData);
    
    [self.layoutManager saveLayout:layoutData withName:layoutName];
    
    // Verify it was saved
    NSDictionary *savedLayout = [self.layoutManager loadLayoutWithName:layoutName];
    if (savedLayout) {
        NSLog(@"Layout saved successfully");
    } else {
        NSLog(@"ERROR: Layout was not saved properly!");
    }
}

- (void)loadLayoutWithName:(NSString *)layoutName {
    NSLog(@"Loading layout with name: %@", layoutName);
    
    NSDictionary *layoutData = [self.layoutManager loadLayoutWithName:layoutName];
    if (!layoutData) {
        NSLog(@"ERROR: No layout found with name: %@", layoutName);
        return;
    }
    
    NSLog(@"Loaded layout data: %@", layoutData);
    
    // Restore panel visibility
    [self toggleLeftPanel:[layoutData[@"leftPanelVisible"] boolValue]];
    [self toggleRightPanel:[layoutData[@"rightPanelVisible"] boolValue]];
    
    // Restore panel contents
    [self.leftPanelController restoreLayout:layoutData[@"leftPanel"]];
    [self.centerPanelController restoreLayout:layoutData[@"centerPanel"]];
    [self.rightPanelController restoreLayout:layoutData[@"rightPanel"]];
    
    // Restore split view positions
    [self restoreSplitViewPositions:layoutData[@"splitViewPositions"]];
    
    NSLog(@"Layout restoration complete");
}

- (NSArray *)availableLayouts {
    return [self.layoutManager availableLayouts];
}

#pragma mark - Split View Management

- (NSArray *)getSplitViewPositions {
    NSMutableArray *positions = [NSMutableArray array];
    for (NSInteger i = 0; i < self.mainSplitView.subviews.count - 1; i++) {
        CGFloat position = NSMinX([self.mainSplitView.subviews[i + 1] frame]);
        [positions addObject:@(position)];
    }
    return positions;
}

- (void)restoreSplitViewPositions:(NSArray *)positions {
    for (NSInteger i = 0; i < positions.count && i < self.mainSplitView.subviews.count - 1; i++) {
        [self.mainSplitView setPosition:[positions[i] doubleValue] ofDividerAtIndex:i];
    }
}

#pragma mark - NSSplitViewDelegate

- (CGFloat)splitView:(NSSplitView *)splitView constrainMinCoordinate:(CGFloat)proposedMinimumPosition ofSubviewAt:(NSInteger)dividerIndex {
    if (dividerIndex == 0) {
        return 200; // Minimum width for left panel
    }
    return proposedMinimumPosition;
}

- (CGFloat)splitView:(NSSplitView *)splitView constrainMaxCoordinate:(CGFloat)proposedMaximumPosition ofSubviewAt:(NSInteger)dividerIndex {
    if (dividerIndex == [splitView.subviews count] - 2) {
        return splitView.frame.size.width - 200; // Minimum width for right panel
    }
    return proposedMaximumPosition;
}

- (BOOL)splitView:(NSSplitView *)splitView canCollapseSubview:(NSView *)subview {
    // Only side panels can collapse
    return (subview == self.leftPanelView || subview == self.rightPanelView);
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
