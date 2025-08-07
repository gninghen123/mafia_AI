// Alert+CoreDataClass.h
#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class Symbol;

NS_ASSUME_NONNULL_BEGIN

@interface Alert : NSManagedObject

// Convenience methods
- (NSString *)symbolName;
- (BOOL)shouldTriggerWithPrice:(double)currentPrice previousPrice:(double)previousPrice;
- (NSString *)formattedTriggerValue;
- (NSString *)conditionDescription;

@end

NS_ASSUME_NONNULL_END
