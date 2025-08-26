//
//  TradingModel+CoreDataProperties.m
//  mafia_AI
//
//  Created by fabio gattone on 07/08/25.
//
//

#import "TradingModel+CoreDataProperties.h"

@implementation TradingModel (CoreDataProperties)

+ (NSFetchRequest<TradingModel *> *)fetchRequest {
	return [NSFetchRequest fetchRequestWithEntityName:@"TradingModel"];
}

@dynamic currentOutcome;
@dynamic entryDate;
@dynamic entryPrice;
@dynamic exitDate;
@dynamic modelType;
@dynamic notes;
@dynamic setupDate;
@dynamic status;
@dynamic stopPrice;
@dynamic targetPrice;
@dynamic symbol;

@end
