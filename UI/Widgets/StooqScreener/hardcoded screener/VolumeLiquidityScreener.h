//
//  VolumeLiquidityScreener.h
//  TradingApp
//
//  Screener: Volume medio (SMA 5) * Close > threshold
//  Filtra titoli con liquidità sufficiente in dollari
//

#import "BaseScreener.h"

NS_ASSUME_NONNULL_BEGIN

@interface VolumeLiquidityScreener : BaseScreener

@end

NS_ASSUME_NONNULL_END
