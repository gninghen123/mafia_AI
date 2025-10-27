//
//  ObjectsPanel.h
//  TradingApp
//
//  Side panel for chart objects creation tools
//

#import <Cocoa/Cocoa.h>
#import "ChartObjectModels.h"

NS_ASSUME_NONNULL_BEGIN

@protocol ObjectsPanelDelegate <NSObject>

@required
/// Called when user requests to create a new chart object
/// @param panel The objects panel instance
/// @param type The type of object to create
- (void)objectsPanel:(id)panel didRequestCreateObjectOfType:(ChartObjectType)type;

/// Called when user requests to show the object manager
/// @param panel The objects panel instance
- (void)objectsPanelDidRequestShowManager:(id)panel;

- (void)objectsPanel:(id)panel didRequestCreateObjectOfType:(ChartObjectType)type;
- (void)objectsPanelDidRequestShowManager:(id)panel;

// NEW: State-based methods
- (void)objectsPanel:(id)panel didActivateObjectType:(ChartObjectType)type withLockMode:(BOOL)lockEnabled;
- (void)objectsPanel:(id)panel didDeactivateObjectType:(ChartObjectType)type;

- (void)objectsPanelDidRequestClearAll:(id)panel;

@optional
/// Called when panel visibility changes
/// @param panel The objects panel instance
/// @param isVisible Whether the panel is now visible
- (void)objectsPanel:(id)panel didChangeVisibility:(BOOL)isVisible;
// AGGIUNGI QUESTI METODI AL PROTOCOLLO (ancora in @optional)

/// Called when annotation type checkbox is toggled
/// @param panel The objects panel instance
/// @param type Annotation type (ChartAnnotationType enum value)
/// @param enabled Whether the annotation type is now enabled
- (void)objectsPanel:(id)panel
didChangeAnnotationType:(NSInteger)type
              enabled:(BOOL)enabled;

/// Called when minimum relevance score slider changes
/// @param panel The objects panel instance
/// @param score The new minimum relevance score (0-100)
- (void)objectsPanel:(id)panel
didChangeMinimumRelevanceScore:(double)score;

/// Called when user taps "Add Note" button
/// @param panel The objects panel instance
- (void)objectsPanelDidRequestAddNote:(id)panel;
@end


@class ChartObjectManagerWindow;

@interface ObjectsPanel : NSView

@property (nonatomic, strong) ChartObjectManagerWindow *objectManagerWindow;

@property (nonatomic, assign) BOOL isLockModeEnabled;
@property (nonatomic, strong) NSButton *currentActiveButton;
@property (nonatomic, assign) ChartObjectType currentActiveObjectType;

// NEW: Lock toggle
@property (nonatomic, strong) NSButton *lockCreationToggle;

// NEW: Snap controls
@property (nonatomic, strong) NSSlider *snapIntensitySlider;
@property (nonatomic, strong) NSTextField *snapIconLabel;
@property (nonatomic, strong) NSTextField *snapValueLabel;

#pragma mark - Configuration
@property (nonatomic, weak, nullable) id<ObjectsPanelDelegate> delegate;
@property (nonatomic, assign) CGFloat panelWidth;

#pragma mark - UI Components
@property (nonatomic, strong, readonly) NSStackView *buttonsStackView;
@property (nonatomic, strong, readonly) NSButton *objectManagerButton;
@property (nonatomic, strong, readonly) NSArray<NSButton *> *objectButtons;
@property (nonatomic, strong, readonly) NSVisualEffectView *backgroundView;

#pragma mark - Animation
@property (nonatomic, strong) NSLayoutConstraint *widthConstraint;

#pragma mark - Annotation Controls (NEW)
@property (nonatomic, strong) NSView *annotationRelevanceRow;
@property (nonatomic, strong) NSButton *showNewsCheckbox;
@property (nonatomic, strong) NSButton *showNotesCheckbox;
@property (nonatomic, strong) NSButton *showMessagesCheckbox;
@property (nonatomic, strong) NSButton *showAlertsCheckbox;
@property (nonatomic, strong) NSButton *showEventsCheckbox;

@property (nonatomic, strong) NSSlider *annotationRelevanceSlider;
@property (nonatomic, strong) NSTextField *annotationRelevanceLabel;
@property (nonatomic, strong) NSButton *addNoteButton;

@property (nonatomic, strong) NSBox *annotationsSeparator;
@property (nonatomic, strong) NSTextField *annotationsTitle;


#pragma mark - Public Methods
- (ChartObjectType)getActiveObjectType;
- (void)clearActiveButton;
- (void)objectCreationCompleted;
/// Toggle panel visibility with animation
/// @param animated Whether to animate the transition
- (void)toggleVisibilityAnimated:(BOOL)animated;

/// Show panel with animation
/// @param animated Whether to animate the transition
- (void)showAnimated:(BOOL)animated;

/// Hide panel with animation
/// @param animated Whether to animate the transition
- (void)hideAnimated:(BOOL)animated;

/// Update button states (e.g., highlight active tool)
/// @param activeType The currently active object type, or -1 for none
- (void)updateButtonStatesWithActiveType:(ChartObjectType)activeType;
- (ChartObjectType)getActiveObjectType;
- (void)clearActiveButton;
- (void)setActiveButton:(NSButton *)button forType:(ChartObjectType)type;

- (IBAction)clearAllObjects:(id)sender;

- (void)updateManagerForSymbol:(NSString *)symbol;
- (void)refreshObjectManager;

// NEW: Snap methods
- (CGFloat)getSnapIntensity;
- (void)setSnapIntensity:(CGFloat)intensity;

@end

NS_ASSUME_NONNULL_END
