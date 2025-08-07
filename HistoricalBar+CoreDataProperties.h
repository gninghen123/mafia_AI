//
//  HistoricalBar+CoreDataProperties.h
//  mafia_AI
//
//  Created by fabio gattone on 07/08/25.
//
//

#import "HistoricalBar+CoreDataClass.h"


NS_ASSUME_NONNULL_BEGIN
@class Symbol;

@interface HistoricalBar (CoreDataProperties)

+ (NSFetchRequest<HistoricalBar *> *)fetchRequest NS_SWIFT_NAME(fetchRequest());

@property (nonatomic) double adjustedClose;
@property (nonatomic) double close;
@property (nullable, nonatomic, copy) NSDate *date;
@property (nonatomic) double high;
@property (nonatomic) double low;
@property (nonatomic) double open;
@property (nonatomic) int16_t timeframe;
@property (nonatomic) int64_t volume;
@property (nullable, nonatomic, retain) Symbol *symbol;

@end

NS_ASSUME_NONNULL_END
