//
//  Alert+CoreDataProperties.m
//  mafia_AI
//
//  Created by fabio gattone on 21/07/25.
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
@dynamic symbol;
@dynamic triggerDate;
@dynamic triggerValue;

@end
