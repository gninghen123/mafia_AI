//
// TechnicalIndicatorBase+Hierarchy.h
// TradingApp
//
// Extension for parent-child hierarchy support in technical indicators
//

#import "TechnicalIndicatorBase.h"

NS_ASSUME_NONNULL_BEGIN

@interface TechnicalIndicatorBase (Hierarchy)

#pragma mark - Hierarchy Properties
@property (nonatomic, weak, nullable) TechnicalIndicatorBase *parentIndicator;
@property (nonatomic, strong) NSMutableArray<TechnicalIndicatorBase *> *childIndicators;
@property (nonatomic, strong) NSString *indicatorID;  // Unique identifier
@property (nonatomic, strong, nullable) NSColor *displayColor;
@property (nonatomic, assign) CGFloat lineWidth;
@property (nonatomic, assign) BOOL isVisible;

#pragma mark - Rendering State
@property (nonatomic, assign) BOOL needsRendering;  // ✅ AGGIUNTO: Flag per re-rendering

#pragma mark - Hierarchy Management

/// Add a child indicator
/// @param childIndicator Child indicator to add
- (void)addChildIndicator:(TechnicalIndicatorBase *)childIndicator;

/// Remove a child indicator
/// @param childIndicator Child indicator to remove
- (void)removeChildIndicator:(TechnicalIndicatorBase *)childIndicator;

/// Remove this indicator from its parent
- (void)removeFromParent;

/// Get all descendants recursively
/// @return Array of all child and grandchild indicators
- (NSArray<TechnicalIndicatorBase *> *)getAllDescendants;

#pragma mark - Hierarchy Navigation

/// Check if this is a root indicator (no parent)
/// @return YES if this is a root indicator
- (BOOL)isRootIndicator;

/// Get the inheritance level (0=root, 1=child, 2=grandchild, etc.)
/// @return Inheritance depth level
- (NSInteger)getInheritanceLevel;

/// Navigate to root indicator
/// @return The root indicator in the hierarchy
- (TechnicalIndicatorBase *)getRootIndicator;

/// Get path from root to this indicator
/// @return Array of indicators from root to self
- (NSArray<TechnicalIndicatorBase *> *)getIndicatorPath;

#pragma mark - Data Flow

/// Calculate with historical bar data (ROOT indicators only)
/// @param bars Historical bar data from ChartWidget
- (void)calculateWithBars:(NSArray<HistoricalBarModel *> *)bars;

/// Calculate with parent series data (CHILD indicators only)
/// @param parentValues Output series from parent indicator
- (void)calculateWithParentSeries:(NSArray<NSNumber *> *)parentValues;

/// Get output series for children to consume
/// @return Array of calculated values for child indicators
- (NSArray<NSNumber *> *)getOutputSeries;

/// Trigger calculation cascade for entire subtree
/// @param inputData Historical bars for root, or parent series for children
- (void)calculateIndicatorTree:(id)inputData;

#pragma mark - Capability Queries

/// Check if this indicator type can have children
/// @return YES if children are supported
- (BOOL)canHaveChildren;

/// Check if this indicator can be a child of specified parent type
/// @param parentType Parent indicator class name
/// @return YES if compatible as child
- (BOOL)canBeChildOfType:(NSString *)parentType;

/// Get list of supported child indicator types
/// @return Array of class names that can be children
- (NSArray<NSString *> *)getSupportedChildTypes;

/// Check if indicator has visual output (should be rendered)
/// @return YES if should be drawn on chart
- (BOOL)hasVisualOutput;

#pragma mark - Display and UI

/// Get display name for UI
/// @return User-friendly indicator name with parameters
- (NSString *)displayName;

/// Get short display name for compact UI
/// @return Abbreviated indicator name
- (NSString *)shortDisplayName;

/// Get icon name for UI representation
/// @return Icon identifier for this indicator type
- (NSString *)iconName;

/// Get default display color for this indicator
/// @return Default color for rendering
- (NSColor *)defaultDisplayColor;

- (NSColor *)getColorBasedOnIndicatorType;
#pragma mark - Serialization Support

/// Serialize indicator configuration to dictionary
/// @return Dictionary containing all necessary data for reconstruction
- (NSDictionary<NSString *, id> *)serializeToDictionary;

/// Create indicator from serialized dictionary
/// @param dictionary Previously serialized indicator data
/// @return Reconstructed indicator instance
+ (instancetype _Nullable)deserializeFromDictionary:(NSDictionary<NSString *, id> *)dictionary;

/// Serialize entire indicator subtree
/// @return Dictionary containing this indicator and all children
- (NSDictionary<NSString *, id> *)serializeSubtreeToDictionary;

/// Deserialize indicator subtree
/// @param dictionary Serialized subtree data
/// @return Root indicator with all children reconstructed
+ (instancetype _Nullable)deserializeSubtreeFromDictionary:(NSDictionary<NSString *, id> *)dictionary;

#pragma mark - Validation

/// Validate indicator configuration
/// @param error Error pointer for validation failures
/// @return YES if configuration is valid
- (BOOL)validateConfiguration:(NSError **)error;

/// Validate parent-child relationship
/// @param proposedParent Proposed parent indicator
/// @param error Error pointer for validation failures
/// @return YES if relationship is valid
- (BOOL)validateParentRelationship:(TechnicalIndicatorBase *)proposedParent error:(NSError **)error;

#pragma mark - Cleanup

/// Clean up resources and break retain cycles
- (void)cleanup;

@end

NS_ASSUME_NONNULL_END
