//
//  ChartLayer+CoreDataProperties.h
//  mafia_AI
//
//  Created by fabio gattone on 07/08/25.
//
//

#import "ChartLayer+CoreDataClass.h"


NS_ASSUME_NONNULL_BEGIN

@interface ChartLayer (CoreDataProperties)

+ (NSFetchRequest<ChartLayer *> *)fetchRequest NS_SWIFT_NAME(fetchRequest());

@property (nullable, nonatomic, copy) NSDate *creationDate;
@property (nonatomic) BOOL isVisible;
@property (nullable, nonatomic, copy) NSDate *lastModified;
@property (nullable, nonatomic, copy) NSString *layerID;
@property (nullable, nonatomic, copy) NSString *name;
@property (nonatomic) int16_t orderIndex;
@property (nullable, nonatomic, retain) NSSet<ChartObject *> *objects;
@property (nullable, nonatomic, retain) Symbol *symbol;

@end

@interface ChartLayer (CoreDataGeneratedAccessors)

- (void)addObjectsObject:(ChartObject *)value;
- (void)removeObjectsObject:(ChartObject *)value;
- (void)addObjects:(NSSet<ChartObject *> *)values;
- (void)removeObjects:(NSSet<ChartObject *> *)values;

@end

NS_ASSUME_NONNULL_END
