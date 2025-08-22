// PanelYCoordinateContext.m
#import "PanelYCoordinateContext.h"
#import "ChartPanelView.h"

@implementation PanelYCoordinateContext

#pragma mark - Cache Management

- (void)invalidateCache {
    self.cacheValid = NO;
}

- (void)updateCacheIfNeeded {
    if (self.cacheValid) return;
    
    // ✅ Cache dei valori base
    self.cachedLinearRange = self.yRangeMax - self.yRangeMin;
    self.cachedUsableHeight = self.panelHeight - 20.0;
    
    // ✅ Cache dei valori logaritmici (solo se necessari)
    if (self.useLogScale && self.yRangeMin > 0 && self.yRangeMax > 0) {
        self.cachedLogMin = log(self.yRangeMin);
        self.cachedLogMax = log(self.yRangeMax);
        double logRange = self.cachedLogMax - self.cachedLogMin;
        self.cachedLogRangeInv = (logRange > 0) ? (1.0 / logRange) : 0.0;
    } else {
        // Reset dei valori log se non in uso
        self.cachedLogMin = 0.0;
        self.cachedLogMax = 0.0;
        self.cachedLogRangeInv = 0.0;
    }
    
    self.cacheValid = YES;
    
    NSLog(@"📊 PanelYContext: Cache updated - Range:%.3f, Height:%.0f, LogScale:%@",
          self.cachedLinearRange, self.cachedUsableHeight, self.useLogScale ? @"YES" : @"NO");
}

#pragma mark - Optimized Conversion Methods

- (CGFloat)screenYForValue:(double)value {
    if (![self isValidForConversion]) {
        return 0.0;
    }
    
    // ✅ AGGIORNA CACHE SE NECESSARIA
    [self updateCacheIfNeeded];
    
    if (self.cachedLinearRange <= 0.0) {
        return 0.0;
    }
    
    double normalizedValue;
    
    if (self.useLogScale && value > 0 && self.yRangeMin > 0 && self.yRangeMax > 0 && self.cachedLogRangeInv > 0.0) {
        // 🔢 SCALA LOGARITMICA OTTIMIZZATA - usa cache
        double logValue = log(value);
        normalizedValue = (logValue - self.cachedLogMin) * self.cachedLogRangeInv;
    } else {
        // 📏 SCALA LINEARE OTTIMIZZATA - usa cache
        normalizedValue = (value - self.yRangeMin) / self.cachedLinearRange;
    }
    
    // ✅ Clamp normalizedValue
    normalizedValue = fmax(0.0, fmin(1.0, normalizedValue));
    
    // ✅ TUA LOGICA CORRETTA: Y-axis increases upwards
    // The lowest value should be at the bottom (y=10.0), and the highest at the top (y=panelHeight-10.0)
    return 10.0 + (normalizedValue * self.cachedUsableHeight);
}

- (double)valueForScreenY:(CGFloat)screenY {
    if (![self isValidForConversion]) {
        return 0.0;
    }
    
    // ✅ AGGIORNA CACHE SE NECESSARIA
    [self updateCacheIfNeeded];
    
    // ✅ TUA LOGICA CORRETTA: Normalize the screen Y position
    // The lowest point (y=10.0) is 0.0, the highest point is 1.0
    double normalizedY = (screenY - 10.0) / self.cachedUsableHeight;
    normalizedY = fmax(0.0, fmin(1.0, normalizedY));
    
    if (self.useLogScale && self.yRangeMin > 0 && self.yRangeMax > 0 && self.cachedLogRangeInv > 0.0) {
        // 🔢 SCALA LOGARITMICA INVERSA OTTIMIZZATA - usa cache
        double logValue = self.cachedLogMin + (normalizedY / self.cachedLogRangeInv);
        return exp(logValue);
    } else {
        // 📏 SCALA LINEARE INVERSA OTTIMIZZATA - usa cache
        return self.yRangeMin + (normalizedY * self.cachedLinearRange);
    }
}

#pragma mark - Setter Overrides for Cache Invalidation

- (void)setYRangeMin:(double)yRangeMin {
    if (_yRangeMin != yRangeMin) {
        _yRangeMin = yRangeMin;
        [self invalidateCache];
    }
}

- (void)setYRangeMax:(double)yRangeMax {
    if (_yRangeMax != yRangeMax) {
        _yRangeMax = yRangeMax;
        [self invalidateCache];
    }
}

- (void)setPanelHeight:(CGFloat)panelHeight {
    if (_panelHeight != panelHeight) {
        _panelHeight = panelHeight;
        [self invalidateCache];
    }
}

- (void)setUseLogScale:(BOOL)useLogScale {
    if (_useLogScale != useLogScale) {
        _useLogScale = useLogScale;
        [self invalidateCache];
    }
}

#pragma mark - Batch Update Method

- (void)updateRanges:(double)yMin yMax:(double)yMax height:(CGFloat)height {
    // ✅ Batch update senza invalidare cache multipla volta
    _yRangeMin = yMin;
    _yRangeMax = yMax;
    _panelHeight = height;
    [self invalidateCache];
    // Cache sarà aggiornata al prossimo accesso
}

#pragma mark - Performance Metrics (Debug)

- (NSDictionary *)getCacheStats {
    return @{
        @"cacheValid": @(self.cacheValid),
        @"useLogScale": @(self.useLogScale),
        @"linearRange": @(self.cachedLinearRange),
        @"usableHeight": @(self.cachedUsableHeight),
        @"logRangeInv": @(self.cachedLogRangeInv)
    };
}
- (double)valueForNormalizedY:(double)normalizedY {
    if (![self isValidForConversion]) {
        return 0.0;
    }
    
    normalizedY = MAX(0.0, MIN(1.0, normalizedY));
    double range = self.yRangeMax - self.yRangeMin;
    return self.yRangeMin + (normalizedY * range);
}

- (double)normalizedYForValue:(double)value {
    if (![self isValidForConversion]) {
        return 0.0;
    }
    
    double range = self.yRangeMax - self.yRangeMin;
    if (range <= 0.0) return 0.0;
    
    double normalized = (value - self.yRangeMin) / range;
    return MAX(0.0, MIN(1.0, normalized));
}

#pragma mark - Legacy Compatibility Methods

- (CGFloat)screenYForTriggerValue:(double)triggerValue {
    return [self screenYForValue:triggerValue];
}

- (double)triggerValueForScreenY:(CGFloat)screenY {
    return [self valueForScreenY:screenY];
}

- (CGFloat)priceFromScreenY:(CGFloat)screenY {
    return [self valueForScreenY:screenY];
}

- (CGFloat)yCoordinateForPrice:(double)price {
    return [self screenYForValue:price];
}

- (BOOL)isValidForConversion {
    return (self.yRangeMax > self.yRangeMin &&
            self.panelHeight > 20.0);
}

@end
