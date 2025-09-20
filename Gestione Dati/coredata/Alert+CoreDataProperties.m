//
//  Alert+CoreDataProperties.m
//  mafia_AI
//
//  Created by fabio gattone on 07/08/25.
//
//

#import "Alert+CoreDataProperties.h"

@implementation Alert (CoreDataProperties)

+ (NSFetchRequest<Alert *> *)fetchRequest {
	return [NSFetchRequest fetchRequestWithEntityName:@"Alert"];
}

@dynamic conditionString;
@dynamic creationDate;
@dynamic isActive;
@dynamic isTriggered;
@dynamic notes;
@dynamic notificationEnabled;
@dynamic triggerDate;
@dynamic triggerValue;
@dynamic symbol;

@end
