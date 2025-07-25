//
//  CompanyInfo+CoreDataProperties.m
//  mafia_AI
//
//  Created by fabio gattone on 25/07/25.
//
//

#import "CompanyInfo+CoreDataProperties.h"

@implementation CompanyInfo (CoreDataProperties)

+ (NSFetchRequest<CompanyInfo *> *)fetchRequest {
	return [NSFetchRequest fetchRequestWithEntityName:@"CompanyInfo"];
}

@dynamic symbol;
@dynamic name;
@dynamic sector;
@dynamic industry;
@dynamic companyDescription;
@dynamic website;
@dynamic ceo;
@dynamic employees;
@dynamic headquarters;
@dynamic ipoDate;
@dynamic lastUpdate;

@end
