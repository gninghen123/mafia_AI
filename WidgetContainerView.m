//
//  WidgetContainerView.m
//  TradingApp
//

#import "WidgetContainerView.h"
#import "PanelController.h"
#import "BaseWidget.h"
#import "WidgetTypeManager.h"

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
        // ✅ FIX: Primo widget - crea nodo root correttamente
        self.rootNode = [[WidgetContainerNode alloc] init];
        self.rootNode.content = widget.view;  // Usa widget.view, non widget
        
        // ✅ CRITICO: Aggiungi il widget alla mappa PRIMA di usarlo
        self.widgetToNodeMap[widget.widgetID] = self.rootNode;
        
        NSLog(@"✅ Added first widget as root: %@ (view: %@)",
              widget.widgetID, widget.view);
        NSLog(@"✅ Widget mapped: %@ -> %@", widget.widgetID, self.rootNode);
        
        // Aggiungi la view al container
        [self addSubview:widget.view];
        [self setupConstraintsForRootView:widget.view];
        
    } else {
        // Widget aggiuntivi - logica esistente per split views
        // (resto del metodo rimane uguale)
        
        // Per ora, aggiungi come split - questo gestirà widget multipli
        BaseWidget *lastWidget = [self findLastWidget];
        if (lastWidget) {
            [self insertWidget:widget
                relativeToWidget:lastWidget
                   inDirection:WidgetAddDirectionBottom];
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
    NSLog(@"🔍 DEBUG serializeStructure called");
       NSLog(@"   rootNode: %@", self.rootNode);
       NSLog(@"   rootNode.content: %@ (class: %@)", self.rootNode.content, [self.rootNode.content class]);
       NSLog(@"   widgetToNodeMap count: %lu", (unsigned long)self.widgetToNodeMap.count);
       NSLog(@"   widgetToNodeMap: %@", self.widgetToNodeMap);
       
       if (!self.rootNode) {
           NSLog(@"WARNING: No root node to serialize");
           return nil;
       }
    if (!self.rootNode) {
        NSLog(@"WARNING: No root node to serialize");
        return nil;
    }
    
    // ✅ FIX: Se il root node ha content ma è una NSView (widget singolo),
    // dobbiamo trovare il widget ID corrispondente
    if ([self.rootNode.content isKindOfClass:[NSView class]] &&
        ![[self.rootNode.content class] isSubclassOfClass:[NSSplitView class]]) {
        
        // Trova il widget ID per questa view
        NSString *foundWidgetID = nil;
        for (NSString *widgetID in self.widgetToNodeMap) {
            if (self.widgetToNodeMap[widgetID] == self.rootNode) {
                foundWidgetID = widgetID;
                break;
            }
        }
        
        if (foundWidgetID) {
            NSDictionary *serialized = @{
                @"type": @"widget",
                @"widgetID": foundWidgetID
            };
            NSLog(@"✅ Serialized single widget structure: %@", serialized);
            return serialized;
        } else {
            NSLog(@"❌ ERROR: Could not find widget ID for root node view");
            // ✅ FIX AGGIUNTIVO: Se non troviamo nella mappa, cerchiamo direttamente
            // Questo può succedere se il widget è stato aggiunto in modo diverso
            
            // Prova a creare una struttura dal primo widget disponibile
            if (self.panelController && self.panelController.widgets.count > 0) {
                BaseWidget *firstWidget = self.panelController.widgets.firstObject;
                NSDictionary *fallbackSerialized = @{
                    @"type": @"widget",
                    @"widgetID": firstWidget.widgetID
                };
                NSLog(@"✅ Used fallback serialization: %@", fallbackSerialized);
                return fallbackSerialized;
            }
            
            return nil;
        }
    }
    
    // Serializzazione normale per strutture complesse (split views)
    NSDictionary *serialized = [self serializeNode:self.rootNode];
    NSLog(@"✅ Serialized complex structure: %@", serialized);
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
        
        NSLog(@"🔍 SERIALIZE SPLIT: isVertical=%@, position=%@",
              dict[@"isVertical"], dict[@"splitPosition"]);
        
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
            NSLog(@"🔍 SERIALIZE NODE: Found widget with ID=%@", foundWidgetID);
        } else {
            NSLog(@"❌ SERIALIZE ERROR: Could not find widget ID for node with view=%@", node.content);
        }
    }
    
    return dict;
}


- (void)restoreStructure:(NSDictionary *)structure
         withWidgetStates:(NSArray *)widgetStates
         panelController:(PanelController *)panelController {
    NSLog(@"🔄 RESTORE STRUCTURE START");
    NSLog(@"   Structure: %@", structure);
    NSLog(@"   Widget states: %@", widgetStates);
    
    [self clearAllWidgets];
    
    if (!structure || !widgetStates || widgetStates.count == 0) {
        NSLog(@"❌ RESTORE STRUCTURE FAILED: Invalid data");
        return;
    }
    
    // Create widget ID to state mapping
    NSMutableDictionary *stateMap = [NSMutableDictionary dictionary];
    for (NSDictionary *state in widgetStates) {
        NSString *widgetID = state[@"widgetID"];
        if (widgetID) {
            stateMap[widgetID] = state;
            NSLog(@"🗂️ MAPPED: %@ -> %@", widgetID, state[@"widgetType"]);
        }
    }
    
    NSLog(@"🔄 CALLING restoreNode...");
    self.rootNode = [self restoreNode:structure withStateMap:stateMap panelController:panelController];
    if (self.rootNode) {
        NSLog(@"✅ RESTORE NODE SUCCESS: Rebuilding view hierarchy...");
        [self rebuildViewHierarchy];
        NSLog(@"✅ RESTORE STRUCTURE COMPLETE");
    } else {
        NSLog(@"❌ RESTORE NODE FAILED: rootNode is nil");
    }
}

- (WidgetContainerNode *)restoreNode:(NSDictionary *)nodeData
                        withStateMap:(NSDictionary *)stateMap
                      panelController:(PanelController *)panelController {
    
    WidgetContainerNode *node = [[WidgetContainerNode alloc] init];
    
    if ([nodeData[@"type"] isEqualToString:@"widget"]) {
        NSString *widgetID = nodeData[@"widgetID"];
        NSDictionary *state = stateMap[widgetID];
        
        if (!state) {
            NSLog(@"❌ No state found for widget ID: %@", widgetID);
            return nil;
        }
        
        NSString *widgetType = state[@"widgetType"];
        if (!widgetType) {
            NSLog(@"❌ No widgetType in state for widget ID: %@", widgetID);
            return nil;
        }
        
        NSLog(@"🔄 RESTORE NODE: Creating widget type '%@' for ID: %@", widgetType, widgetID);
        
        // ✅ CORREZIONE: Usa WidgetTypeManager per ottenere la classe corretta
        Class widgetClass = [[WidgetTypeManager sharedManager] classForWidgetType:widgetType];
        if (!widgetClass) {
            NSLog(@"⚠️ Unknown widget type '%@', using BaseWidget", widgetType);
            widgetClass = [BaseWidget class];
        }
        
        // ✅ CORREZIONE: Crea il widget con la classe corretta E il panelType
        BaseWidget *widget = [[widgetClass alloc] initWithType:widgetType
                                                     panelType:panelController.panelType];
        
        if (!widget) {
            NSLog(@"❌ Failed to create widget of type: %@", widgetType);
            return nil;
        }
        
        // ✅ CORREZIONE: Forza la creazione della view PRIMA di restoreState
        [widget loadView];
        
        // Restore widget state
        [widget restoreState:state];
        
        // ✅ CORREZIONE: Usa widget.view invece di widget direttamente
        node.content = widget.view;
        self.widgetToNodeMap[widget.widgetID] = node;
        
        // Add to panel controller
        [panelController addWidgetToCollection:widget];
        
        // Set up widget callbacks
        __weak typeof(panelController) weakController = panelController;
        widget.onRemoveRequest = ^(BaseWidget *widgetToRemove) {
            [weakController removeWidget:widgetToRemove];
        };
        
        widget.onAddRequest = ^(BaseWidget *sourceWidget, WidgetAddDirection direction) {
            [weakController addNewWidgetFromWidget:sourceWidget inDirection:direction];
        };
        
        widget.onTypeChange = ^(BaseWidget *sourceWidget, NSString *newType) {
            [weakController transformWidget:sourceWidget toType:newType];
        };
        
        NSLog(@"✅ Successfully restored widget: %@ (ID: %@, Class: %@)",
              widget.widgetType, widget.widgetID, NSStringFromClass([widget class]));
        
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
