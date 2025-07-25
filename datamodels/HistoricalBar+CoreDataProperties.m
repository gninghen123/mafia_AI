//
//  HistoricalBar+CoreDataProperties.m
//  mafia_AI
//
//  Created by fabio gattone on 25/07/25.
//
//

#import "HistoricalBar+CoreDataProperties.h"

@implementation HistoricalBar (CoreDataProperties)

+ (NSFetchRequest<HistoricalBar *> *)fetchRequest {
	return [NSFetchRequest fetchRequestWithEntityName:@"HistoricalBar"];
}

@dynamic symbol;
@dynamic date;
@dynamic open;
@dynamic high;
@dynamic low;
@dynamic close;
@dynamic adjustedClose;
@dynamic volume;
@dynamic timeframe;

@end
