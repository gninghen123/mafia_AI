//
//  TradingModel+CoreDataProperties.h
//  mafia_AI
//
//  Created by fabio gattone on 07/08/25.
//
//

#import "TradingModel+CoreDataClass.h"


NS_ASSUME_NONNULL_BEGIN
@class Symbol;

@interface TradingModel (CoreDataProperties)

+ (NSFetchRequest<TradingModel *> *)fetchRequest NS_SWIFT_NAME(fetchRequest());

@property (nonatomic) double currentOutcome;
@property (nullable, nonatomic, copy) NSDate *entryDate;
@property (nonatomic) double entryPrice;
@property (nullable, nonatomic, copy) NSDate *exitDate;
@property (nonatomic) int64_t modelType;
@property (nullable, nonatomic, copy) NSString *notes;
@property (nullable, nonatomic, copy) NSDate *setupDate;
@property (nonatomic) int64_t status;
@property (nonatomic) double stopPrice;
@property (nonatomic) double targetPrice;
@property (nullable, nonatomic, retain) Symbol *symbol;

@end

NS_ASSUME_NONNULL_END
