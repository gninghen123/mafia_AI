//
//  HistoricalBar+CoreDataClass.h
//  mafia_AI
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

NS_ASSUME_NONNULL_BEGIN

@interface HistoricalBar : NSManagedObject

// Metodi helper personalizzati
- (double)typicalPrice;
- (double)range;

@end

NS_ASSUME_NONNULL_END

#import "HistoricalBar+CoreDataProperties.h"
