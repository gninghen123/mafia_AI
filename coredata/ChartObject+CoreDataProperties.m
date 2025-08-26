//
//  ChartObject+CoreDataProperties.m
//  mafia_AI
//
//  Created by fabio gattone on 14/08/25.
//
//

#import "ChartObject+CoreDataProperties.h"

@implementation ChartObject (CoreDataProperties)

+ (NSFetchRequest<ChartObject *> *)fetchRequest {
	return [NSFetchRequest fetchRequestWithEntityName:@"ChartObject"];
}

@dynamic controlPointsData;
@dynamic creationDate;
@dynamic customProperties;
@dynamic isLocked;
@dynamic isVisible;
@dynamic lastModified;
@dynamic name;
@dynamic objectUUID;
@dynamic styleData;
@dynamic type;
@dynamic layer;

@end
