//
//  PanelController.m
//  TradingApp
//

#import "PanelController.h"
#import "BaseWidget.h"
#import "WidgetContainerView.h"
#import "PanelHeaderView.h"
#import "WidgetTypeManager.h"
#import "QuoteWidget.h"

@interface PanelController ()
@property (nonatomic, strong) WidgetContainerView *containerView;
@property (nonatomic, strong) PanelHeaderView *headerView;
@property (nonatomic, strong) NSMutableArray<BaseWidget *> *mutableWidgets;
@property (nonatomic, strong) NSPopUpButton *layoutPopup;
@property (nonatomic, strong) NSTextField *layoutNameField;
@end

@implementation PanelController

- (instancetype)initWithPanelType:(PanelType)panelType {
    self = [super init];
    if (self) {
        _panelType = panelType;
        _mutableWidgets = [NSMutableArray array];
        [self setupViews];
    }
    return self;
}

- (void)loadView {
    self.view = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 400, 600)];
}

- (void)setupViews {
    // Create header view with layout controls
    self.headerView = [[PanelHeaderView alloc] initWithFrame:NSMakeRect(0, 0, 400, 40)];
    self.headerView.panelController = self;
    
    // Create container view for widgets
    self.containerView = [[WidgetContainerView alloc] initWithFrame:NSMakeRect(0, 0, 400, 560)];
    self.containerView.panelController = self;
    
    // Layout with stack view
    NSStackView *stackView = [[NSStackView alloc] init];
    stackView.orientation = NSUserInterfaceLayoutOrientationVertical;
    stackView.spacing = 0;
    stackView.distribution = NSStackViewDistributionFill;
    
    [stackView addArrangedSubview:self.headerView];
    [stackView addArrangedSubview:self.containerView];
    
    // Add to main view
    [self.view addSubview:stackView];
    
    // Setup constraints
    stackView.translatesAutoresizingMaskIntoConstraints = NO;
    [NSLayoutConstraint activateConstraints:@[
        [stackView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [stackView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [stackView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [stackView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor]
    ]];
    
    // Add default widget if none exists
    if (self.mutableWidgets.count == 0) {
        [self addDefaultWidget];
    }
}

- (void)addDefaultWidget {
    BaseWidget *defaultWidget;
    
    if (self.panelType == PanelTypeCenter) {
        // Usa l'ultimo tipo salvato o fallback a Chart Widget
        NSString *lastType = [[NSUserDefaults standardUserDefaults] stringForKey:@"LastCurrentWidgetType"];
        NSString *widgetTypeToUse = lastType ?: @"Chart Widget";
        Class chartWidgetClass = [[WidgetTypeManager sharedManager] classForWidgetType:widgetTypeToUse];
        
        if (chartWidgetClass) {
            defaultWidget = [[chartWidgetClass alloc] initWithType:widgetTypeToUse
                                                        panelType:self.panelType];
        } else {
            // Fallback se non trova la classe
            defaultWidget = [[BaseWidget alloc] initWithType:widgetTypeToUse
                                                  panelType:self.panelType];
        }
    } else {
        // Per altri pannelli usa Empty Widget
        defaultWidget = [[BaseWidget alloc] initWithType:@"Empty Widget"
                                              panelType:self.panelType];
    }
    
    // ✅ STEP 2: Aggiungi il widget (configura automaticamente i callback)
    [self addWidget:defaultWidget];
    
    // ✅ STEP 3: Forza loadView se necessario
    if (!defaultWidget.view) {
        [defaultWidget loadView];
    }
}

#pragma mark - Widget Management

- (void)addWidget:(BaseWidget *)widget {
    [self.mutableWidgets addObject:widget];
    [self.containerView addWidget:widget];
    
    // Set up widget callbacks
    __weak typeof(self) weakSelf = self;
    widget.onRemoveRequest = ^(BaseWidget *widgetToRemove) {
        [weakSelf removeWidget:widgetToRemove];
    };
    
    widget.onAddRequest = ^(BaseWidget *sourceWidget, WidgetAddDirection direction) {
        [weakSelf addNewWidgetFromWidget:sourceWidget inDirection:direction];
    };
    
    widget.onTypeChange = ^(BaseWidget *sourceWidget, NSString *newType) {
        [weakSelf transformWidget:sourceWidget toType:newType];
    };
}

- (void)transformWidget:(BaseWidget *)oldWidget toType:(NSString *)newType {
    // Controlla se il tipo richiesto è già quello attuale
    if ([oldWidget.widgetType isEqualToString:newType]) {
        Class currentClass = [oldWidget class];
        Class targetClass = [[WidgetTypeManager sharedManager] widgetClassForType:newType];

        if (targetClass == currentClass) {
            NSLog(@"🟡 Widget already of type %@ — no transformation needed", newType);
            return; // ❌ Non trasformare
        }
    }
    [[NSUserDefaults standardUserDefaults] setObject:newType forKey:@"LastCurrentWidgetType"];


    NSLog(@"=== DEBUG transformWidget ===");
    NSLog(@"Transform request: %@ (%@) -> %@", oldWidget.widgetType, [oldWidget class], newType);
    
    // Get the widget class for the new type
    Class widgetClass = [[WidgetTypeManager sharedManager] widgetClassForType:newType];
    NSLog(@"Widget class for '%@': %@", newType, widgetClass);
    NSLog(@"Old widget class: %@", [oldWidget class]);
    
    if (!widgetClass || widgetClass == [oldWidget class]) {
        NSLog(@"No transformation needed - same class or nil class");
        return;
    }
    
    // Find the index of the old widget
    NSInteger widgetIndex = [self.mutableWidgets indexOfObject:oldWidget];
    if (widgetIndex == NSNotFound) {
        NSLog(@"ERROR: Old widget not found in mutableWidgets array");
        return;
    }
    NSLog(@"Old widget found at index: %ld", (long)widgetIndex);
    
    // Create new widget instance
    BaseWidget *newWidget = [[widgetClass alloc] initWithType:newType panelType:self.panelType];
    [newWidget loadView];  // Force view creation

    NSLog(@"Created new widget: %@ (%@)", newWidget.widgetType, [newWidget class]);
    
    // Copy state from old widget
    newWidget.widgetID = oldWidget.widgetID;
    newWidget.collapsed = oldWidget.collapsed;
    newWidget.chainColor = oldWidget.chainColor;
    
    // Replace in the container view
    NSLog(@"Replacing widget in container view...");
    [self.containerView replaceWidget:oldWidget withWidget:newWidget];
    
    // Replace in the widgets array
    NSLog(@"Replacing widget in array...");
    [self.mutableWidgets replaceObjectAtIndex:widgetIndex withObject:newWidget];
    
    // Setup callbacks for new widget
    __weak typeof(self) weakSelf = self;
    newWidget.onRemoveRequest = ^(BaseWidget *widgetToRemove) {
        [weakSelf removeWidget:widgetToRemove];
    };
    
    newWidget.onAddRequest = ^(BaseWidget *sourceWidget, WidgetAddDirection direction) {
        [weakSelf addNewWidgetFromWidget:sourceWidget inDirection:direction];
    };
    
    newWidget.onTypeChange = ^(BaseWidget *sourceWidget, NSString *newType) {
        [weakSelf transformWidget:sourceWidget toType:newType];
    };
    
    NSLog(@"Widget transformation completed successfully");
    NSLog(@"=== END DEBUG transformWidget ===");
}

- (void)removeWidget:(BaseWidget *)widget {
    if (![self canRemoveWidget:widget]) {
        NSAlert *alert = [[NSAlert alloc] init];
        alert.messageText = @"Cannot Remove Widget";
        alert.informativeText = @"At least one widget must remain in the panel.";
        [alert addButtonWithTitle:@"OK"];
        [alert runModal];
        return;
    }
    
    [self.mutableWidgets removeObject:widget];
    [self.containerView removeWidget:widget];
}

- (BOOL)canRemoveWidget:(BaseWidget *)widget {
    return self.mutableWidgets.count > 1;
}

- (NSInteger)widgetCount {
    return self.mutableWidgets.count;
}

- (void)addNewWidgetFromWidget:(BaseWidget *)sourceWidget inDirection:(WidgetAddDirection)direction {
    // Crea il nuovo widget
    BaseWidget *newWidget = [[BaseWidget alloc] initWithType:@"Empty Widget"
                                                  panelType:self.panelType];
    
    // IMPORTANTE: Prima aggiungi alla collezione interna
    [self.mutableWidgets addObject:newWidget];
    
    // Poi inserisci nella vista container
    [self.containerView insertWidget:newWidget
                       relativeToWidget:sourceWidget
                          inDirection:direction];
    
    // ✅ Configura TUTTI i callback per il nuovo widget
    __weak typeof(self) weakSelf = self;
    newWidget.onRemoveRequest = ^(BaseWidget *widgetToRemove) {
        [weakSelf removeWidget:widgetToRemove];
    };
    
    newWidget.onAddRequest = ^(BaseWidget *sourceWidget, WidgetAddDirection direction) {
        [weakSelf addNewWidgetFromWidget:sourceWidget inDirection:direction];
    };
    
    // ✅ AGGIUNTO: Callback mancante per la trasformazione
    newWidget.onTypeChange = ^(BaseWidget *sourceWidget, NSString *newType) {
        [weakSelf transformWidget:sourceWidget toType:newType];
    };
}

- (void)addWidgetToCollection:(BaseWidget *)widget {
    [self.mutableWidgets addObject:widget];
}

#pragma mark - Layout Serialization

- (NSDictionary *)serializeLayout {
    NSMutableDictionary *layout = [NSMutableDictionary dictionary];
    layout[@"panelType"] = @(self.panelType);
    
    NSDictionary *containerStructure = [self.containerView serializeStructure];
    if (containerStructure) {
        layout[@"containerStructure"] = containerStructure;
    } else {
        NSLog(@"WARNING: Container structure is nil for panel type %ld", (long)self.panelType);
    }
    
    // Serialize individual widget states
    NSMutableArray *widgetStates = [NSMutableArray array];
    for (BaseWidget *widget in self.mutableWidgets) {
        NSDictionary *state = [widget serializeState];
        if (state) {
            [widgetStates addObject:state];
            // ✅ DEBUG: Log dettagliato dei widget serializzati
            NSLog(@"🔍 SERIALIZE WIDGET: ID=%@, Type=%@, Class=%@",
                  state[@"widgetID"], state[@"widgetType"], NSStringFromClass([widget class]));
            NSLog(@"   Full state: %@", state);
        } else {
            NSLog(@"❌ SERIALIZE ERROR: Widget %@ returned nil state!", widget.widgetID);
        }
    }
    layout[@"widgetStates"] = widgetStates;
    
    NSLog(@"📦 SERIALIZE COMPLETE: Panel %ld with %lu widgets", (long)self.panelType, (unsigned long)widgetStates.count);
    NSLog(@"   Container structure keys: %@", containerStructure.allKeys);
    NSLog(@"   Widget states count: %lu", (unsigned long)widgetStates.count);
    
    return layout;
}
- (void)restoreLayout:(NSDictionary *)layoutData {
    NSLog(@"🔄 RESTORE LAYOUT START: Panel type %ld", (long)self.panelType);
    NSLog(@"   Layout data keys: %@", layoutData.allKeys);
    
    if (!layoutData || layoutData.count == 0) {
        NSLog(@"❌ RESTORE FAILED: No layout data");
        return;
    }
    
    // Clear current widgets
    [self.containerView clearAllWidgets];
    [self.mutableWidgets removeAllObjects];
    
    // Restore container structure and widgets
    NSDictionary *containerStructure = layoutData[@"containerStructure"];
    NSArray *widgetStates = layoutData[@"widgetStates"];
    
    NSLog(@"🔍 RESTORE DATA:");
    NSLog(@"   Container structure: %@", containerStructure ? @"EXISTS" : @"NIL");
    NSLog(@"   Widget states count: %lu", (unsigned long)widgetStates.count);
    
    if (containerStructure && widgetStates) {
        NSLog(@"🔄 CALLING restoreStructure...");
        [self.containerView restoreStructure:containerStructure
                             withWidgetStates:widgetStates
                             panelController:self];
        NSLog(@"✅ RESTORE COMPLETE: %lu widgets restored", (unsigned long)self.mutableWidgets.count);
    } else {
        NSLog(@"❌ RESTORE FAILED: Missing container structure or widget states");
        [self addDefaultWidget];
    }
}

#pragma mark - Layout Presets

- (void)saveCurrentLayoutAsPreset:(NSString *)presetName {
    NSString *key = [NSString stringWithFormat:@"PanelPreset_%ld_%@",
                     (long)self.panelType, presetName];
    NSDictionary *layout = [self serializeLayout];
    [[NSUserDefaults standardUserDefaults] setObject:layout forKey:key];
}

- (void)loadLayoutPreset:(NSString *)presetName {
    NSString *key = [NSString stringWithFormat:@"PanelPreset_%ld_%@",
                     (long)self.panelType, presetName];
    NSDictionary *layout = [[NSUserDefaults standardUserDefaults] objectForKey:key];
    [self restoreLayout:layout];
}

- (NSArray *)availablePresets {
    NSMutableArray *presets = [NSMutableArray array];
    NSString *prefix = [NSString stringWithFormat:@"PanelPreset_%ld_", (long)self.panelType];
    
    NSDictionary *defaults = [[NSUserDefaults standardUserDefaults] dictionaryRepresentation];
    for (NSString *key in defaults.allKeys) {
        if ([key hasPrefix:prefix]) {
            NSString *presetName = [key substringFromIndex:prefix.length];
            [presets addObject:presetName];
        }
    }
    
    return presets;
}

#pragma mark - Properties

- (NSArray<BaseWidget *> *)widgets {
    return [self.mutableWidgets copy];
}

@end
