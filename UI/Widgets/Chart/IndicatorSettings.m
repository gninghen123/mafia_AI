
//
//  IndicatorSettings.m
//  TradingApp
//

#import "IndicatorSettings.h"

@implementation IndicatorSettings

- (instancetype)init {
    self = [super init];
    if (self) {
        [self setDefaults];
    }
    return self;
}

- (void)setDefaults {
    _indicatorType = @"Unknown";
    _displayName = @"Indicator";
    _visualizationType = VisualizationTypeLine;
    
    _primaryColor = [NSColor systemBlueColor];
    _secondaryColor = [NSColor systemRedColor];
    _lineWidth = 1.0;
    _transparency = 1.0;
    
    _period = 14;
    _fastPeriod = 12;
    _slowPeriod = 26;
    _signalPeriod = 9;
    _multiplier = 2.0;
    
    _showLabels = YES;
    _showValues = NO;
    _customLabel = nil;
}

#pragma mark - Factory Methods

+ (instancetype)defaultSettingsForIndicatorType:(NSString *)type {
    IndicatorSettings *settings = [[IndicatorSettings alloc] init];
    settings.indicatorType = type;
    
    if ([type isEqualToString:@"Security"]) {
        settings.displayName = @"Price";
        settings.visualizationType = VisualizationTypeCandlestick;
        settings.primaryColor = [NSColor systemGreenColor];
        settings.secondaryColor = [NSColor systemRedColor];
        settings.lineWidth = 1.0;
        
    } else if ([type isEqualToString:@"Volume"]) {
        settings.displayName = @"Volume";
        settings.visualizationType = VisualizationTypeHistogram;
        settings.primaryColor = [NSColor systemBlueColor];
        settings.lineWidth = 1.0;
        
    } else if ([type isEqualToString:@"RSI"]) {
        settings.displayName = @"RSI(14)";
        settings.visualizationType = VisualizationTypeLine;
        settings.primaryColor = [NSColor systemPurpleColor];
        settings.period = 14;
        settings.lineWidth = 2.0;
        
    } else if ([type isEqualToString:@"SMA"]) {
        settings.displayName = @"SMA(20)";
        settings.visualizationType = VisualizationTypeLine;
        settings.primaryColor = [NSColor systemOrangeColor];
        settings.period = 20;
        settings.lineWidth = 2.0;
        
    } else if ([type isEqualToString:@"MACD"]) {
        settings.displayName = @"MACD(12,26,9)";
        settings.visualizationType = VisualizationTypeLine;
        settings.primaryColor = [NSColor systemBlueColor];
        settings.secondaryColor = [NSColor systemRedColor];
        settings.fastPeriod = 12;
        settings.slowPeriod = 26;
        settings.signalPeriod = 9;
        settings.lineWidth = 1.5;
    }
    
    return settings;
}

+ (instancetype)settingsFromDictionary:(NSDictionary *)dict {
    IndicatorSettings *settings = [[IndicatorSettings alloc] init];
    [settings updateFromDictionary:dict];
    return settings;
}

#pragma mark - Serialization

- (NSDictionary *)toDictionary {
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    
    dict[@"indicatorType"] = self.indicatorType;
    dict[@"displayName"] = self.displayName;
    dict[@"visualizationType"] = @(self.visualizationType);
    
    // Serialize colors as hex strings
    dict[@"primaryColor"] = [self colorToHex:self.primaryColor];
    dict[@"secondaryColor"] = [self colorToHex:self.secondaryColor];
    
    dict[@"lineWidth"] = @(self.lineWidth);
    dict[@"transparency"] = @(self.transparency);
    
    dict[@"period"] = @(self.period);
    dict[@"fastPeriod"] = @(self.fastPeriod);
    dict[@"slowPeriod"] = @(self.slowPeriod);
    dict[@"signalPeriod"] = @(self.signalPeriod);
    dict[@"multiplier"] = @(self.multiplier);
    
    dict[@"showLabels"] = @(self.showLabels);
    dict[@"showValues"] = @(self.showValues);
    if (self.customLabel) {
        dict[@"customLabel"] = self.customLabel;
    }
    
    return [dict copy];
}

- (void)updateFromDictionary:(NSDictionary *)dict {
    if (dict[@"indicatorType"]) self.indicatorType = dict[@"indicatorType"];
    if (dict[@"displayName"]) self.displayName = dict[@"displayName"];
    if (dict[@"visualizationType"]) self.visualizationType = [dict[@"visualizationType"] integerValue];
    
    if (dict[@"primaryColor"]) self.primaryColor = [self colorFromHex:dict[@"primaryColor"]];
    if (dict[@"secondaryColor"]) self.secondaryColor = [self colorFromHex:dict[@"secondaryColor"]];
    
    if (dict[@"lineWidth"]) self.lineWidth = [dict[@"lineWidth"] doubleValue];
    if (dict[@"transparency"]) self.transparency = [dict[@"transparency"] doubleValue];
    
    if (dict[@"period"]) self.period = [dict[@"period"] integerValue];
    if (dict[@"fastPeriod"]) self.fastPeriod = [dict[@"fastPeriod"] integerValue];
    if (dict[@"slowPeriod"]) self.slowPeriod = [dict[@"slowPeriod"] integerValue];
    if (dict[@"signalPeriod"]) self.signalPeriod = [dict[@"signalPeriod"] integerValue];
    if (dict[@"multiplier"]) self.multiplier = [dict[@"multiplier"] doubleValue];
    
    if (dict[@"showLabels"]) self.showLabels = [dict[@"showLabels"] boolValue];
    if (dict[@"showValues"]) self.showValues = [dict[@"showValues"] boolValue];
    if (dict[@"customLabel"]) self.customLabel = dict[@"customLabel"];
}

#pragma mark - NSCopying

- (id)copyWithZone:(NSZone *)zone {
    IndicatorSettings *copy = [[IndicatorSettings alloc] init];
    [copy updateFromDictionary:[self toDictionary]];
    return copy;
}

#pragma mark - Utility Methods

- (NSString *)colorToHex:(NSColor *)color {
    NSColor *rgbColor = [color colorUsingColorSpace:[NSColorSpace sRGBColorSpace]];
    return [NSString stringWithFormat:@"#%02X%02X%02X%02X",
            (int)(rgbColor.redComponent * 255),
            (int)(rgbColor.greenComponent * 255),
            (int)(rgbColor.blueComponent * 255),
            (int)(rgbColor.alphaComponent * 255)];
}

- (NSColor *)colorFromHex:(NSString *)hexString {
    NSString *cleanString = [hexString stringByReplacingOccurrencesOfString:@"#" withString:@""];
    if (cleanString.length == 6) {
        cleanString = [cleanString stringByAppendingString:@"FF"]; // Add alpha
    }
    if (cleanString.length != 8) return [NSColor blackColor];
    
    unsigned int red, green, blue, alpha;
    sscanf([cleanString UTF8String], "%02X%02X%02X%02X", &red, &green, &blue, &alpha);
    
    return [NSColor colorWithRed:red/255.0 green:green/255.0 blue:blue/255.0 alpha:alpha/255.0];
}

@end
