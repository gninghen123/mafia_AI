//
//  OrderQuantityCalculator.h
//  TradingApp
//
//  Advanced quantity calculation engine for position sizing and risk management
//

#import <Foundation/Foundation.h>
#import "TradingRuntimeModels.h"

NS_ASSUME_NONNULL_BEGIN

@interface OrderQuantityCalculator : NSObject

#pragma mark - Singleton

+ (instancetype)sharedCalculator;

#pragma mark - Position Sizing Calculations

/**
 * Calculate shares needed for a percentage of portfolio value
 * @param percent Percentage of portfolio (0-100)
 * @param portfolioValue Total portfolio value
 * @param sharePrice Current share price
 * @return Number of shares (rounded down to avoid fractional shares)
 */
- (double)calculateSharesForPercentOfPortfolio:(double)percent
                                 portfolioValue:(double)portfolioValue
                                     sharePrice:(double)sharePrice;

/**
 * Calculate shares needed for a percentage of available cash
 * @param percent Percentage of cash (0-100)
 * @param cashAvailable Available cash balance
 * @param sharePrice Current share price
 * @return Number of shares
 */
- (double)calculateSharesForPercentOfCash:(double)percent
                                     cash:(double)cashAvailable
                               sharePrice:(double)sharePrice;

/**
 * Calculate shares needed for a specific dollar amount
 * @param dollarAmount Dollar amount to invest
 * @param sharePrice Current share price
 * @return Number of shares (rounded down)
 */
- (double)calculateSharesForDollarAmount:(double)dollarAmount
                              sharePrice:(double)sharePrice;

/**
 * Calculate shares based on maximum risk amount (Kelly Criterion approach)
 * @param riskDollars Maximum dollars willing to lose
 * @param entryPrice Entry price per share
 * @param stopPrice Stop loss price
 * @return Number of shares
 */
- (double)calculateSharesForRiskAmount:(double)riskDollars
                            entryPrice:(double)entryPrice
                             stopPrice:(double)stopPrice;

#pragma mark - Risk/Reward Analysis

/**
 * Calculate total risk amount for a position
 * @param shares Number of shares
 * @param entryPrice Entry price
 * @param stopPrice Stop loss price
 * @return Total risk in dollars
 */
- (double)calculateRiskAmount:(double)shares
                   entryPrice:(double)entryPrice
                    stopPrice:(double)stopPrice;

/**
 * Calculate total reward amount for a position
 * @param shares Number of shares
 * @param entryPrice Entry price
 * @param targetPrice Profit target price
 * @return Total reward in dollars
 */
- (double)calculateRewardAmount:(double)shares
                     entryPrice:(double)entryPrice
                    targetPrice:(double)targetPrice;

/**
 * Calculate risk/reward ratio
 * @param riskAmount Total risk in dollars
 * @param rewardAmount Total reward in dollars
 * @return Risk/reward ratio (e.g., 1:3 returns 3.0)
 */
- (double)calculateRiskRewardRatio:(double)riskAmount
                      rewardAmount:(double)rewardAmount;

/**
 * Calculate percentage of portfolio at risk
 * @param riskAmount Total risk in dollars
 * @param portfolioValue Total portfolio value
 * @return Risk percentage (0-100)
 */
- (double)calculatePortfolioRiskPercent:(double)riskAmount
                         portfolioValue:(double)portfolioValue;

#pragma mark - Smart Pricing Calculations

/**
 * Calculate stop loss price from percentage
 * @param percent Stop loss percentage (e.g., 3.0 for 3%)
 * @param entryPrice Entry price
 * @param side Order side ("BUY" or "SELL")
 * @return Stop loss price
 */
- (double)calculateStopPriceFromPercent:(double)percent
                             entryPrice:(double)entryPrice
                                   side:(NSString *)side;

/**
 * Calculate profit target price from percentage
 * @param percent Profit target percentage (e.g., 10.0 for 10%)
 * @param entryPrice Entry price
 * @param side Order side ("BUY" or "SELL")
 * @return Profit target price
 */
- (double)calculateTargetPriceFromPercent:(double)percent
                               entryPrice:(double)entryPrice
                                     side:(NSString *)side;

/**
 * Calculate profit target based on risk/reward ratio
 * @param rrr Desired risk/reward ratio (e.g., 3.0 for 1:3)
 * @param entryPrice Entry price
 * @param stopPrice Stop loss price
 * @param side Order side ("BUY" or "SELL")
 * @return Profit target price
 */
- (double)calculateTargetPriceFromRRR:(double)rrr
                           entryPrice:(double)entryPrice
                            stopPrice:(double)stopPrice
                                 side:(NSString *)side;

/**
 * Calculate ATR-based stop loss
 * @param atr14 14-period Average True Range
 * @param multiplier ATR multiplier (e.g., 2.0 for 2x ATR)
 * @param entryPrice Entry price
 * @param side Order side ("BUY" or "SELL")
 * @return ATR-based stop price
 */
- (double)calculateATRBasedStop:(double)atr14
                     multiplier:(double)multiplier
                     entryPrice:(double)entryPrice
                           side:(NSString *)side;

/**
 * Calculate stop based on day's range
 * @param dayLow Day's low price
 * @param dayHigh Day's high price
 * @param offset Offset in dollars (e.g., 0.01 for $0.01)
 * @param useHigh YES for resistance-based stop (short), NO for support-based (long)
 * @return Range-based stop price
 */
- (double)calculateRangeBasedStop:(double)dayLow
                          dayHigh:(double)dayHigh
                           offset:(double)offset
                          useHigh:(BOOL)useHigh;

#pragma mark - Position Validation

/**
 * Validate if position size is within risk limits
 * @param shares Number of shares
 * @param entryPrice Entry price
 * @param stopPrice Stop loss price
 * @param portfolioValue Total portfolio value
 * @param maxRiskPercent Maximum risk percentage allowed (e.g., 2.0 for 2%)
 * @return YES if position is within limits
 */
- (BOOL)validatePositionSize:(double)shares
                  entryPrice:(double)entryPrice
                   stopPrice:(double)stopPrice
              portfolioValue:(double)portfolioValue
               maxRiskPercent:(double)maxRiskPercent;

/**
 * Check if share count results in fractional shares
 * @param shares Calculated shares
 * @return YES if shares are whole numbers
 */
- (BOOL)validateWholeShares:(double)shares;

/**
 * Validate if prices make sense for the order side
 * @param entryPrice Entry price
 * @param stopPrice Stop loss price
 * @param side Order side ("BUY" or "SELL")
 * @param error Error details if validation fails
 * @return YES if prices are valid
 */
- (BOOL)validatePriceLogic:(double)entryPrice
                 stopPrice:(double)stopPrice
                      side:(NSString *)side
                     error:(NSError **)error;

#pragma mark - Formatting Helpers

/**
 * Format currency amount for display
 * @param amount Dollar amount
 * @return Formatted currency string
 */
- (NSString *)formatCurrency:(double)amount;

/**
 * Format percentage for display
 * @param percentage Percentage value (0-100)
 * @return Formatted percentage string
 */
- (NSString *)formatPercentage:(double)percentage;

/**
 * Format risk/reward ratio for display
 * @param ratio R:R ratio
 * @return Formatted ratio string (e.g., "1:3.2")
 */
- (NSString *)formatRiskRewardRatio:(double)ratio;

/**
 * Format share count (handle fractional shares)
 * @param shares Share count
 * @return Formatted shares string
 */
- (NSString *)formatShares:(double)shares;

#pragma mark - Advanced Calculations

/**
 * Calculate optimal position size using Kelly Criterion
 * @param winProbability Probability of winning (0.0-1.0)
 * @param avgWin Average winning amount
 * @param avgLoss Average losing amount
 * @param portfolioValue Total portfolio value
 * @return Recommended position size as percentage of portfolio
 */
- (double)calculateKellyOptimalSize:(double)winProbability
                             avgWin:(double)avgWin
                            avgLoss:(double)avgLoss
                     portfolioValue:(double)portfolioValue;

/**
 * Calculate position size heat map for different risk levels
 * @param entryPrice Entry price
 * @param stopPrice Stop price
 * @param portfolioValue Portfolio value
 * @return Dictionary with risk levels as keys and position sizes as values
 */
- (NSDictionary<NSString *, NSNumber *> *)calculateRiskHeatMap:(double)entryPrice
                                                     stopPrice:(double)stopPrice
                                                portfolioValue:(double)portfolioValue;

@end

NS_ASSUME_NONNULL_END
