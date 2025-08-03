//
//  CandlestickRenderer.h
//  TradingApp
//
//  Renders OHLC candlestick charts for security data
//

#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>
#import "IndicatorRenderer.h"
#import "IndicatorSettings.h"

NS_ASSUME_NONNULL_BEGIN

@interface CandlestickRenderer : NSObject <IndicatorRenderer>

#pragma mark - Properties
@property (nonatomic, strong) IndicatorSettings *settings;

#pragma mark - Customization (will be managed by settings)
@property (nonatomic, strong) NSColor *upColor;
@property (nonatomic, strong) NSColor *downColor;
@property (nonatomic, strong) NSColor *wickColor;
@property (nonatomic, assign) BOOL showWicks;
@property (nonatomic, assign) BOOL fillCandles;

@end

NS_ASSUME_NONNULL_END
