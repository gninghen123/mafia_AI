//
//  CompanyInfo+CoreDataProperties.h
//  mafia_AI
//
//  Created by fabio gattone on 07/08/25.
//
//

#import "CompanyInfo+CoreDataClass.h"

@class Symbol;

NS_ASSUME_NONNULL_BEGIN

@interface CompanyInfo (CoreDataProperties)

+ (NSFetchRequest<CompanyInfo *> *)fetchRequest NS_SWIFT_NAME(fetchRequest());

@property (nullable, nonatomic, copy) NSString *ceo;
@property (nullable, nonatomic, copy) NSString *companyDescription;
@property (nonatomic) int32_t employees;
@property (nullable, nonatomic, copy) NSString *headquarters;
@property (nullable, nonatomic, copy) NSString *industry;
@property (nullable, nonatomic, copy) NSDate *ipoDate;
@property (nullable, nonatomic, copy) NSDate *lastUpdate;
@property (nullable, nonatomic, copy) NSString *name;
@property (nullable, nonatomic, copy) NSString *sector;
@property (nullable, nonatomic, copy) NSString *website;
@property (nullable, nonatomic, retain) Symbol *symbol;

@end

NS_ASSUME_NONNULL_END
