//
//  ChartAnnotationProvider.h
//  mafia_AI
//
//  Protocol for annotation data providers
//  Each annotation type (news, notes, messages) has its own provider
//

#import <Foundation/Foundation.h>
#import "ChartAnnotation.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * Protocol that all annotation providers must implement
 * Providers fetch annotations from their respective data sources
 */
@protocol ChartAnnotationProvider <NSObject>

@required

/**
 * Fetch annotations for a symbol within a date range
 *
 * @param symbol Stock symbol to fetch annotations for
 * @param startDate Start of date range
 * @param endDate End of date range
 * @param completion Called with array of ChartAnnotation objects
 */
- (void)getAnnotationsForSymbol:(NSString *)symbol
                      startDate:(NSDate *)startDate
                        endDate:(NSDate *)endDate
                     completion:(void(^)(NSArray<ChartAnnotation *> *annotations, NSError * _Nullable error))completion;

/**
 * The type of annotations this provider supplies
 */
- (ChartAnnotationType)annotationType;

@optional

/**
 * Friendly name for this provider (for debugging)
 */
- (NSString *)providerName;

/**
 * Whether this provider is currently enabled
 */
- (BOOL)isEnabled;

@end

NS_ASSUME_NONNULL_END
