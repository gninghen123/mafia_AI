//
//  CompanyInfo+CoreDataProperties.m
//  mafia_AI
//
//  Created by fabio gattone on 07/08/25.
//
//

#import "CompanyInfo+CoreDataProperties.h"

@implementation CompanyInfo (CoreDataProperties)

+ (NSFetchRequest<CompanyInfo *> *)fetchRequest {
	return [NSFetchRequest fetchRequestWithEntityName:@"CompanyInfo"];
}

@dynamic ceo;
@dynamic companyDescription;
@dynamic employees;
@dynamic headquarters;
@dynamic industry;
@dynamic ipoDate;
@dynamic lastUpdate;
@dynamic name;
@dynamic sector;
@dynamic website;
@dynamic symbol;

@end
