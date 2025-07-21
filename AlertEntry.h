//
//  AlertEntry.h
//  TradingApp
//
//  MODIFICATO: Ora usa SymbolDataModels invece di definire propri enum
//

#import <Foundation/Foundation.h>
#import "SymbolDataModels.h"  // Import per AlertType e AlertStatus

// RIMOSSI gli enum AlertType e AlertStatus - ora usiamo quelli di SymbolDataModels

// Mapping per compatibilità con il vecchio codice
#define AlertTypeAbove AlertTypePriceAbove
#define AlertTypeBelow AlertTypePriceBelow

@interface AlertEntry : NSObject <NSCoding, NSCopying>

@property (nonatomic, strong) NSString *alertID;
@property (nonatomic, strong) NSString *symbol;
@property (nonatomic, assign) double targetPrice;
@property (nonatomic, assign) AlertType alertType;
@property (nonatomic, assign) AlertStatus status;
@property (nonatomic, strong) NSDate *creationDate;
@property (nonatomic, strong, nullable) NSDate *triggerDate;
@property (nonatomic, strong, nullable) NSString *notes;

// Costruttore di convenienza
+ (instancetype)alertWithSymbol:(NSString *)symbol
                    targetPrice:(double)targetPrice
                           type:(AlertType)type;

// Metodi di utilità
- (NSString *)alertTypeString;
- (NSString *)statusString;
- (BOOL)shouldTriggerForPrice:(double)currentPrice;
- (NSDictionary *)toDictionary;
+ (instancetype)fromDictionary:(NSDictionary *)dict;

// NUOVO: Metodo per convertire in AlertData del nuovo sistema
- (AlertData *)toAlertData;
+ (instancetype)fromAlertData:(AlertData *)alertData;

@end
