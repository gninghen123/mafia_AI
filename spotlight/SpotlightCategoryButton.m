//
//  SpotlightCategoryButton.m
//  TradingApp
//
//  Category button with dropdown menu implementation
//

#import "SpotlightCategoryButton.h"

@implementation SpotlightCategoryButton

#pragma mark - Initialization

- (instancetype)initWithCategoryType:(SpotlightCategoryType)categoryType {
    self = [super init];
    if (self) {
        _categoryType = categoryType;
        _isActive = NO;
        
        // Set default selections
        if (categoryType == SpotlightCategoryTypeDataSource) {
            _selectedDataSource = DataSourceTypeSchwab; // Default to Schwab
        } else {
            _selectedWidgetTarget = SpotlightWidgetTargetCenterPanel; // Default to center panel
        }
        
        [self configureButton];
    }
    return self;
}

#pragma mark - Configuration

- (void)configureButton {
    // Button appearance
    self.bezelStyle = NSBezelStyleRounded;
    self.buttonType = NSButtonTypeMomentaryPushIn;
    self.bordered = YES;
    
    // Size and layout
    self.translatesAutoresizingMaskIntoConstraints = NO;
    
    // Set initial title
    [self updateButtonTitle];
    
    // Setup action
    self.target = self;
    self.action = @selector(buttonClicked:);
    
    NSLog(@"🔧 SpotlightCategoryButton: Configured %@ button",
          self.categoryType == SpotlightCategoryTypeDataSource ? @"DataSource" : @"WidgetTarget");
}

- (void)updateButtonTitle {
    NSString *title = @"";
    
    if (self.categoryType == SpotlightCategoryTypeDataSource) {
        title = [NSString stringWithFormat:@"%@ ▼",
                [SpotlightCategoryButton displayNameForDataSource:self.selectedDataSource]];
    } else {
        title = [NSString stringWithFormat:@"%@ ▼",
                [SpotlightCategoryButton displayNameForWidgetTarget:self.selectedWidgetTarget]];
    }
    
    self.title = title;
}

#pragma mark - Menu Actions

- (IBAction)buttonClicked:(id)sender {
    [self showDropdownMenu];
}

- (void)showDropdownMenu {
    NSMenu *menu = [[NSMenu alloc] init];
    
    if (self.categoryType == SpotlightCategoryTypeDataSource) {
        [self setupDataSourceMenu:menu];
    } else {
        [self setupWidgetTargetMenu:menu];
    }
    
    // Show menu below button
    NSRect buttonFrame = self.frame;
    NSPoint menuLocation = NSMakePoint(0, -5);
    
    [menu popUpMenuPositioningItem:nil atLocation:menuLocation inView:self];
}

- (void)setupDataSourceMenu:(NSMenu *)menu {
    NSArray<NSNumber *> *dataSources = @[
        @(DataSourceTypeSchwab),
        @(DataSourceTypeYahoo),
        @(DataSourceTypeIBKR),
        @(DataSourceTypeWebull)
    ];
    
    for (NSNumber *dataSourceNum in dataSources) {
        DataSourceType dataSource = [dataSourceNum integerValue];
        NSString *title = [SpotlightCategoryButton displayNameForDataSource:dataSource];
        
        NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:title
                                                      action:@selector(dataSourceMenuItemSelected:)
                                               keyEquivalent:@""];
        item.target = self;
        item.tag = dataSource;
        
        // Check current selection
        if (dataSource == self.selectedDataSource) {
            item.state = NSControlStateValueOn;
        }
        
        [menu addItem:item];
    }
}

- (void)setupWidgetTargetMenu:(NSMenu *)menu {
    NSArray<NSNumber *> *targets = @[
        @(SpotlightWidgetTargetFloating),
        @(SpotlightWidgetTargetCenterPanel),
        @(SpotlightWidgetTargetLeftPanel),
        @(SpotlightWidgetTargetRightPanel)
    ];
    
    for (NSNumber *targetNum in targets) {
        SpotlightWidgetTarget target = [targetNum integerValue];
        NSString *title = [SpotlightCategoryButton displayNameForWidgetTarget:target];
        
        NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:title
                                                      action:@selector(widgetTargetMenuItemSelected:)
                                               keyEquivalent:@""];
        item.target = self;
        item.tag = target;
        
        // Check current selection
        if (target == self.selectedWidgetTarget) {
            item.state = NSControlStateValueOn;
        }
        
        [menu addItem:item];
    }
}

- (IBAction)dataSourceMenuItemSelected:(NSMenuItem *)sender {
    DataSourceType dataSource = (DataSourceType)sender.tag;
    [self selectDataSource:dataSource];
}

- (IBAction)widgetTargetMenuItemSelected:(NSMenuItem *)sender {
    SpotlightWidgetTarget target = (SpotlightWidgetTarget)sender.tag;
    [self selectWidgetTarget:target];
}

#pragma mark - Selection Methods

- (void)selectDataSource:(DataSourceType)dataSource {
    if (self.selectedDataSource != dataSource) {
        self.selectedDataSource = dataSource;
        [self updateButtonTitle];
        
        if ([self.delegate respondsToSelector:@selector(spotlightCategoryButton:didSelectDataSource:)]) {
            [self.delegate spotlightCategoryButton:self didSelectDataSource:dataSource];
        }
        
        NSLog(@"📊 SpotlightCategoryButton: Selected data source: %@",
              [SpotlightCategoryButton displayNameForDataSource:dataSource]);
    }
}

- (void)selectWidgetTarget:(SpotlightWidgetTarget)target {
    if (self.selectedWidgetTarget != target) {
        self.selectedWidgetTarget = target;
        [self updateButtonTitle];
        
        if ([self.delegate respondsToSelector:@selector(spotlightCategoryButton:didSelectWidgetTarget:)]) {
            [self.delegate spotlightCategoryButton:self didSelectWidgetTarget:target];
        }
        
        NSLog(@"🎯 SpotlightCategoryButton: Selected widget target: %@",
              [SpotlightCategoryButton displayNameForWidgetTarget:target]);
    }
}

#pragma mark - State Management

- (void)setActiveState:(BOOL)active {
    self.isActive = active;
    
    if (active) {
        // Highlight button
        [self highlight:YES];
        self.layer.borderWidth = 2.0;
        self.layer.borderColor = [NSColor controlAccentColor].CGColor;
    } else {
        // Remove highlight
        [self highlight:NO];
        self.layer.borderWidth = 0.0;
    }
}

#pragma mark - Helper Methods

+ (NSString *)displayNameForDataSource:(DataSourceType)dataSource {
    switch (dataSource) {
        case DataSourceTypeSchwab:
            return @"Schwab";
        case DataSourceTypeYahoo:
            return @"Yahoo";
        case DataSourceTypeIBKR:
            return @"IBKR";
        case DataSourceTypeWebull:
            return @"Webull";
        default:
            return @"Unknown";
    }
}

+ (NSString *)displayNameForWidgetTarget:(SpotlightWidgetTarget)target {
    switch (target) {
        case SpotlightWidgetTargetFloating:
            return @"Floating";
        case SpotlightWidgetTargetLeftPanel:
            return @"Left Panel";
        case SpotlightWidgetTargetRightPanel:
            return @"Right Panel";
        case SpotlightWidgetTargetCenterPanel:
            return @"Center Panel";
        default:
            return @"Unknown";
    }
}



@end
