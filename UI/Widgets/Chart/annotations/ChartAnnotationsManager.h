//
//  ChartAnnotationsManager.h
//  mafia_AI
//
//  Central manager for chart annotations
//  Handles data loading, filtering, and business logic
//

#import <Foundation/Foundation.h>
#import "ChartAnnotation.h"
#import "ChartAnnotationProvider.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * Manager for chart annotations
 * Handles data loading from providers, filtering, and caching
 *
 * Architecture:
 * ChartAnnotationsManager (this class - business logic)
 *     ↓ uses
 * ChartAnnotationProviders (data sources - NewsAnnotationProvider, etc.)
 */
@interface ChartAnnotationsManager : NSObject

#pragma mark - Configuration

/**
 * Array of annotation providers (NewsAnnotationProvider, NoteAnnotationProvider, etc.)
 */
@property (nonatomic, strong) NSArray<id<ChartAnnotationProvider>> *providers;

/**
 * Minimum relevance score for annotations to be displayed (0-100)
 */
@property (nonatomic, assign) double minimumRelevanceScore;

/**
 * Set of enabled annotation types (ChartAnnotationType enum values as NSNumber)
 */
@property (nonatomic, strong) NSMutableSet<NSNumber *> *enabledTypes;

#pragma mark - Data

/**
 * All loaded annotations (unfiltered)
 */
@property (nonatomic, strong, readonly) NSArray<ChartAnnotation *> *allAnnotations;

/**
 * Current symbol being displayed
 */
@property (nonatomic, strong, readonly) NSString *currentSymbol;

/**
 * Date range of loaded data
 */
@property (nonatomic, strong, readonly) NSDate *startDate;
@property (nonatomic, strong, readonly) NSDate *endDate;

#pragma mark - Initialization

/**
 * Initialize with providers
 */
- (instancetype)initWithProviders:(NSArray<id<ChartAnnotationProvider>> *)providers;

#pragma mark - Data Loading

/**
 * Load annotations for symbol and date range
 * @param symbol Stock symbol
 * @param startDate Start date for annotations
 * @param endDate End date for annotations
 * @param completion Completion handler with all loaded annotations (unfiltered)
 */
- (void)loadAnnotationsForSymbol:(NSString *)symbol
                       startDate:(NSDate *)startDate
                         endDate:(NSDate *)endDate
                      completion:(void(^)(NSArray<ChartAnnotation *> *annotations, NSError * _Nullable error))completion;

/**
 * Reload annotations for current symbol and date range
 */
- (void)reloadAnnotations:(void(^)(NSArray<ChartAnnotation *> *annotations, NSError * _Nullable error))completion;

#pragma mark - Filtering

/**
 * Get filtered annotations based on current settings
 * Filters by: enabled types + minimum relevance score
 * @return Array of annotations that pass all filters
 */
- (NSArray<ChartAnnotation *> *)filteredAnnotations;

/**
 * Enable or disable specific annotation type
 * @param type Annotation type to toggle
 * @param enabled YES to enable, NO to disable
 */
- (void)setAnnotationType:(ChartAnnotationType)type enabled:(BOOL)enabled;

/**
 * Check if annotation type is enabled
 */
- (BOOL)isAnnotationTypeEnabled:(ChartAnnotationType)type;

#pragma mark - Query

/**
 * Get annotations at specific date
 * @param date Date to query
 * @param tolerance Time tolerance in seconds (e.g., 86400 for 1 day)
 * @return Array of annotations within tolerance of date
 */
- (NSArray<ChartAnnotation *> *)annotationsNearDate:(NSDate *)date
                                          tolerance:(NSTimeInterval)tolerance;

/**
 * Get annotation with specific identifier
 */
- (nullable ChartAnnotation *)annotationWithIdentifier:(NSString *)identifier;

#pragma mark - Statistics

/**
 * Get statistics about loaded annotations
 * @return Dictionary with counts by type, average scores, etc.
 */
- (NSDictionary *)statistics;

@end

NS_ASSUME_NONNULL_END
