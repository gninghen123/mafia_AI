//
// SecurityIndicator.h
// TradingApp
//
// Security price data visualizer - displays OHLC data as candlesticks, lines, etc.
// This replaces the missing "SecurityIndicator" referenced in default templates
//

#import "RawDataSeriesIndicator.h"

NS_ASSUME_NONNULL_BEGIN

@interface SecurityIndicator : RawDataSeriesIndicator

#pragma mark - Convenience Factory Methods

/// Create candlestick chart (default for security data)
/// @return SecurityIndicator configured for candlesticks
+ (instancetype)candlestickIndicator;

/// Create line chart from close prices
/// @return SecurityIndicator configured for line chart
+ (instancetype)lineIndicator;

/// Create OHLC bar chart
/// @return SecurityIndicator configured for OHLC bars
+ (instancetype)ohlcIndicator;

/// Create area chart from close prices
/// @return SecurityIndicator configured for area chart
+ (instancetype)areaIndicator;

#pragma mark - Security-Specific Methods

/// Get current price (latest close)
/// @return Current close price or NAN if not calculated
- (double)currentPrice;

/// Get price change from previous bar
/// @return Price change or NAN if insufficient data
- (double)priceChange;

/// Get percentage change from previous bar
/// @return Percentage change or NAN if insufficient data
- (double)percentChange;

/// Check if latest bar is bullish (green)
/// @return YES if close > open
- (BOOL)isCurrentBarBullish;

- (BOOL)hasVisualOutput;

/// Get OHLC values for latest bar
/// @return Dictionary with open, high, low, close keys
- (NSDictionary<NSString *, NSNumber *> *)currentOHLC;

#pragma mark - Display Configuration

/// Configure for candlestick display with custom colors
/// @param bullishColor Color for bullish candles (close > open)
/// @param bearishColor Color for bearish candles (close < open)
- (void)configureCandlestickWithBullishColor:(NSColor *)bullishColor
                                bearishColor:(NSColor *)bearishColor;

/// Configure for line display with custom color and width
/// @param color Line color
/// @param width Line width
- (void)configureLineWithColor:(NSColor *)color width:(CGFloat)width;

@end

NS_ASSUME_NONNULL_END
