//
//  ChartObjectSettingsWindow.m
//  TradingApp
//
//  Chart Object Settings Popup Window Implementation
//

#import "ChartObjectSettingsWindow.h"
#import "ChartObjectsManager.h"
#import "ChartObjectModels.h"

@interface ChartObjectSettingsWindow ()
@property (nonatomic, strong) NSView *contentContainer;
@property (nonatomic, strong) ObjectStyleModel *originalStyle;
@property (nonatomic, strong) ObjectStyleModel *workingStyle;
@end

@implementation ChartObjectSettingsWindow

#pragma mark - Initialization

- (instancetype)initWithObject:(ChartObjectModel *)object
                objectsManager:(ChartObjectsManager *)manager {
    
    NSRect windowFrame = NSMakeRect(0, 0, 340, 450);
    
    self = [super initWithContentRect:windowFrame
                            styleMask:(NSWindowStyleMaskTitled |
                                     NSWindowStyleMaskClosable |
                                     NSWindowStyleMaskResizable)
                              backing:NSBackingStoreBuffered
                                defer:NO];
    
    if (self) {
        _targetObject = object;
        _objectsManager = manager;
        
        // Create working copy of style
        _originalStyle = [object.style copy];
        _workingStyle = [object.style copy];
        
        [self setupWindow];
        [self setupUI];
        [self refreshUI];
        
        NSLog(@"✅ ChartObjectSettingsWindow: Initialized for object '%@'", object.name);
    }
    
    return self;
}

#pragma mark - Window Setup

- (void)setupWindow {
    self.title = @"Object Settings";
    self.level = NSFloatingWindowLevel;
    self.hidesOnDeactivate = NO;
    self.backgroundColor = [NSColor controlBackgroundColor];
    
    // Center the window
    [self center];
}

- (void)setupUI {
    // Main content container
    self.contentContainer = [[NSView alloc] init];
    self.contentContainer.translatesAutoresizingMaskIntoConstraints = NO;
    [self.contentView addSubview:self.contentContainer];
    
    [self createHeaderSection];
    [self createStyleSection];
    [self createVisibilitySection];
    [self createActionButtons];
    [self setupConstraints];
}

- (void)createHeaderSection {
    // Object name label
    self.objectNameLabel = [[NSTextField alloc] init];
    self.objectNameLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.objectNameLabel.editable = NO;
    self.objectNameLabel.bordered = NO;
    self.objectNameLabel.backgroundColor = [NSColor clearColor];
    self.objectNameLabel.font = [NSFont systemFontOfSize:16 weight:NSFontWeightSemibold];
    self.objectNameLabel.alignment = NSTextAlignmentCenter;
    [self.contentContainer addSubview:self.objectNameLabel];
    
    // Object type label
    self.objectTypeLabel = [[NSTextField alloc] init];
    self.objectTypeLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.objectTypeLabel.editable = NO;
    self.objectTypeLabel.bordered = NO;
    self.objectTypeLabel.backgroundColor = [NSColor clearColor];
    self.objectTypeLabel.font = [NSFont systemFontOfSize:12];
    self.objectTypeLabel.textColor = [NSColor secondaryLabelColor];
    self.objectTypeLabel.alignment = NSTextAlignmentCenter;
    [self.contentContainer addSubview:self.objectTypeLabel];
}

- (void)createStyleSection {
    // Style section title
    NSTextField *styleTitle = [self createSectionTitle:@"Style Properties"];
    [self.contentContainer addSubview:styleTitle];
    
    // Color well with label
    NSTextField *colorLabel = [self createLabel:@"Color:"];
    self.colorWell = [[NSColorWell alloc] init];
    self.colorWell.translatesAutoresizingMaskIntoConstraints = NO;
    self.colorWell.action = @selector(colorChanged:);
    self.colorWell.target = self;
    
    NSView *colorGroup = [self createControlGroup:colorLabel control:self.colorWell];
    [self.contentContainer addSubview:colorGroup];
    
    // Thickness slider with label
    NSTextField *thicknessLabelText = [self createLabel:@"Thickness:"];
    self.thicknessSlider = [[NSSlider alloc] init];
    self.thicknessSlider.translatesAutoresizingMaskIntoConstraints = NO;
    self.thicknessSlider.minValue = 0.5;
    self.thicknessSlider.maxValue = 8.0;
    self.thicknessSlider.action = @selector(thicknessChanged:);
    self.thicknessSlider.target = self;
    
    self.thicknessLabel = [self createValueLabel:@"2.0"];
    
    NSView *thicknessGroup = [self createSliderGroup:thicknessLabelText
                                              slider:self.thicknessSlider
                                           valueLabel:self.thicknessLabel];
    [self.contentContainer addSubview:thicknessGroup];
    
    // Line type popup
    NSTextField *lineTypeLabel = [self createLabel:@"Line Type:"];
    self.lineTypePopup = [[NSPopUpButton alloc] init];
    self.lineTypePopup.translatesAutoresizingMaskIntoConstraints = NO;
    [self.lineTypePopup addItemWithTitle:@"Solid"];
    [self.lineTypePopup addItemWithTitle:@"Dashed"];
    [self.lineTypePopup addItemWithTitle:@"Dotted"];
    [self.lineTypePopup addItemWithTitle:@"Dash-Dot"];
    self.lineTypePopup.action = @selector(lineTypeChanged:);
    self.lineTypePopup.target = self;
    
    NSView *lineTypeGroup = [self createControlGroup:lineTypeLabel control:self.lineTypePopup];
    [self.contentContainer addSubview:lineTypeGroup];
    
    // Opacity slider with label
    NSTextField *opacityLabelText = [self createLabel:@"Opacity:"];
    self.opacitySlider = [[NSSlider alloc] init];
    self.opacitySlider.translatesAutoresizingMaskIntoConstraints = NO;
    self.opacitySlider.minValue = 0.1;
    self.opacitySlider.maxValue = 1.0;
    self.opacitySlider.action = @selector(opacityChanged:);
    self.opacitySlider.target = self;
    
    self.opacityLabel = [self createValueLabel:@"1.0"];
    
    NSView *opacityGroup = [self createSliderGroup:opacityLabelText
                                            slider:self.opacitySlider
                                         valueLabel:self.opacityLabel];
    [self.contentContainer addSubview:opacityGroup];
}

- (void)createVisibilitySection {
    // Visibility section title
    NSTextField *visibilityTitle = [self createSectionTitle:@"Object State"];
    [self.contentContainer addSubview:visibilityTitle];
    
    // Visibility checkbox
    self.visibilityCheckbox = [[NSButton alloc] init];
    self.visibilityCheckbox.translatesAutoresizingMaskIntoConstraints = NO;
    self.visibilityCheckbox.buttonType = NSButtonTypeSwitch;
    self.visibilityCheckbox.title = @"Visible";
    self.visibilityCheckbox.action = @selector(visibilityChanged:);
    self.visibilityCheckbox.target = self;
    [self.contentContainer addSubview:self.visibilityCheckbox];
    
    // Lock checkbox
    self.lockCheckbox = [[NSButton alloc] init];
    self.lockCheckbox.translatesAutoresizingMaskIntoConstraints = NO;
    self.lockCheckbox.buttonType = NSButtonTypeSwitch;
    self.lockCheckbox.title = @"Locked";
    self.lockCheckbox.action = @selector(lockChanged:);
    self.lockCheckbox.target = self;
    [self.contentContainer addSubview:self.lockCheckbox];
}

- (void)createActionButtons {
    // Button container
    NSView *buttonContainer = [[NSView alloc] init];
    buttonContainer.translatesAutoresizingMaskIntoConstraints = NO;
    [self.contentContainer addSubview:buttonContainer];
    
    // Apply button
    self.applyButton = [NSButton buttonWithTitle:@"Apply" target:self action:@selector(applyButtonClicked:)];
    self.applyButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.applyButton.bezelStyle = NSBezelStyleRounded;
    self.applyButton.keyEquivalent = @"\r"; // Enter key
    [buttonContainer addSubview:self.applyButton];
    
    // Cancel button
    self.cancelButton = [NSButton buttonWithTitle:@"Cancel" target:self action:@selector(cancelButtonClicked:)];
    self.cancelButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.cancelButton.bezelStyle = NSBezelStyleRounded;
    self.cancelButton.keyEquivalent = @"\033"; // Escape key
    [buttonContainer addSubview:self.cancelButton];
    
    // Delete button
    self.deleteButton = [NSButton buttonWithTitle:@"Delete" target:self action:@selector(deleteButtonClicked:)];
    self.deleteButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.deleteButton.bezelStyle = NSBezelStyleRounded;
    self.deleteButton.contentTintColor = [NSColor systemRedColor];
    [buttonContainer addSubview:self.deleteButton];
    
    // Button constraints
    [NSLayoutConstraint activateConstraints:@[
        [self.applyButton.trailingAnchor constraintEqualToAnchor:buttonContainer.trailingAnchor],
        [self.applyButton.centerYAnchor constraintEqualToAnchor:buttonContainer.centerYAnchor],
        [self.applyButton.widthAnchor constraintEqualToConstant:80],
        
        [self.cancelButton.trailingAnchor constraintEqualToAnchor:self.applyButton.leadingAnchor constant:-8],
        [self.cancelButton.centerYAnchor constraintEqualToAnchor:buttonContainer.centerYAnchor],
        [self.cancelButton.widthAnchor constraintEqualToConstant:80],
        
        [self.deleteButton.leadingAnchor constraintEqualToAnchor:buttonContainer.leadingAnchor],
        [self.deleteButton.centerYAnchor constraintEqualToAnchor:buttonContainer.centerYAnchor],
        [self.deleteButton.widthAnchor constraintEqualToConstant:80],
        
        [buttonContainer.heightAnchor constraintEqualToConstant:40]
    ]];
}

#pragma mark - UI Helpers

- (NSTextField *)createSectionTitle:(NSString *)title {
    NSTextField *label = [[NSTextField alloc] init];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    label.stringValue = title;
    label.font = [NSFont systemFontOfSize:14 weight:NSFontWeightSemibold];
    label.textColor = [NSColor labelColor];
    label.editable = NO;
    label.bordered = NO;
    label.backgroundColor = [NSColor clearColor];
    return label;
}

- (NSTextField *)createLabel:(NSString *)text {
    NSTextField *label = [[NSTextField alloc] init];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    label.stringValue = text;
    label.font = [NSFont systemFontOfSize:12];
    label.textColor = [NSColor labelColor];
    label.editable = NO;
    label.bordered = NO;
    label.backgroundColor = [NSColor clearColor];
    [label setContentHuggingPriority:NSLayoutPriorityRequired forOrientation:NSLayoutConstraintOrientationHorizontal];
    return label;
}

- (NSTextField *)createValueLabel:(NSString *)text {
    NSTextField *label = [self createLabel:text];
    label.alignment = NSTextAlignmentRight;
    label.font = [NSFont monospacedDigitSystemFontOfSize:12 weight:NSFontWeightMedium];
    label.textColor = [NSColor secondaryLabelColor];
    [label setContentHuggingPriority:NSLayoutPriorityRequired forOrientation:NSLayoutConstraintOrientationHorizontal];
    return label;
}

- (NSView *)createControlGroup:(NSTextField *)label control:(NSControl *)control {
    NSView *group = [[NSView alloc] init];
    group.translatesAutoresizingMaskIntoConstraints = NO;
    
    [group addSubview:label];
    [group addSubview:control];
    
    [NSLayoutConstraint activateConstraints:@[
        [label.leadingAnchor constraintEqualToAnchor:group.leadingAnchor],
        [label.centerYAnchor constraintEqualToAnchor:group.centerYAnchor],
        [label.widthAnchor constraintEqualToConstant:80],
        
        [control.leadingAnchor constraintEqualToAnchor:label.trailingAnchor constant:12],
        [control.trailingAnchor constraintEqualToAnchor:group.trailingAnchor],
        [control.centerYAnchor constraintEqualToAnchor:group.centerYAnchor],
        
        [group.heightAnchor constraintEqualToConstant:28]
    ]];
    
    return group;
}

- (NSView *)createSliderGroup:(NSTextField *)label slider:(NSSlider *)slider valueLabel:(NSTextField *)valueLabel {
    NSView *group = [[NSView alloc] init];
    group.translatesAutoresizingMaskIntoConstraints = NO;
    
    [group addSubview:label];
    [group addSubview:slider];
    [group addSubview:valueLabel];
    
    [NSLayoutConstraint activateConstraints:@[
        [label.leadingAnchor constraintEqualToAnchor:group.leadingAnchor],
        [label.centerYAnchor constraintEqualToAnchor:group.centerYAnchor],
        [label.widthAnchor constraintEqualToConstant:80],
        
        [slider.leadingAnchor constraintEqualToAnchor:label.trailingAnchor constant:12],
        [slider.centerYAnchor constraintEqualToAnchor:group.centerYAnchor],
        
        [valueLabel.leadingAnchor constraintEqualToAnchor:slider.trailingAnchor constant:8],
        [valueLabel.trailingAnchor constraintEqualToAnchor:group.trailingAnchor],
        [valueLabel.centerYAnchor constraintEqualToAnchor:group.centerYAnchor],
        [valueLabel.widthAnchor constraintEqualToConstant:40],
        
        [group.heightAnchor constraintEqualToConstant:28]
    ]];
    
    return group;
}

- (void)setupConstraints {
    NSArray *allSubviews = self.contentContainer.subviews;
    
    [NSLayoutConstraint activateConstraints:@[
        // Content container
        [self.contentContainer.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:16],
        [self.contentContainer.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:16],
        [self.contentContainer.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-16],
        [self.contentContainer.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-16]
    ]];
    
    // Vertical spacing between all components
    NSLayoutConstraint *previousConstraint = [self.objectNameLabel.topAnchor constraintEqualToAnchor:self.contentContainer.topAnchor];
    previousConstraint.active = YES;
    
    for (NSInteger i = 1; i < allSubviews.count; i++) {
        NSView *currentView = allSubviews[i];
        NSView *previousView = allSubviews[i-1];
        
        CGFloat spacing = 12;
        if ([currentView isKindOfClass:[NSTextField class]] &&
            [(NSTextField *)currentView font].pointSize >= 14) {
            spacing = 20; // More space before section titles
        }
        
        NSLayoutConstraint *constraint = [currentView.topAnchor constraintEqualToAnchor:previousView.bottomAnchor constant:spacing];
        constraint.active = YES;
    }
    
    // Leading/trailing constraints for all views
    for (NSView *view in allSubviews) {
        [NSLayoutConstraint activateConstraints:@[
            [view.leadingAnchor constraintEqualToAnchor:self.contentContainer.leadingAnchor],
            [view.trailingAnchor constraintEqualToAnchor:self.contentContainer.trailingAnchor]
        ]];
    }
}

#pragma mark - Public Methods

- (void)showSettingsForObject:(ChartObjectModel *)object {
    self.targetObject = object;
    self.originalStyle = [object.style copy];
    self.workingStyle = [object.style copy];
    
    [self refreshUI];
    [self makeKeyAndOrderFront:nil];
    
    NSLog(@"🔧 ChartObjectSettingsWindow: Showing settings for object '%@'", object.name);
}

- (void)refreshUI {
    if (!self.targetObject) return;
    
    // Update header
    self.objectNameLabel.stringValue = self.targetObject.name;
    self.objectTypeLabel.stringValue = [self stringForObjectType:self.targetObject.type];
    
    // Update style controls
    self.colorWell.color = self.workingStyle.color;
    self.thicknessSlider.doubleValue = self.workingStyle.thickness;
    self.thicknessLabel.stringValue = [NSString stringWithFormat:@"%.1f", self.workingStyle.thickness];
    [self.lineTypePopup selectItemAtIndex:self.workingStyle.lineType];
    self.opacitySlider.doubleValue = self.workingStyle.opacity;
    self.opacityLabel.stringValue = [NSString stringWithFormat:@"%.1f", self.workingStyle.opacity];
    
    // Update state controls
    self.visibilityCheckbox.state = self.targetObject.isVisible ? NSControlStateValueOn : NSControlStateValueOff;
    self.lockCheckbox.state = self.targetObject.isLocked ? NSControlStateValueOn : NSControlStateValueOff;
}

- (NSString *)stringForObjectType:(ChartObjectType)type {
    switch (type) {
        case ChartObjectTypeHorizontalLine: return @"Horizontal Line";
        case ChartObjectTypeTrendline: return @"Trendline";
        case ChartObjectTypeFibonacci: return @"Fibonacci";
        case ChartObjectTypeRectangle: return @"Rectangle";
        case ChartObjectTypeCircle: return @"Circle";
        case ChartObjectTypeChannel: return @"Channel";
        case ChartObjectTypeTarget: return @"Target Price";
        case ChartObjectTypeFreeDrawing: return @"Free Drawing";
        default: return @"Unknown";
    }
}

#pragma mark - Actions

- (IBAction)colorChanged:(id)sender {
    self.workingStyle.color = self.colorWell.color;
    [self applyWorkingStyleToObject];
    NSLog(@"🎨 Color changed to: %@", self.colorWell.color);
}

- (IBAction)thicknessChanged:(id)sender {
    self.workingStyle.thickness = self.thicknessSlider.doubleValue;
    self.thicknessLabel.stringValue = [NSString stringWithFormat:@"%.1f", self.workingStyle.thickness];
    [self applyWorkingStyleToObject];
    NSLog(@"📏 Thickness changed to: %.1f", self.workingStyle.thickness);
}

- (IBAction)lineTypeChanged:(id)sender {
    self.workingStyle.lineType = (ChartLineType)self.lineTypePopup.indexOfSelectedItem;
    [self applyWorkingStyleToObject];
    NSLog(@"📝 Line type changed to: %ld", (long)self.workingStyle.lineType);
}

- (IBAction)opacityChanged:(id)sender {
    self.workingStyle.opacity = self.opacitySlider.doubleValue;
    self.opacityLabel.stringValue = [NSString stringWithFormat:@"%.1f", self.workingStyle.opacity];
    [self applyWorkingStyleToObject];
    NSLog(@"💫 Opacity changed to: %.1f", self.workingStyle.opacity);
}

- (IBAction)visibilityChanged:(id)sender {
    self.targetObject.isVisible = (self.visibilityCheckbox.state == NSControlStateValueOn);
    [self requestChartRefresh];
    NSLog(@"👁️ Visibility changed to: %@", self.targetObject.isVisible ? @"visible" : @"hidden");
}

- (IBAction)lockChanged:(id)sender {
    self.targetObject.isLocked = (self.lockCheckbox.state == NSControlStateValueOn);
    NSLog(@"🔒 Lock state changed to: %@", self.targetObject.isLocked ? @"locked" : @"unlocked");
}

- (IBAction)applyButtonClicked:(id)sender {
    NSLog(@"✅ ChartObjectSettingsWindow: Applying settings for object '%@'", self.targetObject.name);
    
    // Apply the working style permanently
    self.targetObject.style = [self.workingStyle copy];
    self.targetObject.lastModified = [NSDate date];
    
    // Find and update layer timestamp
    for (ChartLayerModel *layer in self.objectsManager.layers) {
        if ([layer.objects containsObject:self.targetObject]) {
            layer.lastModified = [NSDate date];
            break;
        }
    }
    
    // Save to DataHub
    [self.objectsManager saveToDataHub];
    NSLog(@"💾 ChartObjectSettingsWindow: Saved to DataHub");
    
    // ✅ NUOVO: Trigger chart redraw via callback
    if (self.onApplyCallback) {
        self.onApplyCallback(self.targetObject);
        NSLog(@"🔄 ChartObjectSettingsWindow: Triggered chart redraw via callback");
    } else {
        // ✅ FALLBACK: Trigger redraw via notification
        [[NSNotificationCenter defaultCenter] postNotificationName:@"ChartObjectSettingsApplied"
                                                            object:self
                                                          userInfo:@{
                                                              @"object": self.targetObject,
                                                              @"symbol": self.objectsManager.currentSymbol
                                                          }];
        NSLog(@"🔄 ChartObjectSettingsWindow: Triggered chart redraw via notification");
    }
    
    [self close];
    NSLog(@"✅ ChartObjectSettingsWindow: Settings applied successfully");
}
- (IBAction)cancelButtonClicked:(id)sender {
    // Restore original style
    self.targetObject.style = [self.originalStyle copy];
    [self requestChartRefresh];
    
    [self close];
    NSLog(@"❌ ChartObjectSettingsWindow: Cancelled changes");
}

- (IBAction)deleteButtonClicked:(id)sender {
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"Delete Object";
    alert.informativeText = [NSString stringWithFormat:@"Are you sure you want to delete '%@'?", self.targetObject.name];
    [alert addButtonWithTitle:@"Delete"];
    [alert addButtonWithTitle:@"Cancel"];
    alert.alertStyle = NSAlertStyleWarning;
    
    [alert beginSheetModalForWindow:self completionHandler:^(NSModalResponse returnCode) {
        if (returnCode == NSAlertFirstButtonReturn) {
            [self.objectsManager deleteObject:self.targetObject];
            [self close];
            NSLog(@"🗑️ ChartObjectSettingsWindow: Object deleted");
        }
    }];
}

#pragma mark - Private Helpers

- (void)applyWorkingStyleToObject {
    // Apply working style temporarily for preview
    self.targetObject.style = [self.workingStyle copy];
    [self requestChartRefresh];
}

- (void)requestChartRefresh {
    // Request chart refresh through the objects manager
    // This would typically trigger a redraw of the chart
    if (self.objectsManager) {
        // The manager could have a delegate or notification system
        // For now we just log the request
        NSLog(@"🔄 Requesting chart refresh for style preview");
    }
}

@end
