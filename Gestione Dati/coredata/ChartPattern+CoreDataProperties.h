//
//  ChartPattern+CoreDataProperties.h
//  mafia_AI
//
//  Created by fabio gattone on 22/08/25.
//
//

#import "ChartPattern+CoreDataClass.h"


NS_ASSUME_NONNULL_BEGIN

@interface ChartPattern (CoreDataProperties)

+ (NSFetchRequest<ChartPattern *> *)fetchRequest NS_SWIFT_NAME(fetchRequest());

@property (nullable, nonatomic, copy) NSString *additionalNotes;
@property (nullable, nonatomic, copy) NSDate *creationDate;
@property (nullable, nonatomic, copy) NSString *patternID;
@property (nullable, nonatomic, copy) NSDate *patternStartDate;
@property (nullable, nonatomic, copy) NSDate *patternEndDate;
@property (nullable, nonatomic, copy) NSString *patternType;
@property (nullable, nonatomic, copy) NSString *savedDataReference;

@end

NS_ASSUME_NONNULL_END
