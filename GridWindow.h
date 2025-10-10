//
//  GridWindow.h
//  TradingApp
//
//  Grid window with dynamic matrix layout and resizable splits
//

#import <Cocoa/Cocoa.h>
#import "GridTemplate.h"

@class BaseWidget;
@class AppDelegate;

NS_ASSUME_NONNULL_BEGIN

@interface GridWindow : NSWindow <NSWindowDelegate, NSSplitViewDelegate>

#pragma mark - Properties

// Grid data
@property (nonatomic, strong) NSMutableArray<BaseWidget *> *widgets;
@property (nonatomic, strong) NSMutableDictionary<NSString *, BaseWidget *> *widgetPositions; // Key: "rc" (e.g., "11", "23")
@property (nonatomic, strong) GridTemplate *currentTemplate;
@property (nonatomic, strong) NSString *gridName;
@property (nonatomic, weak) AppDelegate *appDelegate;

// Grid dimensions
@property (nonatomic, assign, readonly) NSInteger rows;
@property (nonatomic, assign, readonly) NSInteger cols;

// UI Controls
@property (nonatomic, strong) NSStepper *rowsStepper;
@property (nonatomic, strong) NSStepper *colsStepper;
@property (nonatomic, strong) NSTextField *rowsLabel;
@property (nonatomic, strong) NSTextField *colsLabel;
@property (nonatomic, strong) NSButton *addWidgetButton;
@property (nonatomic, strong) NSButton *settingsButton;

// Layout structure
@property (nonatomic, strong) NSSplitView *mainSplitView;              // Vertical for rows
@property (nonatomic, strong) NSMutableArray<NSSplitView *> *rowSplitViews; // Horizontal splits for each row

#pragma mark - Initialization

/**
 * Initializes a grid window with a template
 * @param template GridTemplate defining initial layout
 * @param name Display name for the grid
 * @param appDelegate Reference to app delegate
 */
- (instancetype)initWithTemplate:(GridTemplate *)template
                            name:(nullable NSString *)name
                     appDelegate:(AppDelegate *)appDelegate;

#pragma mark - Widget Management

/**
 * Adds a widget at a specific matrix position
 * @param widget Widget to add
 * @param matrixCode Position code "rc" (e.g., "11" = row 1, col 1)
 */
- (void)addWidget:(BaseWidget *)widget atMatrixCode:(NSString *)matrixCode;

/**
 * Removes a widget from the grid
 */
- (void)removeWidget:(BaseWidget *)widget;

/**
 * Detaches a widget for moving to a floating window
 * @return The detached widget
 */
- (BaseWidget *)detachWidget:(BaseWidget *)widget;

/**
 * Transforms a widget to a different type
 */
- (void)transformWidget:(BaseWidget *)oldWidget toType:(NSString *)newType;

#pragma mark - Layout Management

/**
 * Rebuilds the entire grid layout with new dimensions
 * Called when rows/cols change via steppers
 */
- (void)rebuildGridLayout;

/**
 * Updates grid dimensions and rebuilds layout
 * @param newRows New number of rows (1-3)
 * @param newCols New number of columns (1-3)
 */
- (void)updateGridDimensions:(NSInteger)newRows cols:(NSInteger)newCols;

/**
 * Captures current split view proportions and saves to template
 */
- (void)captureCurrentProportions;

/**
 * Applies proportions from template to split views
 */
- (void)applyProportionsFromTemplate;

#pragma mark - Serialization

/**
 * Serializes the grid state including widgets and proportions
 */
- (NSDictionary *)serializeState;

/**
 * Restores grid state from serialized data
 */
- (void)restoreState:(NSDictionary *)state;

- (void)applyRowProportions;
- (void)applyColumnProportions;

@end

NS_ASSUME_NONNULL_END
