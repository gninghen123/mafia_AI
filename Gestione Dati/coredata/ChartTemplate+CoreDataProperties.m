//
//  ChartTemplate+CoreDataProperties.m
//  mafia_AI
//
//  Created by fabio gattone on 02/09/25.
//
//

#import "ChartTemplate+CoreDataProperties.h"

@implementation ChartTemplate (CoreDataProperties)

+ (NSFetchRequest<ChartTemplate *> *)fetchRequest {
	return [NSFetchRequest fetchRequestWithEntityName:@"ChartTemplate"];
}

@dynamic createdDate;
@dynamic isDefault;
@dynamic modifiedDate;
@dynamic templateID;
@dynamic templateName;
@dynamic panels;

@end
