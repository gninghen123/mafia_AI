//
//  WidgetContainerView.m
//  TradingApp
//

#import "WidgetContainerView.h"
#import "PanelController.h"
#import "BaseWidget.h"

@interface WidgetContainerNode : NSObject
@property (nonatomic, strong) id content; // Can be BaseWidget or NSSplitView
@property (nonatomic, weak) WidgetContainerNode *parent;
@property (nonatomic, strong) WidgetContainerNode *leftOrTop;
@property (nonatomic, strong) WidgetContainerNode *rightOrBottom;
@property (nonatomic, assign) BOOL isVertical; // YES for left/right split, NO for top/bottom


@end

@implementation WidgetContainerNode
@end

@interface WidgetContainerView ()
@property (nonatomic, strong) WidgetContainerNode *rootNode;
@property (nonatomic, strong) NSMutableDictionary<NSString *, WidgetContainerNode *> *widgetToNodeMap;
@end

@implementation WidgetContainerView
- (void)replaceWidget:(BaseWidget *)oldWidget withWidget:(BaseWidget *)newWidget {
    WidgetContainerNode *node = self.widgetToNodeMap[oldWidget.widgetID];
    if (!node) {
        NSLog(@"Error: Cannot find node for widget to replace");
        return;
    }

    // ✅ Rimuovi la view del vecchio widget
    [oldWidget.view removeFromSuperview];

    // ✅ Sostituisci con il nuovo widget
    node.content = newWidget;

    // ✅ Aggiorna la mappa
    [self.widgetToNodeMap removeObjectForKey:oldWidget.widgetID];
    self.widgetToNodeMap[newWidget.widgetID] = node;

    // ✅ Ricostruisci la gerarchia
    [self rebuildViewHierarchy];
}


- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}
- (instancetype)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.widgetToNodeMap = [NSMutableDictionary dictionary];
        self.wantsLayer = YES;
        self.layer.backgroundColor = [NSColor controlBackgroundColor].CGColor;
        
        // Ensure the container view resizes properly
        self.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
        
        // Set up to receive size change notifications
        self.postsFrameChangedNotifications = YES;
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(frameDidChange:)
                                                     name:NSViewFrameDidChangeNotification
                                                   object:self];
    }
    return self;
}

- (void)frameDidChange:(NSNotification *)notification {
    // When container resizes, adjust split views
    if ([self.rootNode.content isKindOfClass:[NSSplitView class]]) {
        NSSplitView *splitView = (NSSplitView *)self.rootNode.content;
        [splitView adjustSubviews];
    }
}

#pragma mark - Widget Management

- (void)addWidget:(BaseWidget *)widget {
    if (!self.rootNode) {
        // First widget becomes the root
        self.rootNode = [[WidgetContainerNode alloc] init];
        self.rootNode.content = widget.view;
        self.widgetToNodeMap[widget.widgetID] = self.rootNode;
        
        // Make sure widget view has a size
        if (NSIsEmptyRect(widget.view.frame)) {
            widget.view.frame = self.bounds;
        }
        
        [self addSubview:widget.view];
        [self setupConstraintsForRootView:widget.view];
        
        NSLog(@"Added first widget as root: %@", widget.widgetID);
    } else {
        // Add to the bottom of the last widget (default behavior for panels)
        BaseWidget *lastWidget = [self findLastWidget];
        if (lastWidget) {
            // For side panels, always add below. For center panel, add to the right
            WidgetAddDirection direction = (widget.panelType == PanelTypeCenter) ?
                                         WidgetAddDirectionRight : WidgetAddDirectionBottom;
            [self insertWidget:widget relativeToWidget:lastWidget inDirection:direction];
        }
    }
}

- (void)removeWidget:(BaseWidget *)widget {
    WidgetContainerNode *node = self.widgetToNodeMap[widget.widgetID];
    if (!node) return;
    
    WidgetContainerNode *parent = node.parent;
    if (!parent) {
        // Removing root widget - not allowed if it's the only one
        return;
    }
    
    // Find sibling
    WidgetContainerNode *sibling = (parent.leftOrTop == node) ? parent.rightOrBottom : parent.leftOrTop;
    
    // Replace parent with sibling in grandparent
    if (parent.parent) {
        if (parent.parent.leftOrTop == parent) {
            parent.parent.leftOrTop = sibling;
        } else {
            parent.parent.rightOrBottom = sibling;
        }
        sibling.parent = parent.parent;
    } else {
        // Parent was root, sibling becomes new root
        self.rootNode = sibling;
        sibling.parent = nil;
    }
    
    // Remove the split view if it exists
    if ([parent.content isKindOfClass:[NSSplitView class]]) {
        [(NSView *)parent.content removeFromSuperview];
    }
    
    // Remove widget view
    [widget.view removeFromSuperview];
    [self.widgetToNodeMap removeObjectForKey:widget.widgetID];
    
    // Rebuild view hierarchy
    [self rebuildViewHierarchy];
}

- (void)insertWidget:(BaseWidget *)widget
       relativeToWidget:(BaseWidget *)relativeWidget
          inDirection:(WidgetAddDirection)direction {
    
    WidgetContainerNode *relativeNode = self.widgetToNodeMap[relativeWidget.widgetID];
    if (!relativeNode) {
        NSLog(@"Error: Cannot find relative widget node for ID: %@", relativeWidget.widgetID);
        return;
    }
    
    NSLog(@"Before insertion:");
    [self printNodeStructure:self.rootNode indent:@""];
    
    // Create new split view
    NSSplitView *splitView = [[NSSplitView alloc] init];
    splitView.dividerStyle = NSSplitViewDividerStyleThin;
    splitView.delegate = self;
    
    // Determine split direction
    BOOL isVertical = (direction == WidgetAddDirectionLeft || direction == WidgetAddDirectionRight);
    splitView.vertical = isVertical;
    
    // Create new parent node for the split view
    WidgetContainerNode *newParent = [[WidgetContainerNode alloc] init];
    newParent.content = splitView;
    newParent.isVertical = isVertical;
    newParent.parent = relativeNode.parent;
    
    // Create new widget node
    WidgetContainerNode *newNode = [[WidgetContainerNode alloc] init];
    newNode.content = widget.view;
    newNode.parent = newParent;
    self.widgetToNodeMap[widget.widgetID] = newNode;
    
    // Update parent's child reference if it exists
    if (relativeNode.parent) {
        if (relativeNode.parent.leftOrTop == relativeNode) {
            relativeNode.parent.leftOrTop = newParent;
        } else {
            relativeNode.parent.rightOrBottom = newParent;
        }
    } else {
        // relativeNode was root
        self.rootNode = newParent;
    }
    
    // Set up the new parent's children based on direction
    if (direction == WidgetAddDirectionLeft || direction == WidgetAddDirectionTop) {
        newParent.leftOrTop = newNode;
        newParent.rightOrBottom = relativeNode;
    } else {
        newParent.leftOrTop = relativeNode;
        newParent.rightOrBottom = newNode;
    }
    relativeNode.parent = newParent;
    
    NSLog(@"After insertion:");
    [self printNodeStructure:self.rootNode indent:@""];
    
    NSLog(@"Inserted widget %@ %@ relative to %@",
          widget.widgetID,
          @[@"Top", @"Bottom", @"Left", @"Right"][direction],
          relativeWidget.widgetID);
    
    // Rebuild view hierarchy
    [self rebuildViewHierarchy];
}

- (void)printNodeStructure:(WidgetContainerNode *)node indent:(NSString *)indent {
    if (!node) {
        NSLog(@"%@(null)", indent);
        return;
    }
    
    if ([node.content isKindOfClass:[NSSplitView class]]) {
        NSLog(@"%@SplitView (vertical: %@)", indent, node.isVertical ? @"YES" : @"NO");
        NSLog(@"%@  Left/Top:", indent);
        [self printNodeStructure:node.leftOrTop indent:[indent stringByAppendingString:@"    "]];
        NSLog(@"%@  Right/Bottom:", indent);
        [self printNodeStructure:node.rightOrBottom indent:[indent stringByAppendingString:@"    "]];
    } else {
        // Find widget ID for this view
        NSString *widgetID = @"Unknown";
        for (NSString *wID in self.widgetToNodeMap) {
            if (self.widgetToNodeMap[wID] == node) {
                widgetID = wID;
                break;
            }
        }
        NSLog(@"%@Widget: %@", indent, widgetID);
    }
}

- (void)clearAllWidgets {
    for (NSView *subview in self.subviews) {
        [subview removeFromSuperview];
    }
    [self.widgetToNodeMap removeAllObjects];
    self.rootNode = nil;
}

#pragma mark - View Hierarchy Management

- (void)rebuildViewHierarchy {
    NSLog(@"Rebuilding view hierarchy...");
    NSLog(@"Root node content class: %@", [self.rootNode.content class]);
    
    // Remove all subviews
    NSArray *subviewsCopy = [self.subviews copy];
    for (NSView *subview in subviewsCopy) {
        [subview removeFromSuperview];
    }
    
    // Rebuild from root
    if (self.rootNode) {
        NSView *rootView = [self buildViewFromNode:self.rootNode];
        if (rootView) {
            [self addSubview:rootView];
            [self setupConstraintsForRootView:rootView];
            
            // Force layout update
            [self setNeedsLayout:YES];
            [self layoutSubtreeIfNeeded];
            
            NSLog(@"View hierarchy rebuilt successfully with root view: %@", rootView);
            NSLog(@"Root view has %lu subviews", (unsigned long)rootView.subviews.count);
            if ([rootView isKindOfClass:[NSSplitView class]]) {
                NSSplitView *splitView = (NSSplitView *)rootView;
                for (NSView *subview in splitView.subviews) {
                    NSLog(@"  - Subview: %@ frame: %@", subview, NSStringFromRect(subview.frame));
                }
                
                // Force the split view to layout properly
                [splitView adjustSubviews];
            }
        } else {
            NSLog(@"Error: buildViewFromNode returned nil!");
        }
    } else {
        NSLog(@"Warning: No root node to rebuild from!");
    }
}

- (NSView *)buildViewFromNode:(WidgetContainerNode *)node {
    if (!node) {
        NSLog(@"Error: buildViewFromNode called with nil node!");
        return nil;
    }
    
    if ([node.content isKindOfClass:[NSSplitView class]]) {
        NSLog(@"Building view from split node (vertical: %@)", node.isVertical ? @"YES" : @"NO");
        NSSplitView *splitView = node.content;
        
        // Clear existing subviews
        NSArray *subviewsCopy = [splitView.subviews copy];
        for (NSView *subview in subviewsCopy) {
            [subview removeFromSuperview];
        }
        
        // Add children
        NSView *leftView = nil;
        NSView *rightView = nil;
        
        if (node.leftOrTop) {
            leftView = [self buildViewFromNode:node.leftOrTop];
            if (leftView) {
                [splitView addSubview:leftView];
            } else {
                NSLog(@"Warning: leftOrTop node produced nil view!");
            }
        }
        if (node.rightOrBottom) {
            rightView = [self buildViewFromNode:node.rightOrBottom];
            if (rightView) {
                [splitView addSubview:rightView];
            } else {
                NSLog(@"Warning: rightOrBottom node produced nil view!");
            }
        }
        
        // Configure split view properly
        if (leftView && rightView) {
            // Set autoresizing masks for proper behavior
            leftView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
            rightView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
            
            // Force layout
            [splitView adjustSubviews];
            
            // Set initial split position to 50%
            dispatch_async(dispatch_get_main_queue(), ^{
                if (splitView.subviews.count == 2) {
                    CGFloat position = splitView.isVertical ?
                                      splitView.bounds.size.width / 2.0 :
                                      splitView.bounds.size.height / 2.0;
                    if (position > 0) {
                        [splitView setPosition:position ofDividerAtIndex:0];
                    }
                }
            });
        }
        
        return splitView;
    } else if ([node.content isKindOfClass:[BaseWidget class]]) {
        BaseWidget *widget = (BaseWidget *)node.content;
        NSLog(@"✅ Building view from widget: %@ (%@)", widget.widgetID, [widget class]);
        NSLog(@"  - view: %@", widget.view);
        NSLog(@"  - view subviews: %lu", widget.view.subviews.count);
        return widget.view;
    } else if ([node.content isKindOfClass:[NSView class]]) {
        NSLog(@"⚠️ node.content is raw NSView, no widget logic");
        return (NSView *)node.content;
    } else {
        NSLog(@"❌ Unknown node content: %@", node.content);
    }


    
    NSLog(@"Error: Unknown node content type: %@", [node.content class]);
    return nil;
}

- (void)setupConstraintsForRootView:(NSView *)rootView {
    if (!rootView || !rootView.superview) {
        return;
    }
    
    rootView.translatesAutoresizingMaskIntoConstraints = NO;
    
    // Verifica che tutti gli anchor siano validi prima di creare i constraint
    if (rootView.topAnchor && self.topAnchor &&
        rootView.leadingAnchor && self.leadingAnchor &&
        rootView.trailingAnchor && self.trailingAnchor &&
        rootView.bottomAnchor && self.bottomAnchor) {
        
        [NSLayoutConstraint activateConstraints:@[
            [rootView.topAnchor constraintEqualToAnchor:self.topAnchor],
            [rootView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
            [rootView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
            [rootView.bottomAnchor constraintEqualToAnchor:self.bottomAnchor]
        ]];
    }
}

#pragma mark - Helper Methods

- (BaseWidget *)findLastWidget {
    // Simple implementation - returns any widget
    for (NSString *widgetID in self.widgetToNodeMap) {
        WidgetContainerNode *node = self.widgetToNodeMap[widgetID];
        if ([node.content isKindOfClass:[NSView class]]) {
            // Find the widget that owns this view
            for (BaseWidget *widget in self.panelController.widgets) {
                if (widget.view == node.content) {
                    return widget;
                }
            }
        }
    }
    return nil;
}

#pragma mark - Serialization

- (NSDictionary *)serializeStructure {
    if (!self.rootNode) {
        NSLog(@"WARNING: No root node to serialize");
        return nil;
    }
    
    NSDictionary *serialized = [self serializeNode:self.rootNode];
    NSLog(@"Serialized structure: %@", serialized);
    return serialized;
}

- (NSDictionary *)serializeNode:(WidgetContainerNode *)node {
    if (!node) {
        return nil;
    }
    
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    
    if ([node.content isKindOfClass:[NSSplitView class]]) {
        dict[@"type"] = @"split";
        dict[@"isVertical"] = @(node.isVertical);
        
        if (node.leftOrTop) {
            NSDictionary *leftDict = [self serializeNode:node.leftOrTop];
            if (leftDict) {
                dict[@"leftOrTop"] = leftDict;
            }
        }
        if (node.rightOrBottom) {
            NSDictionary *rightDict = [self serializeNode:node.rightOrBottom];
            if (rightDict) {
                dict[@"rightOrBottom"] = rightDict;
            }
        }
        
        // Save split position
        NSSplitView *splitView = (NSSplitView *)node.content;
        if (splitView.subviews.count >= 2) {
            CGFloat position = NSMaxX([splitView.subviews[0] frame]);
            dict[@"splitPosition"] = @(position);
        }
    } else if ([node.content isKindOfClass:[NSView class]]) {
        // Find the widget that owns this view
        NSString *foundWidgetID = nil;
        for (NSString *widgetID in self.widgetToNodeMap) {
            if (self.widgetToNodeMap[widgetID] == node) {
                foundWidgetID = widgetID;
                break;
            }
        }
        
        if (foundWidgetID) {
            dict[@"type"] = @"widget";
            dict[@"widgetID"] = foundWidgetID;
        } else {
            NSLog(@"WARNING: Could not find widget ID for node");
        }
    }
    
    return dict;
}

- (void)restoreStructure:(NSDictionary *)structure
         withWidgetStates:(NSArray *)widgetStates
         panelController:(PanelController *)panelController {
    [self clearAllWidgets];
    
    if (!structure || !widgetStates || widgetStates.count == 0) {
        return;
    }
    
    // Create widget ID to state mapping
    NSMutableDictionary *stateMap = [NSMutableDictionary dictionary];
    for (NSDictionary *state in widgetStates) {
        NSString *widgetID = state[@"widgetID"];
        if (widgetID) {
            stateMap[widgetID] = state;
        }
    }
    
    self.rootNode = [self restoreNode:structure withStateMap:stateMap panelController:panelController];
    if (self.rootNode) {
        [self rebuildViewHierarchy];
    }
}

- (WidgetContainerNode *)restoreNode:(NSDictionary *)nodeData
                        withStateMap:(NSDictionary *)stateMap
                      panelController:(PanelController *)panelController {
    
    WidgetContainerNode *node = [[WidgetContainerNode alloc] init];
    
    if ([nodeData[@"type"] isEqualToString:@"widget"]) {
        NSString *widgetID = nodeData[@"widgetID"];
        NSDictionary *state = stateMap[widgetID];
        
        BaseWidget *widget = [[BaseWidget alloc] initWithType:state[@"widgetType"] ?: @"Empty Widget"
                                                    panelType:panelController.panelType];
        [widget restoreState:state];
        
        node.content = widget.view;
        self.widgetToNodeMap[widget.widgetID] = node;
        
        [panelController addWidgetToCollection:widget];
        
        // Set up widget callbacks
        __weak typeof(panelController) weakController = panelController;
        widget.onRemoveRequest = ^(BaseWidget *widgetToRemove) {
            [weakController removeWidget:widgetToRemove];
        };
        
        widget.onAddRequest = ^(BaseWidget *sourceWidget, WidgetAddDirection direction) {
            [weakController addNewWidgetFromWidget:sourceWidget inDirection:direction];
        };
        
    } else if ([nodeData[@"type"] isEqualToString:@"split"]) {
        NSSplitView *splitView = [[NSSplitView alloc] init];
        splitView.dividerStyle = NSSplitViewDividerStyleThin;
        splitView.vertical = [nodeData[@"isVertical"] boolValue];
        splitView.delegate = self;
        
        node.content = splitView;
        node.isVertical = [nodeData[@"isVertical"] boolValue];
        
        if (nodeData[@"leftOrTop"]) {
            node.leftOrTop = [self restoreNode:nodeData[@"leftOrTop"]
                                   withStateMap:stateMap
                                 panelController:panelController];
            node.leftOrTop.parent = node;
        }
        
        if (nodeData[@"rightOrBottom"]) {
            node.rightOrBottom = [self restoreNode:nodeData[@"rightOrBottom"]
                                      withStateMap:stateMap
                                    panelController:panelController];
            node.rightOrBottom.parent = node;
        }
    }
    
    return node;
}

#pragma mark - NSSplitViewDelegate

- (CGFloat)splitView:(NSSplitView *)splitView
constrainMinCoordinate:(CGFloat)proposedMinimumPosition
         ofSubviewAt:(NSInteger)dividerIndex {
    return proposedMinimumPosition < 100 ? 100 : proposedMinimumPosition;
}

- (CGFloat)splitView:(NSSplitView *)splitView
constrainMaxCoordinate:(CGFloat)proposedMaximumPosition
         ofSubviewAt:(NSInteger)dividerIndex {
    CGFloat maxPosition = (splitView.vertical ? splitView.bounds.size.width : splitView.bounds.size.height) - 100;
    return proposedMaximumPosition > maxPosition ? maxPosition : proposedMaximumPosition;
}

@end
