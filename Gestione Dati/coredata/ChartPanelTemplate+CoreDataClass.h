//
// ChartPanelTemplate+CoreDataClass.h
// TradingApp
//
// CoreData model for chart panel templates
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class ChartTemplate;
@class TechnicalIndicatorBase;

NS_ASSUME_NONNULL_BEGIN

@interface ChartPanelTemplate : NSManagedObject

// Runtime Properties (not persisted - reconstructed from serialized data)
@property (nonatomic, strong) TechnicalIndicatorBase *rootIndicator;

// Convenience Methods
+ (instancetype)createWithRootIndicatorType:(NSString *)rootType
                                 parameters:(NSDictionary *)params
                                    context:(NSManagedObjectContext *)context;

- (void)serializeRootIndicator:(TechnicalIndicatorBase *)rootIndicator;
- (TechnicalIndicatorBase *)deserializeRootIndicator;
- (void)serializeChildIndicators:(NSArray<TechnicalIndicatorBase *> *)childIndicators;
- (NSArray<TechnicalIndicatorBase *> *)deserializeChildIndicators;

// ✅ AGGIUNTO: Working copy methods
- (ChartPanelTemplate *)createWorkingCopy;
- (void)updateFromWorkingCopy:(ChartPanelTemplate *)workingCopy;

// Display helpers
- (NSString *)displayName;
- (NSString *)rootIndicatorDisplayName;

@end

NS_ASSUME_NONNULL_END

// ✅ SPOSTATO FUORI dal blocco NS_ASSUME_NONNULL
#import "ChartPanelTemplate+CoreDataProperties.h"
