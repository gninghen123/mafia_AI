//
//  StockConnection+CoreDataProperties.h
//  mafia_AI
//
//  Created by fabio gattone on 31/07/25.
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
@property (nullable, nonatomic, copy) NSString *connectionID;
@property (nullable, nonatomic, copy) NSString *title;
@property (nullable, nonatomic, copy) NSDate *lastModified;
@property (nonatomic) BOOL isActive;
@property (nullable, nonatomic, copy) NSString *sourceSymbol;
@property (nullable, nonatomic, retain) NSArray *targetSymbols;
@property (nonatomic) BOOL bidirectional;
@property (nullable, nonatomic, copy) NSString *originalSummary;
@property (nullable, nonatomic, copy) NSString *manualSummary;
@property (nonatomic) int16_t summarySource;
@property (nonatomic) double initialStrength;
@property (nonatomic) double currentStrength;
@property (nonatomic) double decayRate;
@property (nonatomic) double minimumStrength;
@property (nullable, nonatomic, copy) NSDate *strengthHorizon;
@property (nonatomic) BOOL autoDelete;
@property (nullable, nonatomic, copy) NSDate *lastStrengthUpdate;
@property (nullable, nonatomic, copy) NSString *notes;
@property (nullable, nonatomic, retain) NSArray *tags;

@end

NS_ASSUME_NONNULL_END
