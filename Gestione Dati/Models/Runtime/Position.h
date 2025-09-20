//
//  Position.h
//  mafia_AI
//
//  Modello per rappresentare una posizione di trading
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface Position : NSObject

@property (nonatomic, strong) NSString *symbol;
@property (nonatomic, strong) NSString *accountId;
@property (nonatomic, assign) double quantity;
@property (nonatomic, assign) double averageCost;
@property (nonatomic, assign) double currentPrice;
@property (nonatomic, assign) double marketValue;
@property (nonatomic, assign) double unrealizedPL;
@property (nonatomic, assign) double realizedPL;
@property (nonatomic, assign) double unrealizedPLPercent;
@property (nonatomic, strong) NSDate *openDate;
@property (nonatomic, strong, nullable) NSString *positionType; // "long", "short"

// Calcolati
- (double)totalCost;
- (double)totalReturn;
- (double)totalReturnPercent;

@end

NS_ASSUME_NONNULL_END
