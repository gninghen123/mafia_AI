//
//  AlertEntry.h
//  TradingApp
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, AlertType) {
    AlertTypeAbove = 0,  // Prezzo sopra il target
    AlertTypeBelow = 1   // Prezzo sotto il target
};

typedef NS_ENUM(NSInteger, AlertStatus) {
    AlertStatusActive = 0,
    AlertStatusTriggered = 1,
    AlertStatusDisabled = 2
};

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

@end
