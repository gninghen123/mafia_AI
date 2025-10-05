//
//  MovingAverageTrendScreener.h
//  TradingApp
//
//  Screener che verifica se una media mobile è in trend up o down
//

#import "BaseScreener.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, MATrendDirection) {
    MATrendDirectionUp = 0,
    MATrendDirectionDown = 1
};

typedef NS_ENUM(NSInteger, MAType) {
    MATypeSimple = 0,        // SMA
    MATypeExponential = 1    // EMA
};

@interface MovingAverageTrendScreener : BaseScreener

/**
 * Parameters:
 * - "period" (NSInteger): Periodo della media mobile (default: 50)
 * - "direction" (NSInteger): Direzione trend (0=Up, 1=Down) (default: 0 - Up)
 * - "maType" (NSInteger): Tipo di media (0=Simple, 1=Exponential) (default: 0 - Simple)
 * - "lookbackBars" (NSInteger): Numero di barre per verificare il trend (default: 3)
 */

@end

NS_ASSUME_NONNULL_END
