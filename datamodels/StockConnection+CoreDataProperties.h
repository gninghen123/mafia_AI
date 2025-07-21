//
//  StockConnection+CoreDataProperties.h
//  mafia_AI
//
//  Created by fabio gattone on 21/07/25.
//
//

#import "StockConnection+CoreDataClass.h"


NS_ASSUME_NONNULL_BEGIN

@interface StockConnection (CoreDataProperties)

+ (NSFetchRequest<StockConnection *> *)fetchRequest NS_SWIFT_NAME(fetchRequest());

@property (nullable, nonatomic, copy) NSString *connectionDescription;
@property (nonatomic) int64_t connectionType;
@property (nullable, nonatomic, copy) NSDate *creationDate;
@property (nullable, nonatomic, copy) NSString *source;
@property (nullable, nonatomic, retain) NSArray *symbols;
@property (nullable, nonatomic, copy) NSString *url;

@end

NS_ASSUME_NONNULL_END
