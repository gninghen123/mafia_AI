//
//  BreakoutScreener.h
//  TradingApp
//
//  Breakout pattern screener
//  Pattern: close > highest(close[1], lookbackPeriod)
//

#import "BaseScreener.h"

NS_ASSUME_NONNULL_BEGIN

@interface BreakoutScreener : BaseScreener
@end

NS_ASSUME_NONNULL_END
