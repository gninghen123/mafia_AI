//
//  CompanyInfo+CoreDataProperties.h
//  mafia_AI
//
//  Created by fabio gattone on 25/07/25.
//
//

#import "CompanyInfo+CoreDataClass.h"


NS_ASSUME_NONNULL_BEGIN

@interface CompanyInfo (CoreDataProperties)

+ (NSFetchRequest<CompanyInfo *> *)fetchRequest NS_SWIFT_NAME(fetchRequest());

@property (nullable, nonatomic, copy) NSString *symbol;
@property (nullable, nonatomic, copy) NSString *name;
@property (nullable, nonatomic, copy) NSString *sector;
@property (nullable, nonatomic, copy) NSString *industry;
@property (nullable, nonatomic, copy) NSString *companyDescription;
@property (nullable, nonatomic, copy) NSString *website;
@property (nullable, nonatomic, copy) NSString *ceo;
@property (nonatomic) int32_t employees;
@property (nullable, nonatomic, copy) NSString *headquarters;
@property (nullable, nonatomic, copy) NSDate *ipoDate;
@property (nullable, nonatomic, copy) NSDate *lastUpdate;

@end

NS_ASSUME_NONNULL_END
