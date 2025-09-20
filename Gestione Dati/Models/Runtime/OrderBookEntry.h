//
//  OrderBookEntry.h
//  mafia_AI
//
//  Modello per rappresentare un'entry nell'order book
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface OrderBookEntry : NSObject

@property (nonatomic, assign) double price;
@property (nonatomic, assign) NSInteger size;
@property (nonatomic, strong) NSString *marketMaker;
@property (nonatomic, strong) NSDate *timestamp;
@property (nonatomic, assign) BOOL isBid; // YES = bid, NO = ask

// Inizializzatore
- (instancetype)initWithPrice:(double)price
                         size:(NSInteger)size
                  marketMaker:(NSString *)marketMaker
                        isBid:(BOOL)isBid;

@end

NS_ASSUME_NONNULL_END
