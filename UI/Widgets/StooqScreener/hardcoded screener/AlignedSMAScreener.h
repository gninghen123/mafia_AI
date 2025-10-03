//
//  AlignedSMAScreener.h
//  TradingApp
//
//  Filtra simboli con medie mobili allineate in ordine crescente
//  Esempio: SMA(10) > SMA(20) > SMA(50)
//  Opzionale: Close > SMA(10) per conferma trend
//

#import "BaseScreener.h"

NS_ASSUME_NONNULL_BEGIN

@interface AlignedSMAScreener : BaseScreener
@end

NS_ASSUME_NONNULL_END
