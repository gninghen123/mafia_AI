//
// ChartTemplate+CoreDataClass.h
// TradingApp
//
// CoreData model for chart templates persistence
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class ChartPanelTemplate;

NS_ASSUME_NONNULL_BEGIN

@interface ChartTemplate : NSManagedObject

// Convenience Methods
+ (instancetype)createWithName:(NSString *)name context:(NSManagedObjectContext *)context;
- (ChartTemplate *)createWorkingCopy; // Non-managed copy for editing
- (void)updateFromWorkingCopy:(ChartTemplate *)workingCopy;
- (NSArray<ChartPanelTemplate *> *)orderedPanels;

@end

NS_ASSUME_NONNULL_END

// ✅ SPOSTATO FUORI dal blocco NS_ASSUME_NONNULL
#import "ChartTemplate+CoreDataProperties.h"
