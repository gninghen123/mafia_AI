
//
//  PanelSettingsDialog.m
//  TradingApp
//

#import "PanelSettingsDialog.h"
#import "IndicatorConfigurationDialog.h"
#import "IndicatorRegistry.h"

@interface PanelSettingsDialog () <NSOutlineViewDataSource, NSOutlineViewDelegate>
@property (nonatomic, strong, readwrite) ChartPanelTemplateModel *panelTemplate;
@property (nonatomic, strong, readwrite) ChartPanelTemplateModel *originalPanel;
@property (nonatomic, strong) NSArray<NSString *> *availableRootIndicators;
@end

@implementation PanelSettingsDialog

#pragma mark - Class Methods

+ (void)showSettingsForPanel:(ChartPanelTemplateModel *)panelTemplate
                parentWindow:(NSWindow *)parentWindow
                  completion:(PanelSettingsCompletionBlock)completion {
    
    PanelSettingsDialog *dialog = [[self alloc] initWithPanelTemplate:panelTemplate];
    [dialog showAsSheetForWindow:parentWindow completion:completion];
}

#pragma mark - Initialization

- (instancetype)initWithPanelTemplate:(ChartPanelTemplateModel *)panelTemplate {
    self = [super initWithWindowNibName:@"PanelSettingsDialog"];
    if (self) {
        _panelTemplate = panelTemplate;
        _originalPanel = panelTemplate;
        _workingPanel = [panelTemplate createWorkingCopy];
        
        // Load available root indicators
        _availableRootIndicators = @[
            @"SecurityIndicator",
            @"VolumeIndicator",
            @"RSIIndicator",
            @"MACDIndicator",
            @"StochasticIndicator",
            @"BollingerBandsIndicator",
            @"MovingAverageIndicator"
        ];
    }
    return self;
}

- (void)windowDidLoad {
    [super windowDidLoad];
    
    [self setupUI];
    [self setupRootIndicatorPopup];
    [self setupChildIndicatorsOutlineView];
    [self loadPanelData];
}

#pragma mark - UI Setup

- (void)setupUI {
    self.window.title = [NSString stringWithFormat:@"Panel Settings - %@", self.workingPanel.displayName];
    
    // Setup height slider
    self.heightSlider.minValue = 0.05; // 5% minimum
    self.heightSlider.maxValue = 0.80; // 80% maximum
    self.heightSlider.doubleValue = self.workingPanel.relativeHeight;
    
    // Setup auto height toggle
    self.autoHeightToggle.state = NSControlStateValueOff; // TODO: Add autoHeight property to model
    
    [self updateHeightControls];
}

- (void)setupRootIndicatorPopup {
    [self.rootIndicatorPopup removeAllItems];
    
    for (NSString *indicatorType in self.availableRootIndicators) {
        NSString *displayName = [self friendlyNameForIndicatorType:indicatorType];
        [self.rootIndicatorPopup addItemWithTitle:displayName];
        self.rootIndicatorPopup.lastItem.representedObject = indicatorType;
    }
    
    // Select current root indicator
    for (NSMenuItem *item in self.rootIndicatorPopup.itemArray) {
        if ([item.representedObject isEqualToString:self.workingPanel.rootIndicatorType]) {
            [self.rootIndicatorPopup selectItem:item];
            break;
        }
    }
}

- (void)setupChildIndicatorsOutlineView {
    self.childIndicatorsOutlineView.dataSource = self;
    self.childIndicatorsOutlineView.delegate = self;
    
    // Create table column if needed
    if (self.childIndicatorsOutlineView.tableColumns.count == 0) {
        NSTableColumn *column = [[NSTableColumn alloc] initWithIdentifier:@"ChildIndicatorColumn"];
        column.title = @"Child Indicators";
        column.width = 200;
        [self.childIndicatorsOutlineView addTableColumn:column];
    }
    
    [self.childIndicatorsOutlineView reloadData];
}

- (void)loadPanelData {
    // Load basic info
    self.panelNameField.stringValue = self.workingPanel.panelName ?: @"";
    self.displayOrderField.integerValue = self.workingPanel.displayOrder;
    
    // Update height display
    [self updateHeightControls];
    
    // Update root indicator info
    self.rootIndicatorLabel.stringValue = [self friendlyNameForIndicatorType:self.workingPanel.rootIndicatorType];
}

- (void)updateHeightControls {
    double heightPercentage = self.workingPanel.relativeHeight * 100.0;
    
    self.heightSlider.doubleValue = self.workingPanel.relativeHeight;
    self.heightLabel.stringValue = [NSString stringWithFormat:@"%.1f%%", heightPercentage];
    self.heightPercentageLabel.stringValue = [NSString stringWithFormat:@"%.1f%% of total chart height", heightPercentage];
    
    // Enable/disable height controls based on auto height
    BOOL autoHeight = (self.autoHeightToggle.state == NSControlStateValueOn);
    self.heightSlider.enabled = !autoHeight;
}

#pragma mark - Helper Methods

- (NSString *)friendlyNameForIndicatorType:(NSString *)indicatorType {
    // Remove "Indicator" suffix and add spaces
    NSString *name = [indicatorType stringByReplacingOccurrencesOfString:@"Indicator" withString:@""];
    
    // Add spaces before capital letters
    NSMutableString *friendlyName = [[NSMutableString alloc] init];
    for (NSUInteger i = 0; i < name.length; i++) {
        unichar c = [name characterAtIndex:i];
        
        if (i > 0 && [[NSCharacterSet uppercaseLetterCharacterSet] characterIsMember:c]) {
            [friendlyName appendString:@" "];
        }
        
        [friendlyName appendString:[NSString stringWithCharacters:&c length:1]];
    }
    
    return [friendlyName copy];
}

#pragma mark - Dialog Management

- (void)showAsSheetForWindow:(NSWindow *)parentWindow completion:(PanelSettingsCompletionBlock)completion {
    self.completionBlock = completion;
    
    [parentWindow beginSheet:self.window completionHandler:^(NSModalResponse returnCode) {
        BOOL saved = (returnCode == NSModalResponseOK);
        ChartPanelTemplateModel *panel = saved ? self.workingPanel : nil;
        
        if (completion) {
            completion(saved, panel);
        }
    }];
}

#pragma mark - Actions - Basic

- (IBAction)saveAction:(NSButton *)sender {
    NSError *error;
    if (![self validatePanelSettings:&error]) {
        NSAlert *alert = [[NSAlert alloc] init];
        alert.messageText = @"Invalid Panel Settings";
        alert.informativeText = error.localizedDescription;
        alert.alertStyle = NSAlertStyleWarning;
        [alert addButtonWithTitle:@"OK"];
        [alert beginSheetModalForWindow:self.window completionHandler:nil];
        return;
    }
