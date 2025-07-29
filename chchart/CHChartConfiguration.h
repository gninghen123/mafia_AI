//
//  CHChartConfiguration.h
//  ChartWidget
//
//  Configuration object for customizing chart appearance and behavior
//

#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>

typedef NS_ENUM(NSInteger, CHChartType) {
    CHChartTypeLine,
    CHChartTypeBar,
    CHChartTypePie,
    CHChartTypeArea,
    CHChartTypeScatter,
    CHChartTypeCombined
};

typedef NS_ENUM(NSInteger, CHAnimationType) {
    CHAnimationTypeNone,
    CHAnimationTypeFadeIn,
    CHAnimationTypeGrowIn,
    CHAnimationTypeSlideIn,
    CHAnimationTypeBounce
};

typedef NS_OPTIONS(NSUInteger, CHChartGridLines) {
    CHChartGridLinesNone = 0,
    CHChartGridLinesHorizontal = 1 << 0,
    CHChartGridLinesVertical = 1 << 1,
    CHChartGridLinesBoth = CHChartGridLinesHorizontal | CHChartGridLinesVertical
};

@interface CHChartConfiguration : NSObject <NSCopying>

// Chart Type
@property (nonatomic) CHChartType chartType;

// Colors
@property (nonatomic, strong) NSColor *backgroundColor;
@property (nonatomic, strong) NSColor *gridLineColor;
@property (nonatomic, strong) NSColor *axisColor;
@property (nonatomic, strong) NSColor *textColor;
@property (nonatomic, strong) NSArray<NSColor *> *seriesColors;

// Layout
@property (nonatomic) NSEdgeInsets padding;
@property (nonatomic) CGFloat lineWidth;
@property (nonatomic) CGFloat barWidth;
@property (nonatomic) CGFloat barSpacing;
@property (nonatomic) CGFloat pointRadius;

// Grid
@property (nonatomic) CHChartGridLines gridLines;
@property (nonatomic) CGFloat gridLineWidth;
@property (nonatomic) NSArray<NSNumber *> *gridLineDashPattern;

// Axes
@property (nonatomic) BOOL showXAxis;
@property (nonatomic) BOOL showYAxis;
@property (nonatomic) BOOL showXLabels;
@property (nonatomic) BOOL showYLabels;
@property (nonatomic) NSInteger xAxisLabelCount;
@property (nonatomic) NSInteger yAxisLabelCount;

// Legend
@property (nonatomic) BOOL showLegend;
@property (nonatomic) NSRectEdge legendPosition;
@property (nonatomic) CGSize legendSize;

// Animation
@property (nonatomic) BOOL animated;
@property (nonatomic) CHAnimationType animationType;
@property (nonatomic) NSTimeInterval animationDuration;
@property (nonatomic) NSTimeInterval animationDelay;

// Interaction
@property (nonatomic) BOOL interactive;
@property (nonatomic) BOOL showTooltips;
@property (nonatomic) BOOL allowSelection;
@property (nonatomic) BOOL allowZoom;
@property (nonatomic) BOOL allowPan;

// Font
@property (nonatomic, strong) NSFont *labelFont;
@property (nonatomic, strong) NSFont *titleFont;
@property (nonatomic, strong) NSFont *legendFont;

// Convenience methods
+ (instancetype)defaultConfiguration;
+ (instancetype)configurationForChartType:(CHChartType)type;

// Apply theme presets
- (void)applyDarkTheme;
- (void)applyLightTheme;
- (void)applyMinimalTheme;

@end
