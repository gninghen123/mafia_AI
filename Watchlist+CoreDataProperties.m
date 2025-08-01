//
//  Watchlist+CoreDataProperties.m
//  mafia_AI
//
//  Created by fabio gattone on 30/07/25.
//
//

#import "Watchlist+CoreDataProperties.h"

@implementation Watchlist (CoreDataProperties)

+ (NSFetchRequest<Watchlist *> *)fetchRequest {
	return [NSFetchRequest fetchRequestWithEntityName:@"Watchlist"];
}

@dynamic colorHex;
@dynamic creationDate;
@dynamic lastModified;
@dynamic name;
@dynamic sortOrder;
@dynamic symbols;

@end
