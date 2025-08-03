//
//  IndicatorRenderer.h
//  TradingApp
//
//  Protocol for all chart indicators rendering
//

#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>
#import "ChartTypes.h"
#import "RuntimeModels.h"

@class ChartCoordinator;
@class IndicatorSettings;

NS_ASSUME_NONNULL_BEGIN

@protocol IndicatorRenderer <NSObject>

#pragma mark - Required Methods

/**
 * Unique identifier for this indicator type
 */
- (NSString *)indicatorType;

/**
 * Display name for UI
 */
- (NSString *)displayName;

/**
 * Category for grouping in UI
 */
- (IndicatorCategory)category;

/**
 * Whether this indicator needs its own panel or can overlay on existing panel
 */
- (BOOL)needsSeparatePanel;

/**
 * Main drawing method
 */
- (void)drawInRect:(NSRect)rect
          withData:(NSArray<HistoricalBarModel *> *)data
        coordinator:(ChartCoordinator *)coordinator;

#pragma mark - Optional Methods

@optional

/**
 * Value range for this indicator (for Y-axis calculation)
 * Return NSMakeRange(0, 0) to auto-calculate
 */
- (NSRange)valueRangeForData:(NSArray<HistoricalBarModel *> *)data;

/**
 * Primary color for this indicator (used in legends, etc.)
 */
- (NSColor *)primaryColor;

/**
 * Settings object for this indicator
 */
- (IndicatorSettings *)settings;

/**
 * Apply settings to this indicator
 */
- (void)applySettings:(IndicatorSettings *)settings;

/**
 * Create a settings view for editing this indicator
 */
- (NSView *)createSettingsView;

/**
 * Serialize current state for template saving
 */
- (NSDictionary *)serializeState;

/**
 * Restore state from template loading
 */
- (void)restoreState:(NSDictionary *)state;

/**
 * Calculate indicator values (for indicators that need preprocessing)
 */
- (NSArray *)calculateValuesForData:(NSArray<HistoricalBarModel *> *)data;

@end

NS_ASSUME_NONNULL_END
