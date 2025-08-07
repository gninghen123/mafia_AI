//
//  ChartLayer+CoreDataProperties.m
//  mafia_AI
//
//  Created by fabio gattone on 07/08/25.
//
//

#import "ChartLayer+CoreDataProperties.h"

@implementation ChartLayer (CoreDataProperties)

+ (NSFetchRequest<ChartLayer *> *)fetchRequest {
	return [NSFetchRequest fetchRequestWithEntityName:@"ChartLayer"];
}

@dynamic creationDate;
@dynamic isVisible;
@dynamic lastModified;
@dynamic layerID;
@dynamic name;
@dynamic orderIndex;
@dynamic objects;
@dynamic symbol;

@end
