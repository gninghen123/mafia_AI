//
//  ChartObject+CoreDataProperties.h
//  mafia_AI
//
//  Created by fabio gattone on 07/08/25.
//
//

#import "ChartObject+CoreDataClass.h"


NS_ASSUME_NONNULL_BEGIN

@interface ChartObject (CoreDataProperties)

+ (NSFetchRequest<ChartObject *> *)fetchRequest NS_SWIFT_NAME(fetchRequest());

@property (nullable, nonatomic, retain) NSArray *controlPointsData;
@property (nullable, nonatomic, copy) NSDate *creationDate;
@property (nullable, nonatomic, retain) NSDictionary *customProperties;
@property (nonatomic) BOOL isLocked;
@property (nonatomic) BOOL isVisible;
@property (nullable, nonatomic, copy) NSDate *lastModified;
@property (nullable, nonatomic, copy) NSString *name;
@property (nullable, nonatomic, copy) NSString *objectID;
@property (nullable, nonatomic, retain) NSDictionary *styleData;
@property (nonatomic) int16_t type;
@property (nullable, nonatomic, retain) ChartLayer *layer;

@end

NS_ASSUME_NONNULL_END
