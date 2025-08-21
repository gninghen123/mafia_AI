//
//  ChartPattern+CoreDataProperties.m
//  mafia_AI
//
//  Created by fabio gattone on 21/08/25.
//
//

#import "ChartPattern+CoreDataProperties.h"

@implementation ChartPattern (CoreDataProperties)

+ (NSFetchRequest<ChartPattern *> *)fetchRequest {
	return [NSFetchRequest fetchRequestWithEntityName:@"ChartPattern"];
}

@dynamic additionalNotes;
@dynamic creationDate;
@dynamic patternID;
@dynamic patternType;
@dynamic savedDataReference;

@end
