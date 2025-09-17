// PanelYCoordinateContext.h
#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

/// Panel-specific Y-axis coordinate context
/// Manages value-to-screen conversions for individual panels (prices, volume, indicators)
@interface PanelYCoordinateContext : NSObject

#pragma mark - Panel Y-axis Context
@property (nonatomic, assign) double yRangeMin;
@property (nonatomic, assign) double yRangeMax;
@property (nonatomic, assign) CGFloat panelHeight;
@property (nonatomic, strong, nullable) NSString *currentSymbol; // For alerts
@property (nonatomic, strong, nullable) NSString *panelType; // "security", "volume", etc.
@property (nonatomic, assign) BOOL useLogScale;  // 🆕 NEW: Scala logaritmica per asse Y
#pragma mark - Performance Cache (CORRETTO)
@property (nonatomic, assign) double cachedLinearRange;     // yRangeMax - yRangeMin (sempre uguale)
@property (nonatomic, assign) double cachedLogRange;       // log(yRangeMax) - log(yRangeMin) (solo per scala log)
@property (nonatomic, assign) CGFloat cachedUsableHeight;  // panelHeight - 20.0 (sempre uguale)
@property (nonatomic, assign) BOOL cacheValid;             // Flag per validità cache


#pragma mark - Y Coordinate Conversion Methods
- (CGFloat)screenYForValue:(double)value;
- (double)valueForScreenY:(CGFloat)screenY;
- (double)valueForNormalizedY:(double)normalizedY;
- (double)normalizedYForValue:(double)value;

#pragma mark - Legacy Compatibility Methods
- (CGFloat)screenYForTriggerValue:(double)triggerValue;
- (double)triggerValueForScreenY:(CGFloat)screenY;
- (CGFloat)priceFromScreenY:(CGFloat)screenY;
- (CGFloat)yCoordinateForPrice:(double)price;

#pragma mark - Validation
- (BOOL)isValidForConversion;

@end

NS_ASSUME_NONNULL_END
