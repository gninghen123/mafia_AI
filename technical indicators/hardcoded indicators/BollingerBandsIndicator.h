//
// BollingerBandsIndicator.h
// TradingApp
//
// Bollinger Bands indicator implementation
//

#import "TechnicalIndicatorBase.h"

NS_ASSUME_NONNULL_BEGIN

@interface BollingerBandsIndicator : TechnicalIndicatorBase

// Bollinger Bands specific methods
- (double)currentMiddleBand;            // Middle band (SMA)
- (double)currentUpperBand;             // Upper band
- (double)currentLowerBand;             // Lower band
- (double)currentBandwidth;             // Upper - Lower
- (double)currentPercentB:(double)price; // %B position within bands

// Band analysis
- (BOOL)isPriceTouchingUpperBand:(double)price tolerance:(double)tolerance;
- (BOOL)isPriceTouchingLowerBand:(double)price tolerance:(double)tolerance;
- (BOOL)isPriceOutsideBands:(double)price;
- (BOOL)areBandsContracting:(NSInteger)lookbackPeriods; // Volatility decreasing

@end

NS_ASSUME_NONNULL_END
