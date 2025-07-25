#pragma mark - CompanyInfo Entity
// Informazioni aziendali
@interface CompanyInfo : NSManagedObject

@property (nonatomic, strong) NSString *symbol;
@property (nonatomic, strong) NSString *name;
@property (nonatomic, strong) NSString *sector;
@property (nonatomic, strong) NSString *industry;
@property (nonatomic, strong) NSString *companyDescription;
@property (nonatomic, strong) NSString *website;
@property (nonatomic, strong) NSString *ceo;
@property (nonatomic) int32_t employees;
@property (nonatomic, strong) NSString *headquarters;
@property (nonatomic, strong) NSDate *ipoDate;
@property (nonatomic, strong) NSDate *lastUpdate;

@end
