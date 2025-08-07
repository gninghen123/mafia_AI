//
//  HistoricalBar+CoreDataProperties.m
//  mafia_AI
//
//  Created by fabio gattone on 07/08/25.
//
//

#import "HistoricalBar+CoreDataProperties.h"

@implementation HistoricalBar (CoreDataProperties)

+ (NSFetchRequest<HistoricalBar *> *)fetchRequest {
	return [NSFetchRequest fetchRequestWithEntityName:@"HistoricalBar"];
}

@dynamic adjustedClose;
@dynamic close;
@dynamic date;
@dynamic high;
@dynamic low;
@dynamic open;
@dynamic timeframe;
@dynamic volume;
@dynamic symbol;

@end
