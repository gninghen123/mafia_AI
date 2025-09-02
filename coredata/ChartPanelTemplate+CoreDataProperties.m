//
//  ChartPanelTemplate+CoreDataProperties.m
//  mafia_AI
//
//  Created by fabio gattone on 02/09/25.
//
//

#import "ChartPanelTemplate+CoreDataProperties.h"

@implementation ChartPanelTemplate (CoreDataProperties)

+ (NSFetchRequest<ChartPanelTemplate *> *)fetchRequest {
	return [NSFetchRequest fetchRequestWithEntityName:@"ChartPanelTemplate"];
}

@dynamic panelID;
@dynamic relativeHeight;
@dynamic displayOrder;
@dynamic panelName;
@dynamic rootIndicatorType;
@dynamic rootIndicatorParams;
@dynamic childIndicatorsData;
@dynamic template;

@end
