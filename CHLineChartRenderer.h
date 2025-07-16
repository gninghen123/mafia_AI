//
//  CHLineChartRenderer.h
//  ChartWidget
//
//  Renderer for line charts
//

#import "CHChartRenderer.h"

typedef NS_ENUM(NSInteger, CHLineChartStyle) {
    CHLineChartStyleStraight,      // Simple straight lines
    CHLineChartStyleSmooth,        // Bezier curves
    CHLineChartStyleStepped,       // Step/staircase style
    CHLineChartStyleSteppedMiddle  // Steps centered on points
};

typedef NS_ENUM(NSInteger, CHLineChartPointStyle) {
    CHLineChartPointStyleNone,     // No points
    CHLineChartPointStyleCircle,   // Circle points
    CHLineChartPointStyleSquare,   // Square points
    CHLineChartPointStyleDiamond,  // Diamond points
    CHLineChartPointStyleTriangle  // Triangle points
};

@interface CHLineChartRenderer : CHChartRenderer

// Line style
@property (nonatomic) CHLineChartStyle lineStyle;
@property (nonatomic) CHLineChartPointStyle pointStyle;

// Appearance
@property (nonatomic) BOOL fillArea;              // Fill area under line
@property (nonatomic) CGFloat fillOpacity;         // Opacity for filled area
@property (nonatomic) BOOL showDataPoints;         // Show individual data points
@property (nonatomic) BOOL animatePointByPoint;    // Animate drawing point by point

// Shadow
@property (nonatomic) BOOL drawShadow;
@property (nonatomic, strong) NSColor *shadowColor;
@property (nonatomic) CGSize shadowOffset;
@property (nonatomic) CGFloat shadowBlurRadius;

@end
