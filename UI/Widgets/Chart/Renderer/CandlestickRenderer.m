//
//  CandlestickRenderer.m
//  TradingApp
//

#import "CandlestickRenderer.h"
#import "ChartCoordinator.h"

@implementation CandlestickRenderer

- (instancetype)init {
    self = [super init];
    if (self) {
        _settings = [IndicatorSettings defaultSettingsForIndicatorType:@"Security"];
        [self applySettings:_settings];
        
        // Default visual settings
        _showWicks = YES;
        _fillCandles = YES;
        _wickColor = [NSColor labelColor];
    }
    return self;
}

#pragma mark - IndicatorRenderer Protocol

- (NSString *)indicatorType {
    return @"Security";
}

- (NSString *)displayName {
    return self.settings.displayName;
}

- (IndicatorCategory)category {
    return IndicatorCategorySecurity;
}

- (BOOL)needsSeparatePanel {
    return NO; // Security data goes in main panel
}

- (void)drawInRect:(NSRect)rect
          withData:(NSArray<HistoricalBarModel *> *)data
        coordinator:(ChartCoordinator *)coordinator {
    
    if (!data || data.count == 0) return;
    
    NSRange visibleRange = coordinator.visibleBarsRange;
    if (visibleRange.location >= data.count) return;
    
    NSInteger startIndex = visibleRange.location;
    NSInteger endIndex = MIN(startIndex + visibleRange.length, data.count);
    NSInteger visibleBars = endIndex - startIndex;
    
    if (visibleBars <= 0) return;
    
    // Calculate price range for Y-axis
    NSRange priceRange = [coordinator calculateValueRangeForData:data type:@"Security"];
    
    // Calculate bar dimensions
    CGFloat barWidth = rect.size.width / visibleBars;
    CGFloat candleWidth = MAX(1.0, barWidth * 0.8);
    CGFloat barSpacing = MAX(0.5, (barWidth - candleWidth) / 2);
    
    // Draw each candlestick
    for (NSInteger i = 0; i < visibleBars; i++) {
        NSInteger dataIndex = startIndex + i;
        if (dataIndex >= data.count) break;
        
        HistoricalBarModel *bar = data[dataIndex];
        [self drawCandlestickForBar:bar
                            atIndex:i
                           barWidth:candleWidth
                         barSpacing:barSpacing
                             inRect:rect
                         priceRange:priceRange
                        coordinator:coordinator];
    }
}

- (void)drawCandlestickForBar:(HistoricalBarModel *)bar
                      atIndex:(NSInteger)index
                     barWidth:(CGFloat)barWidth
                   barSpacing:(CGFloat)barSpacing
                       inRect:(NSRect)rect
                   priceRange:(NSRange)priceRange
                  coordinator:(ChartCoordinator *)coordinator {
    
    CGFloat x = index * (barWidth + barSpacing * 2) + barSpacing + barWidth / 2;
    
    // Calculate Y positions
    CGFloat openY = [coordinator yPositionForValue:bar.open inRange:priceRange rect:rect];
    CGFloat highY = [coordinator yPositionForValue:bar.high inRange:priceRange rect:rect];
    CGFloat lowY = [coordinator yPositionForValue:bar.low inRange:priceRange rect:rect];
    CGFloat closeY = [coordinator yPositionForValue:bar.close inRange:priceRange rect:rect];
    
    // Determine if bullish or bearish
    BOOL isUp = bar.close >= bar.open;
    NSColor *bodyColor = isUp ? self.upColor : self.downColor;
    
    // Draw upper and lower wicks
    if (self.showWicks) {
        [self.wickColor setStroke];
        NSBezierPath *wickPath = [NSBezierPath bezierPath];
        wickPath.lineWidth = 1.0;
        
        // Upper wick
        [wickPath moveToPoint:NSMakePoint(x, highY)];
        [wickPath lineToPoint:NSMakePoint(x, MAX(openY, closeY))];
        
        // Lower wick
        [wickPath moveToPoint:NSMakePoint(x, lowY)];
        [wickPath lineToPoint:NSMakePoint(x, MIN(openY, closeY))];
        
        [wickPath stroke];
    }
    
    // Draw candle body
    CGFloat bodyTop = MAX(openY, closeY);
    CGFloat bodyBottom = MIN(openY, closeY);
    CGFloat bodyHeight = bodyTop - bodyBottom;
    
    // Ensure doji candles are visible
    if (bodyHeight < 1.0) {
        bodyHeight = 1.0;
        bodyTop = bodyBottom + bodyHeight;
    }
    
    NSRect candleRect = NSMakeRect(x - barWidth / 2, bodyBottom, barWidth, bodyHeight);
    
    if (self.fillCandles) {
        [bodyColor setFill];
        NSRectFill(candleRect);
    }
    
    // Draw candle border
    [bodyColor setStroke];
    NSBezierPath *borderPath = [NSBezierPath bezierPathWithRect:candleRect];
    borderPath.lineWidth = self.settings.lineWidth;
    [borderPath stroke];
}

#pragma mark - Optional Protocol Methods

- (NSColor *)primaryColor {
    return self.upColor;
}


- (IndicatorSettings *)settings {
    return _settings;
}

- (void)applySettings:(IndicatorSettings *)settings {
    _settings = [settings copy];
    
    // Update visual properties from settings
    _upColor = settings.primaryColor;
    _downColor = settings.secondaryColor;
    
    // Update display name if needed
    if (![settings.displayName isEqualToString:@"Price"]) {
        settings.displayName = @"Price";
    }
}

- (NSDictionary *)serializeState {
    NSMutableDictionary *state = [NSMutableDictionary dictionary];
    state[@"settings"] = [self.settings toDictionary];
    state[@"showWicks"] = @(self.showWicks);
    state[@"fillCandles"] = @(self.fillCandles);
    return [state copy];
}

- (void)restoreState:(NSDictionary *)state {
    if (state[@"settings"]) {
        IndicatorSettings *newSettings = [IndicatorSettings settingsFromDictionary:state[@"settings"]];
        [self applySettings:newSettings];
    }
    
    if (state[@"showWicks"]) {
        self.showWicks = [state[@"showWicks"] boolValue];
    }
    
    if (state[@"fillCandles"]) {
        self.fillCandles = [state[@"fillCandles"] boolValue];
    }
}

- (NSView *)createSettingsView {
    // TODO: Create settings view for editing candle appearance
    // This will be implemented in a later phase
    return nil;
}

@end
