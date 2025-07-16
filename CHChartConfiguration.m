//
//  CHChartConfiguration.m
//  ChartWidget
//
//  Implementation of CHChartConfiguration
//

#import "CHChartConfiguration.h"

@implementation CHChartConfiguration

#pragma mark - Class Methods

+ (instancetype)defaultConfiguration {
    return [[self alloc] init];
}

+ (instancetype)configurationForChartType:(CHChartType)type {
    CHChartConfiguration *config = [[self alloc] init];
    config.chartType = type;
    
    // Apply type-specific defaults
    switch (type) {
        case CHChartTypeLine:
            config.lineWidth = 2.0;
            config.pointRadius = 3.0;
            config.showXAxis = YES;
            config.showYAxis = YES;
            break;
            
        case CHChartTypeBar:
            config.barWidth = 30.0;
            config.barSpacing = 10.0;
            config.showXAxis = YES;
            config.showYAxis = YES;
            break;
            
        case CHChartTypePie:
            config.showXAxis = NO;
            config.showYAxis = NO;
            config.showLegend = YES;
            config.legendPosition = NSMaxXEdge;
            break;
            
        default:
            break;
    }
    
    return config;
}

#pragma mark - Initialization

- (instancetype)init {
    self = [super init];
    if (self) {
        [self setupDefaults];
    }
    return self;
}

- (void)setupDefaults {
    // Chart Type
    _chartType = CHChartTypeLine;
    
    // Colors
    _backgroundColor = [NSColor whiteColor];
    _gridLineColor = [NSColor colorWithWhite:0.9 alpha:1.0];
    _axisColor = [NSColor colorWithWhite:0.3 alpha:1.0];
    _textColor = [NSColor colorWithWhite:0.2 alpha:1.0];
    
    // Default series colors
    _seriesColors = @[
        [NSColor systemBlueColor],
        [NSColor systemRedColor],
        [NSColor systemGreenColor],
        [NSColor systemOrangeColor],
        [NSColor systemPurpleColor],
        [NSColor systemYellowColor],
        [NSColor systemBrownColor],
        [NSColor systemPinkColor]
    ];
    
    // Layout
    _padding = NSEdgeInsetsMake(20, 20, 20, 20);
    _lineWidth = 2.0;
    _barWidth = 30.0;
    _barSpacing = 10.0;
    _pointRadius = 3.0;
    
    // Grid
    _gridLines = CHChartGridLinesBoth;
    _gridLineWidth = 0.5;
    _gridLineDashPattern = nil;
    
    // Axes
    _showXAxis = YES;
    _showYAxis = YES;
    _showXLabels = YES;
    _showYLabels = YES;
    _xAxisLabelCount = 10;
    _yAxisLabelCount = 5;
    
    // Legend
    _showLegend = NO;
    _legendPosition = NSMaxXEdge;
    _legendSize = CGSizeMake(100, 30);
    
    // Animation
    _animated = YES;
    _animationType = CHAnimationTypeFadeIn;
    _animationDuration = 0.3;
    _animationDelay = 0.0;
    
    // Interaction
    _interactive = YES;
    _showTooltips = YES;
    _allowSelection = YES;
    _allowZoom = NO;
    _allowPan = NO;
    
    // Fonts
    _labelFont = [NSFont systemFontOfSize:10];
    _titleFont = [NSFont boldSystemFontOfSize:14];
    _legendFont = [NSFont systemFontOfSize:10];
}

#pragma mark - NSCopying

- (id)copyWithZone:(NSZone *)zone {
    CHChartConfiguration *copy = [[CHChartConfiguration allocWithZone:zone] init];
    if (copy) {
        // Copy all properties
        copy.chartType = self.chartType;
        
        // Colors
        copy.backgroundColor = [self.backgroundColor copy];
        copy.gridLineColor = [self.gridLineColor copy];
        copy.axisColor = [self.axisColor copy];
        copy.textColor = [self.textColor copy];
        copy.seriesColors = [[NSArray alloc] initWithArray:self.seriesColors copyItems:YES];
        
        // Layout
        copy.padding = self.padding;
        copy.lineWidth = self.lineWidth;
        copy.barWidth = self.barWidth;
        copy.barSpacing = self.barSpacing;
        copy.pointRadius = self.pointRadius;
        
        // Grid
        copy.gridLines = self.gridLines;
        copy.gridLineWidth = self.gridLineWidth;
        copy.gridLineDashPattern = [self.gridLineDashPattern copy];
        
        // Axes
        copy.showXAxis = self.showXAxis;
        copy.showYAxis = self.showYAxis;
        copy.showXLabels = self.showXLabels;
        copy.showYLabels = self.showYLabels;
        copy.xAxisLabelCount = self.xAxisLabelCount;
        copy.yAxisLabelCount = self.yAxisLabelCount;
        
        // Legend
        copy.showLegend = self.showLegend;
        copy.legendPosition = self.legendPosition;
        copy.legendSize = self.legendSize;
        
        // Animation
        copy.animated = self.animated;
        copy.animationType = self.animationType;
        copy.animationDuration = self.animationDuration;
        copy.animationDelay = self.animationDelay;
        
        // Interaction
        copy.interactive = self.interactive;
        copy.showTooltips = self.showTooltips;
        copy.allowSelection = self.allowSelection;
        copy.allowZoom = self.allowZoom;
        copy.allowPan = self.allowPan;
        
        // Fonts
        copy.labelFont = [self.labelFont copy];
        copy.titleFont = [self.titleFont copy];
        copy.legendFont = [self.legendFont copy];
    }
    return copy;
}

#pragma mark - Theme Methods

- (void)applyDarkTheme {
    self.backgroundColor = [NSColor colorWithWhite:0.1 alpha:1.0];
    self.gridLineColor = [NSColor colorWithWhite:0.2 alpha:1.0];
    self.axisColor = [NSColor colorWithWhite:0.7 alpha:1.0];
    self.textColor = [NSColor colorWithWhite:0.9 alpha:1.0];
}

- (void)applyLightTheme {
    self.backgroundColor = [NSColor whiteColor];
    self.gridLineColor = [NSColor colorWithWhite:0.9 alpha:1.0];
    self.axisColor = [NSColor colorWithWhite:0.3 alpha:1.0];
    self.textColor = [NSColor colorWithWhite:0.2 alpha:1.0];
}

- (void)applyMinimalTheme {
    self.backgroundColor = [NSColor whiteColor];
    self.gridLines = CHChartGridLinesNone;
    self.showXAxis = NO;
    self.showYAxis = NO;
    self.padding = NSEdgeInsetsMake(40, 40, 40, 40);
}

@end
