//
//  IndicatorSettings.h
//  TradingApp
//
//  Settings model for indicators
//

#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>
#import "ChartTypes.h"

NS_ASSUME_NONNULL_BEGIN

@interface IndicatorSettings : NSObject <NSCopying>

#pragma mark - Core Properties
@property (nonatomic, strong) NSString *indicatorType;
@property (nonatomic, strong) NSString *displayName;
@property (nonatomic, assign) VisualizationType visualizationType;

#pragma mark - Visual Properties
@property (nonatomic, strong) NSColor *primaryColor;
@property (nonatomic, strong) NSColor *secondaryColor;  // For indicators with multiple lines
@property (nonatomic, assign) CGFloat lineWidth;
@property (nonatomic, assign) CGFloat transparency;

#pragma mark - Calculation Properties
@property (nonatomic, assign) NSInteger period;         // For SMA, RSI, etc.
@property (nonatomic, assign) NSInteger fastPeriod;     // For MACD
@property (nonatomic, assign) NSInteger slowPeriod;     // For MACD
@property (nonatomic, assign) NSInteger signalPeriod;   // For MACD
@property (nonatomic, assign) double multiplier;        // For Bollinger Bands, etc.

#pragma mark - Display Properties
@property (nonatomic, assign) BOOL showLabels;
@property (nonatomic, assign) BOOL showValues;
@property (nonatomic, strong, nullable) NSString *customLabel;

#pragma mark - Factory Methods
+ (instancetype)defaultSettingsForIndicatorType:(NSString *)type;
+ (instancetype)settingsFromDictionary:(NSDictionary *)dict;

#pragma mark - Serialization
- (NSDictionary *)toDictionary;
- (void)updateFromDictionary:(NSDictionary *)dict;

@end

NS_ASSUME_NONNULL_END
