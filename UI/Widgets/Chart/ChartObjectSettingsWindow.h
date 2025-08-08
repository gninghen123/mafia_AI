//
//  ChartObjectSettingsWindow.h
//  TradingApp
//
//  Chart Object Settings Popup Window
//  Opzione C: OBJECT SETTINGS POPUP
//  ✅ Finestra per modificare colore, spessore, tipo linea degli oggetti
//  ✅ Double-click su oggetto → Apre settings
//

#import <AppKit/AppKit.h>
#import "ChartObjectModels.h"

NS_ASSUME_NONNULL_BEGIN

@class ChartObjectsManager;

@interface ChartObjectSettingsWindow : NSWindow


@property (nonatomic, copy, nullable) void (^onApplyCallback)(ChartObjectModel *object);

// Properties
@property (nonatomic, strong) ChartObjectModel *targetObject;
@property (nonatomic, weak) ChartObjectsManager *objectsManager;

// UI Components
@property (nonatomic, strong) NSTextField *objectNameLabel;
@property (nonatomic, strong) NSTextField *objectTypeLabel;

// Style controls
@property (nonatomic, strong) NSColorWell *colorWell;
@property (nonatomic, strong) NSSlider *thicknessSlider;
@property (nonatomic, strong) NSTextField *thicknessLabel;
@property (nonatomic, strong) NSPopUpButton *lineTypePopup;
@property (nonatomic, strong) NSSlider *opacitySlider;
@property (nonatomic, strong) NSTextField *opacityLabel;

// Visibility controls
@property (nonatomic, strong) NSButton *visibilityCheckbox;
@property (nonatomic, strong) NSButton *lockCheckbox;

// Action buttons
@property (nonatomic, strong) NSButton *applyButton;
@property (nonatomic, strong) NSButton *cancelButton;
@property (nonatomic, strong) NSButton *deleteButton;

// Initialization
- (instancetype)initWithObject:(ChartObjectModel *)object
                objectsManager:(ChartObjectsManager *)manager;

// Public methods
- (void)showSettingsForObject:(ChartObjectModel *)object;
- (void)refreshUI;

// Actions
- (IBAction)colorChanged:(id)sender;
- (IBAction)thicknessChanged:(id)sender;
- (IBAction)lineTypeChanged:(id)sender;
- (IBAction)opacityChanged:(id)sender;
- (IBAction)visibilityChanged:(id)sender;
- (IBAction)lockChanged:(id)sender;
- (IBAction)applyButtonClicked:(id)sender;
- (IBAction)cancelButtonClicked:(id)sender;
- (IBAction)deleteButtonClicked:(id)sender;

@end

NS_ASSUME_NONNULL_END
