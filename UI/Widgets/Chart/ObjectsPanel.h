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

@optional
/// Called when panel visibility changes
/// @param panel The objects panel instance
/// @param isVisible Whether the panel is now visible
- (void)objectsPanel:(id)panel didChangeVisibility:(BOOL)isVisible;

@end

@interface ObjectsPanel : NSView

#pragma mark - Configuration
@property (nonatomic, weak, nullable) id<ObjectsPanelDelegate> delegate;
@property (nonatomic, assign) BOOL isVisible;
@property (nonatomic, assign) CGFloat panelWidth;

#pragma mark - UI Components
@property (nonatomic, strong, readonly) NSStackView *buttonsStackView;
@property (nonatomic, strong, readonly) NSButton *objectManagerButton;
@property (nonatomic, strong, readonly) NSArray<NSButton *> *objectButtons;
@property (nonatomic, strong, readonly) NSVisualEffectView *backgroundView;

#pragma mark - Animation
@property (nonatomic, strong) NSLayoutConstraint *widthConstraint;

#pragma mark - Public Methods

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

@end

NS_ASSUME_NONNULL_END
