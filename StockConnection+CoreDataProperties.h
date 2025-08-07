//
//  StockConnection+CoreDataProperties.h
//  mafia_AI
//
//  Created by fabio gattone on 07/08/25.
//
//

#import "StockConnection+CoreDataClass.h"


NS_ASSUME_NONNULL_BEGIN
@class Symbol;

@interface StockConnection (CoreDataProperties)

+ (NSFetchRequest<StockConnection *> *)fetchRequest NS_SWIFT_NAME(fetchRequest());

@property (nonatomic) BOOL autoDelete;
@property (nonatomic) BOOL bidirectional;
@property (nullable, nonatomic, copy) NSString *connectionDescription;
@property (nullable, nonatomic, copy) NSString *connectionID;
@property (nonatomic) int64_t connectionType;
@property (nullable, nonatomic, copy) NSDate *creationDate;
@property (nonatomic) double currentStrength;
@property (nonatomic) double decayRate;
@property (nonatomic) double initialStrength;
@property (nonatomic) BOOL isActive;
@property (nullable, nonatomic, copy) NSDate *lastModified;
@property (nullable, nonatomic, copy) NSDate *lastStrengthUpdate;
@property (nullable, nonatomic, copy) NSString *manualSummary;
@property (nonatomic) double minimumStrength;
@property (nullable, nonatomic, copy) NSString *notes;
@property (nullable, nonatomic, copy) NSString *originalSummary;
@property (nullable, nonatomic, copy) NSString *source;
@property (nullable, nonatomic, copy) NSDate *strengthHorizon;
@property (nonatomic) int16_t summarySource;
@property (nullable, nonatomic, retain) NSArray *tags;
@property (nullable, nonatomic, copy) NSString *title;
@property (nullable, nonatomic, copy) NSString *url;
@property (nullable, nonatomic, retain) Symbol *sourceSymbol;
@property (nullable, nonatomic, retain) NSSet<Symbol *> *targetSymbols;

@end

@interface StockConnection (CoreDataGeneratedAccessors)

- (void)addTargetSymbolsObject:(Symbol *)value;
- (void)removeTargetSymbolsObject:(Symbol *)value;
- (void)addTargetSymbols:(NSSet<Symbol *> *)values;
- (void)removeTargetSymbols:(NSSet<Symbol *> *)values;

@end

NS_ASSUME_NONNULL_END
