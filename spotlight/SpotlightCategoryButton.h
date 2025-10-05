//
//  SpotlightCategoryButton.h
//  TradingApp
//
//  Category button with dropdown menu for Spotlight Search
//  Supports DataSource selection and Widget target selection
//

#import <Cocoa/Cocoa.h>
#import "commontypes.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, SpotlightCategoryType) {
    SpotlightCategoryTypeDataSource,
    SpotlightCategoryTypeWidgetTarget
};

typedef NS_ENUM(NSInteger, SpotlightWidgetTarget) {
    SpotlightWidgetTargetFloating,
    SpotlightWidgetTargetLeftPanel,
    SpotlightWidgetTargetRightPanel,
    SpotlightWidgetTargetCenterPanel
};

@class SpotlightCategoryButton;

@protocol SpotlightCategoryButtonDelegate <NSObject>
@optional
- (void)spotlightCategoryButton:(SpotlightCategoryButton *)button didSelectDataSource:(DataSourceType)dataSource;
- (void)spotlightCategoryButton:(SpotlightCategoryButton *)button didSelectWidgetTarget:(SpotlightWidgetTarget)target;
@end

@interface SpotlightCategoryButton : NSButton

#pragma mark - Properties

@property (nonatomic, assign) SpotlightCategoryType categoryType;
@property (nonatomic, weak) id<SpotlightCategoryButtonDelegate> delegate;
@property (nonatomic, assign) BOOL isActive;  // Visual state for active category

// Current selections
@property (nonatomic, assign) DataSourceType selectedDataSource;
@property (nonatomic, assign) SpotlightWidgetTarget selectedWidgetTarget;

#pragma mark - Initialization

/**
 * Initialize with category type
 * @param categoryType Type of category (DataSource or WidgetTarget)
 */
- (instancetype)initWithCategoryType:(SpotlightCategoryType)categoryType;

#pragma mark - Configuration

/**
 * Setup button appearance and default selections
 */
- (void)configureButton;

/**
 * Update button title based on current selection
 */
- (void)updateButtonTitle;

#pragma mark - Menu Actions

/**
 * Show dropdown menu when clicked
 */
- (void)showDropdownMenu;

/**
 * Select data source option
 * @param dataSource DataSource type to select
 */
- (void)selectDataSource:(DataSourceType)dataSource;

/**
 * Select widget target option
 * @param target Widget target to select
 */
- (void)selectWidgetTarget:(SpotlightWidgetTarget)target;

#pragma mark - State Management

/**
 * Set active state (highlighted)
 * @param active YES to highlight button
 */
- (void)setActiveState:(BOOL)active;

#pragma mark - Helper Methods

/**
 * Get display name for data source
 * @param dataSource DataSource type
 * @return Human readable name
 */
+ (NSString *)displayNameForDataSource:(DataSourceType)dataSource;

/**
 * Get display name for target type
 * @param target Target type
 * @return Human readable name
 */
+ (NSString *)displayNameForTargetType:(SpotlightCategoryType)target;


@end

NS_ASSUME_NONNULL_END
