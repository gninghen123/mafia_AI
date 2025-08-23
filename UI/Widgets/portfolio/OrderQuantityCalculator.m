//
//  OrderQuantityCalculator.m
//  TradingApp
//
//  Implementation of advanced quantity calculation engine
//

#import "OrderQuantityCalculator.h"

@implementation OrderQuantityCalculator

#pragma mark - Singleton

+ (instancetype)sharedCalculator {
    static OrderQuantityCalculator *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[OrderQuantityCalculator alloc] init];
    });
    return sharedInstance;
}

#pragma mark - Position Sizing Calculations

- (double)calculateSharesForPercentOfPortfolio:(double)percent
                                 portfolioValue:(double)portfolioValue
                                     sharePrice:(double)sharePrice {
    if (sharePrice <= 0 || portfolioValue <= 0 || percent <= 0) {
        return 0;
    }
    
    double dollarAmount = (percent / 100.0) * portfolioValue;
    double shares = floor(dollarAmount / sharePrice);
    
    NSLog(@"📊 Calculator: Portfolio sizing - %.1f%% of $%.0f = %.0f shares at $%.2f",
          percent, portfolioValue, shares, sharePrice);
    
    return shares;
}

- (double)calculateSharesForPercentOfCash:(double)percent
                                     cash:(double)cashAvailable
                               sharePrice:(double)sharePrice {
    if (sharePrice <= 0 || cashAvailable <= 0 || percent <= 0) {
        return 0;
    }
    
    double dollarAmount = (percent / 100.0) * cashAvailable;
    double shares = floor(dollarAmount / sharePrice);
    
    NSLog(@"💰 Calculator: Cash sizing - %.1f%% of $%.0f cash = %.0f shares",
          percent, cashAvailable, shares);
    
    return shares;
}

- (double)calculateSharesForDollarAmount:(double)dollarAmount
                              sharePrice:(double)sharePrice {
    if (sharePrice <= 0 || dollarAmount <= 0) {
        return 0;
    }
    
    double shares = floor(dollarAmount / sharePrice);
    
    NSLog(@"💵 Calculator: Dollar sizing - $%.0f = %.0f shares at $%.2f",
          dollarAmount, shares, sharePrice);
    
    return shares;
}

- (double)calculateSharesForRiskAmount:(double)riskDollars
                            entryPrice:(double)entryPrice
                             stopPrice:(double)stopPrice {
    if (entryPrice <= 0 || stopPrice <= 0 || riskDollars <= 0) {
        return 0;
    }
    
    double riskPerShare = fabs(entryPrice - stopPrice);
    if (riskPerShare <= 0) {
        return 0;
    }
    
    double shares = floor(riskDollars / riskPerShare);
    
    NSLog(@"⚠️ Calculator: Risk sizing - $%.0f risk / $%.4f per share = %.0f shares",
          riskDollars, riskPerShare, shares);
    
    return shares;
}

#pragma mark - Risk/Reward Analysis

- (double)calculateRiskAmount:(double)shares
                   entryPrice:(double)entryPrice
                    stopPrice:(double)stopPrice {
    if (shares <= 0 || entryPrice <= 0 || stopPrice <= 0) {
        return 0;
    }
    
    double riskPerShare = fabs(entryPrice - stopPrice);
    double totalRisk = shares * riskPerShare;
    
    return totalRisk;
}

- (double)calculateRewardAmount:(double)shares
                     entryPrice:(double)entryPrice
                    targetPrice:(double)targetPrice {
    if (shares <= 0 || entryPrice <= 0 || targetPrice <= 0) {
        return 0;
    }
    
    double rewardPerShare = fabs(targetPrice - entryPrice);
    double totalReward = shares * rewardPerShare;
    
    return totalReward;
}

- (double)calculateRiskRewardRatio:(double)riskAmount
                      rewardAmount:(double)rewardAmount {
    if (riskAmount <= 0) {
        return 0;
    }
    
    return rewardAmount / riskAmount;
}

- (double)calculatePortfolioRiskPercent:(double)riskAmount
                         portfolioValue:(double)portfolioValue {
    if (portfolioValue <= 0) {
        return 0;
    }
    
    return (riskAmount / portfolioValue) * 100.0;
}

#pragma mark - Smart Pricing Calculations

- (double)calculateStopPriceFromPercent:(double)percent
                             entryPrice:(double)entryPrice
                                   side:(NSString *)side {
    if (entryPrice <= 0 || percent <= 0) {
        return 0;
    }
    
    double multiplier = (percent / 100.0);
    
    if ([side hasPrefix:@"BUY"]) {
        // For long positions, stop is below entry
        return entryPrice * (1.0 - multiplier);
    } else {
        // For short positions, stop is above entry
        return entryPrice * (1.0 + multiplier);
    }
}

- (double)calculateTargetPriceFromPercent:(double)percent
                               entryPrice:(double)entryPrice
                                     side:(NSString *)side {
    if (entryPrice <= 0 || percent <= 0) {
        return 0;
    }
    
    double multiplier = (percent / 100.0);
    
    if ([side hasPrefix:@"BUY"]) {
        // For long positions, target is above entry
        return entryPrice * (1.0 + multiplier);
    } else {
        // For short positions, target is below entry
        return entryPrice * (1.0 - multiplier);
    }
}

- (double)calculateTargetPriceFromRRR:(double)rrr
                           entryPrice:(double)entryPrice
                            stopPrice:(double)stopPrice
                                 side:(NSString *)side {
    if (entryPrice <= 0 || stopPrice <= 0 || rrr <= 0) {
        return 0;
    }
    
    double riskPerShare = fabs(entryPrice - stopPrice);
    double rewardPerShare = rrr * riskPerShare;
    
    if ([side hasPrefix:@"BUY"]) {
        // For long positions, target is above entry
        return entryPrice + rewardPerShare;
    } else {
        // For short positions, target is below entry
        return entryPrice - rewardPerShare;
    }
}

- (double)calculateATRBasedStop:(double)atr14
                     multiplier:(double)multiplier
                     entryPrice:(double)entryPrice
                           side:(NSString *)side {
    if (atr14 <= 0 || multiplier <= 0 || entryPrice <= 0) {
        return 0;
    }
    
    double atrStop = atr14 * multiplier;
    
    if ([side hasPrefix:@"BUY"]) {
        // For long positions, stop is below entry
        return entryPrice - atrStop;
    } else {
        // For short positions, stop is above entry
        return entryPrice + atrStop;
    }
}

- (double)calculateRangeBasedStop:(double)dayLow
                          dayHigh:(double)dayHigh
                           offset:(double)offset
                          useHigh:(BOOL)useHigh {
    if (useHigh) {
        // Resistance-based stop (typically for short positions)
        return dayHigh + offset;
    } else {
        // Support-based stop (typically for long positions)
        return dayLow - offset;
    }
}

#pragma mark - Position Validation

- (BOOL)validatePositionSize:(double)shares
                  entryPrice:(double)entryPrice
                   stopPrice:(double)stopPrice
              portfolioValue:(double)portfolioValue
               maxRiskPercent:(double)maxRiskPercent {
    
    double riskAmount = [self calculateRiskAmount:shares entryPrice:entryPrice stopPrice:stopPrice];
    double riskPercent = [self calculatePortfolioRiskPercent:riskAmount portfolioValue:portfolioValue];
    
    BOOL isValid = riskPercent <= maxRiskPercent;
    
    if (!isValid) {
        NSLog(@"⚠️ Calculator: Position size validation failed - Risk %.2f%% exceeds max %.2f%%",
              riskPercent, maxRiskPercent);
    }
    
    return isValid;
}

- (BOOL)validateWholeShares:(double)shares {
    return (shares == floor(shares));
}

- (BOOL)validatePriceLogic:(double)entryPrice
                 stopPrice:(double)stopPrice
                      side:(NSString *)side
                     error:(NSError **)error {
    
    if (entryPrice <= 0 || stopPrice <= 0) {
        if (error) {
            *error = [NSError errorWithDomain:@"OrderValidation"
                                         code:1001
                                     userInfo:@{NSLocalizedDescriptionKey: @"Prices must be greater than zero"}];
        }
        return NO;
    }
    
    if ([side hasPrefix:@"BUY"]) {
        // For long positions, stop should be below entry
        if (stopPrice >= entryPrice) {
            if (error) {
                *error = [NSError errorWithDomain:@"OrderValidation"
                                             code:1002
                                         userInfo:@{NSLocalizedDescriptionKey: @"For BUY orders, stop price must be below entry price"}];
            }
            return NO;
        }
    } else if ([side isEqualToString:@"SELL"] || [side isEqualToString:@"SELL_SHORT"]) {
        // For short positions, stop should be above entry
        if (stopPrice <= entryPrice) {
            if (error) {
                *error = [NSError errorWithDomain:@"OrderValidation"
                                             code:1003
                                         userInfo:@{NSLocalizedDescriptionKey: @"For SELL orders, stop price must be above entry price"}];
            }
            return NO;
        }
    }
    
    return YES;
}

#pragma mark - Formatting Helpers

- (NSString *)formatCurrency:(double)amount {
    NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
    formatter.numberStyle = NSNumberFormatterCurrencyStyle;
    formatter.maximumFractionDigits = 2;
    
    // Handle negative amounts
    if (amount < 0) {
        formatter.negativeFormat = @"-$#,##0.00";
    }
    
    return [formatter stringFromNumber:@(amount)];
}

- (NSString *)formatPercentage:(double)percentage {
    if (percentage == 0) {
        return @"0.0%";
    } else if (fabs(percentage) < 0.01) {
        return [NSString stringWithFormat:@"%.3f%%", percentage];
    } else if (fabs(percentage) < 0.1) {
        return [NSString stringWithFormat:@"%.2f%%", percentage];
    } else {
        return [NSString stringWithFormat:@"%.1f%%", percentage];
    }
}

- (NSString *)formatRiskRewardRatio:(double)ratio {
    if (ratio <= 0) {
        return @"--";
    }
    
    return [NSString stringWithFormat:@"1:%.1f", ratio];
}

- (NSString *)formatShares:(double)shares {
    if (shares == floor(shares)) {
        return [NSString stringWithFormat:@"%.0f", shares];
    } else {
        return [NSString stringWithFormat:@"%.2f", shares];
    }
}

#pragma mark - Advanced Calculations

- (double)calculateKellyOptimalSize:(double)winProbability
                             avgWin:(double)avgWin
                            avgLoss:(double)avgLoss
                     portfolioValue:(double)portfolioValue {
    if (avgLoss <= 0 || winProbability <= 0 || winProbability >= 1) {
        return 0;
    }
    
    // Kelly Formula: f = (bp - q) / b
    // where: b = avgWin/avgLoss, p = winProbability, q = (1 - winProbability)
    double b = avgWin / avgLoss;
    double p = winProbability;
    double q = 1.0 - winProbability;
    
    double kellyPercent = (b * p - q) / b;
    
    // Cap at 25% for safety
    kellyPercent = MIN(kellyPercent, 0.25);
    kellyPercent = MAX(kellyPercent, 0.0);
    
    NSLog(@"🎯 Calculator: Kelly optimal size - %.1f%% of portfolio", kellyPercent * 100.0);
    
    return kellyPercent * 100.0; // Return as percentage
}

- (NSDictionary<NSString *, NSNumber *> *)calculateRiskHeatMap:(double)entryPrice
                                                     stopPrice:(double)stopPrice
                                                portfolioValue:(double)portfolioValue {
    NSMutableDictionary *heatMap = [NSMutableDictionary dictionary];
    
    NSArray<NSNumber *> *riskLevels = @[@0.5, @1.0, @1.5, @2.0, @2.5, @3.0, @4.0, @5.0];
    
    for (NSNumber *riskPercent in riskLevels) {
        double riskAmount = (riskPercent.doubleValue / 100.0) * portfolioValue;
        double shares = [self calculateSharesForRiskAmount:riskAmount
                                                entryPrice:entryPrice
                                                 stopPrice:stopPrice];
        
        NSString *key = [NSString stringWithFormat:@"%.1f%%", riskPercent.doubleValue];
        heatMap[key] = @(shares);
    }
    
    return [heatMap copy];
}

@end
