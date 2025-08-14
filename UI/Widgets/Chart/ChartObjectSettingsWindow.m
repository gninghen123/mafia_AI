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
        
        // ✅ VALIDATION: Check oggetto e style
        if (!object || !object.style) {
            NSLog(@"❌ ChartObjectSettingsWindow: Invalid object or style");
            return nil;
        }
        
        // Create working copy of style
        _originalStyle = [object.style copy];
        _workingStyle = [object.style copy];
        
        // ✅ VALIDATION: Check copy successo
        if (!_originalStyle || !_workingStyle) {
            NSLog(@"❌ ChartObjectSettingsWindow: Failed to copy style");
            return nil;
        }
        
        [self setupWindow];
        
        @try {
            [self setupUI];
            
            // ✅ SAFE: Chiama refreshUI solo se tutti i controlli esistono
            if (self.objectNameLabel && self.colorWell && self.thicknessSlider) {
                [self refreshUI];
            } else {
                NSLog(@"⚠️ ChartObjectSettingsWindow: UI controls not ready, skipping refreshUI");
            }
            
        } @catch (NSException *exception) {
            NSLog(@"❌ ChartObjectSettingsWindow: Exception during initialization: %@", exception.reason);
            return nil;
        }
        
        NSLog(@"✅ ChartObjectSettingsWindow: Initialized successfully for object '%@'", object.name);
    }
    
    return self;
}


- (void)refreshUI {
    if (!self.targetObject || !self.workingStyle) {
        NSLog(@"⚠️ ChartObjectSettingsWindow: refreshUI called with nil objects");
        return;
    }
    
    @try {
        // ✅ SAFE: Controlla ogni controllo prima di usarlo
        
        // Update header
        if (self.objectNameLabel) {
            self.objectNameLabel.stringValue = self.targetObject.name ?: @"Unknown Object";
        }
        
        if (self.objectTypeLabel) {
            self.objectTypeLabel.stringValue = [self stringForObjectType:self.targetObject.type];
        }
        
        // Update style controls
        if (self.colorWell) {
            self.colorWell.color = self.workingStyle.color ?: [NSColor systemBlueColor];
        }
        
        if (self.thicknessSlider) {
            self.thicknessSlider.doubleValue = self.workingStyle.thickness;
        }
        
        if (self.thicknessLabel) {
            self.thicknessLabel.stringValue = [NSString stringWithFormat:@"%.1f", self.workingStyle.thickness];
        }
        
        if (self.lineTypePopup) {
            // Safe select - check bounds
            NSInteger lineType = self.workingStyle.lineType;
            if (lineType >= 0 && lineType < self.lineTypePopup.numberOfItems) {
                [self.lineTypePopup selectItemAtIndex:lineType];
            }
        }
        
        if (self.opacitySlider) {
            self.opacitySlider.doubleValue = self.workingStyle.opacity;
        }
        
        if (self.opacityLabel) {
            self.opacityLabel.stringValue = [NSString stringWithFormat:@"%.1f", self.workingStyle.opacity];
        }
        
        // Update state controls
        if (self.visibilityCheckbox) {
            self.visibilityCheckbox.state = self.targetObject.isVisible ? NSControlStateValueOn : NSControlStateValueOff;
        }
        
        if (self.lockCheckbox) {
            self.lockCheckbox.state = self.targetObject.isLocked ? NSControlStateValueOn : NSControlStateValueOff;
        }
        
        NSLog(@"✅ ChartObjectSettingsWindow: refreshUI completed successfully");
        
    } @catch (NSException *exception) {
        NSLog(@"❌ ChartObjectSettingsWindow: Exception in refreshUI: %@", exception.reason);
    }
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
    @try {
        // Main content container
        self.contentContainer = [[NSView alloc] init];
        self.contentContainer.translatesAutoresizingMaskIntoConstraints = NO;
        [self.contentView addSubview:self.contentContainer];
        
        // Create sections in try-catch
        [self createHeaderSection];
        [self createStyleSection];
        [self createVisibilitySection];
        [self createActionButtons];
        [self setupConstraints];
        
        NSLog(@"✅ ChartObjectSettingsWindow: UI setup completed");
        
    } @catch (NSException *exception) {
        NSLog(@"❌ ChartObjectSettingsWindow: Exception in setupUI: %@", exception.reason);
        @throw exception; // Re-throw per permettere al constructor di gestirlo
    }
}



- (void)createHeaderSection {
    @try {
        // Object name label
        self.objectNameLabel = [[NSTextField alloc] init];
        self.objectNameLabel.translatesAutoresizingMaskIntoConstraints = NO;
        self.objectNameLabel.editable = NO;
        self.objectNameLabel.bordered = NO;
        self.objectNameLabel.backgroundColor = [NSColor clearColor];
        self.objectNameLabel.font = [NSFont boldSystemFontOfSize:16];
        self.objectNameLabel.stringValue = @"Object Name";
        [self.contentContainer addSubview:self.objectNameLabel];
        
        // Object type label
        self.objectTypeLabel = [[NSTextField alloc] init];
        self.objectTypeLabel.translatesAutoresizingMaskIntoConstraints = NO;
        self.objectTypeLabel.editable = NO;
        self.objectTypeLabel.bordered = NO;
        self.objectTypeLabel.backgroundColor = [NSColor clearColor];
        self.objectTypeLabel.font = [NSFont systemFontOfSize:12];
        self.objectTypeLabel.textColor = [NSColor secondaryLabelColor];
        self.objectTypeLabel.stringValue = @"Object Type";
        [self.contentContainer addSubview:self.objectTypeLabel];
        
        NSLog(@"✅ Header section created");
        
    } @catch (NSException *exception) {
        NSLog(@"❌ Exception in createHeaderSection: %@", exception.reason);
        @throw exception;
    }
}

- (void)createStyleSection {
    @try {
        // Color well
        self.colorWell = [[NSColorWell alloc] init];
        self.colorWell.translatesAutoresizingMaskIntoConstraints = NO;
        self.colorWell.target = self;
        self.colorWell.action = @selector(colorChanged:);
        [self.contentContainer addSubview:self.colorWell];
        
        // Thickness slider
        self.thicknessSlider = [[NSSlider alloc] init];
        self.thicknessSlider.translatesAutoresizingMaskIntoConstraints = NO;
        self.thicknessSlider.minValue = 0.5;
        self.thicknessSlider.maxValue = 10.0;
        self.thicknessSlider.doubleValue = 2.0;
        self.thicknessSlider.target = self;
        self.thicknessSlider.action = @selector(thicknessChanged:);
        [self.contentContainer addSubview:self.thicknessSlider];
        
        // Thickness label
        self.thicknessLabel = [[NSTextField alloc] init];
        self.thicknessLabel.translatesAutoresizingMaskIntoConstraints = NO;
        self.thicknessLabel.editable = NO;
        self.thicknessLabel.bordered = NO;
        self.thicknessLabel.backgroundColor = [NSColor clearColor];
        self.thicknessLabel.stringValue = @"2.0";
        [self.contentContainer addSubview:self.thicknessLabel];
        
        NSLog(@"✅ Style section created");
        
    } @catch (NSException *exception) {
        NSLog(@"❌ Exception in createStyleSection: %@", exception.reason);
        @throw exception;
    }
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
    @try {
        if (!object || !object.style) {
            NSLog(@"❌ ChartObjectSettingsWindow: Invalid object or object.style is nil");
            return;
        }
        
        self.targetObject = object;
        self.originalStyle = [object.style copy];
        self.workingStyle = [object.style copy];
        
        if (!self.originalStyle || !self.workingStyle) {
            NSLog(@"❌ ChartObjectSettingsWindow: Failed to copy object style");
            return;
        }
        
        [self refreshUI];
        [self makeKeyAndOrderFront:nil];
        
        NSLog(@"🔧 ChartObjectSettingsWindow: Showing settings for object '%@'", object.name);
        
    } @catch (NSException *exception) {
        NSLog(@"❌ ChartObjectSettingsWindow: Exception in showSettingsForObject: %@", exception.reason);
    }
}


- (NSString *)stringForObjectType:(ChartObjectType)type {
    switch (type) {
        case ChartObjectTypeTrendline: return @"Trendline";
        case ChartObjectTypeFibonacci: return @"Fibonacci";
        case ChartObjectTypeTarget: return @"Target Price";
        case ChartObjectTypeChannel: return @"Channel";
        case ChartObjectTypeRectangle: return @"Rectangle";
        case ChartObjectTypeCircle: return @"Circle";
        case ChartObjectTypeTrailingFibo: return @"Trailing Fibonacci";
        case ChartObjectTypeTrailingFiboBetween: return @"Trailing Fibonacci Between";
        default: return @"Unknown Object";
    }
}

#pragma mark - Actions

- (IBAction)colorChanged:(id)sender {
    @try {
        if (self.workingStyle && [sender isKindOfClass:[NSColorWell class]]) {
            self.workingStyle.color = [(NSColorWell *)sender color];
            [self applyWorkingStyleToObject];
        }
    } @catch (NSException *exception) {
        NSLog(@"❌ ChartObjectSettingsWindow: Exception in colorChanged: %@", exception.reason);
    }
}


- (IBAction)thicknessChanged:(id)sender {
    @try {
        if (self.workingStyle && [sender isKindOfClass:[NSSlider class]]) {
            self.workingStyle.thickness = [(NSSlider *)sender doubleValue];
            self.thicknessLabel.stringValue = [NSString stringWithFormat:@"%.1f", self.workingStyle.thickness];
            [self applyWorkingStyleToObject];
        }
    } @catch (NSException *exception) {
        NSLog(@"❌ ChartObjectSettingsWindow: Exception in thicknessChanged: %@", exception.reason);
    }
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

    @try {
        if (!self.targetObject || !self.workingStyle) {
            NSLog(@"❌ ChartObjectSettingsWindow: Invalid state");
            [self close];
            return;
        }
        
        // Apply the working style permanently
        self.targetObject.style = [self.workingStyle copy];
        self.targetObject.lastModified = [NSDate date];
        
        // Find and update layer timestamp
        if (self.objectsManager) {
            for (ChartLayerModel *layer in self.objectsManager.layers) {
                if ([layer.objects containsObject:self.targetObject]) {
                    layer.lastModified = [NSDate date];
                    break;
                }
            }
            
            // ❌ RIMOSSO: [self.objectsManager saveToDataHub]; - Non salvare qui!
            NSLog(@"💫 ChartObjectSettingsWindow: Applied style (will save on window close)");
        }
        
        // Trigger redraw callback
        if (self.onApplyCallback) {
            void (^callback)(ChartObjectModel *) = self.onApplyCallback;
            self.onApplyCallback = nil;
            
            dispatch_async(dispatch_get_main_queue(), ^{
                callback(self.targetObject);
            });
        }
        
        // Close window
        [self close];
        
    } @catch (NSException *exception) {
        NSLog(@"❌ ChartObjectSettingsWindow: Exception in apply: %@", exception);
    }
}


- (void)windowWillClose:(NSNotification *)notification {
    // ✅ SALVA solo quando chiudi la finestra (modifica completata)
    if (self.objectsManager) {
        [self.objectsManager saveToDataHub];
        NSLog(@"💾 ChartObjectSettingsWindow: Saved on window close");
    }
    
    // Cleanup
    self.targetObject = nil;
    self.workingStyle = nil;
    self.objectsManager = nil;
    self.onApplyCallback = nil;
}


- (IBAction)cancelButtonClicked:(id)sender {
    NSLog(@"❌ ChartObjectSettingsWindow: Cancelling changes");
    
    @try {
        // ✅ SAFE RESTORE: Check objects exist
        if (self.targetObject && self.originalStyle) {
            self.targetObject.style = [self.originalStyle copy];
            NSLog(@"🔄 ChartObjectSettingsWindow: Restored original style");
        }
        
        // Clear callback to avoid retain cycle
        self.onApplyCallback = nil;
        
    } @catch (NSException *exception) {
        NSLog(@"❌ ChartObjectSettingsWindow: Exception in cancelButtonClicked: %@", exception.reason);
    } @finally {
        // Always close window
        [self safeClose];
    }
}

- (IBAction)deleteButtonClicked:(id)sender {
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"Delete Object";
    alert.informativeText = [NSString stringWithFormat:@"Are you sure you want to delete '%@'?",
                            self.targetObject.name ?: @"this object"];
    [alert addButtonWithTitle:@"Delete"];
    [alert addButtonWithTitle:@"Cancel"];
    alert.alertStyle = NSAlertStyleWarning;
    
    // ✅ SAFE SHEET: Use weak reference
    __weak typeof(self) weakSelf = self;
    [alert beginSheetModalForWindow:self completionHandler:^(NSModalResponse returnCode) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        
        if (returnCode == NSAlertFirstButtonReturn) {
            @try {
                if (strongSelf.objectsManager && strongSelf.targetObject) {
                    [strongSelf.objectsManager deleteObject:strongSelf.targetObject];
                    NSLog(@"🗑️ ChartObjectSettingsWindow: Object deleted");
                }
            } @catch (NSException *exception) {
                NSLog(@"❌ ChartObjectSettingsWindow: Exception in delete: %@", exception.reason);
            }
        }
        
        [strongSelf safeClose];
    }];
}


#pragma mark - Private Helpers

- (void)applyWorkingStyleToObject {
    @try {
        if (self.targetObject && self.workingStyle) {
            // Apply working style temporarily for preview
            self.targetObject.style = [self.workingStyle copy];
            [self requestChartRefresh];
        }
    } @catch (NSException *exception) {
        NSLog(@"❌ ChartObjectSettingsWindow: Exception in applyWorkingStyleToObject: %@", exception.reason);
    }
}

- (void)requestChartRefresh {
    // Safe chart refresh request
    if (self.objectsManager) {
        NSLog(@"🔄 Requesting chart refresh for style preview");
        
        // Use notification instead of direct calls to avoid crashes
        [[NSNotificationCenter defaultCenter] postNotificationName:@"ChartObjectStylePreview"
                                                            object:nil
                                                          userInfo:@{
            @"objectId": self.targetObject.objectID ?: @"unknown"
                                                          }];
    }
}


#pragma mark - Safe Window Management

- (void)safeClose {
    NSLog(@"🚪 SAFE CLOSE START - Object: %@ (pointer: %p)",
              self.targetObject ? self.targetObject.name : @"(already nil)",
              self.targetObject);
        

    // Clear all references before closing
    self.onApplyCallback = nil;
    self.originalStyle = nil;
    self.workingStyle = nil;
    self.objectsManager = nil;
    self.targetObject = nil;

    // Close window safely
    dispatch_async(dispatch_get_main_queue(), ^{
        [self close];
    });
    
    NSLog(@"🪟 ChartObjectSettingsWindow: Safely closed and cleaned up");
}

- (void)dealloc {
    NSLog(@"🗑️ DEALLOC START - Object: %@ (pointer: %p)",
             self.targetObject ? self.targetObject.name : @"(already nil)",
             self.targetObject);

    // Assicurati che sia tutto pulito
    self.targetObject = nil;
    self.objectsManager = nil;
    self.onApplyCallback = nil;
}


@end
