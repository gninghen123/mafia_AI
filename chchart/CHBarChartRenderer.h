//
//  CHBarChartRenderer.h
//  ChartWidget
//
//  Renderer for bar charts and histograms
//

#import "CHChartRenderer.h"

typedef NS_ENUM(NSInteger, CHBarChartStyle) {
    CHBarChartStyleSeparated,      // Standard bar chart with gaps
    CHBarChartStyleGrouped,        // Grouped bars for multiple series
    CHBarChartStyleStacked,        // Stacked bars
    CHBarChartStyleHistogram,      // Histogram (no gaps between bars)
    CHBarChartStyleWaterfall       // Waterfall chart
};

typedef NS_ENUM(NSInteger, CHBarChartOrientation) {
    CHBarChartOrientationVertical,   // Bars grow upward
    CHBarChartOrientationHorizontal  // Bars grow rightward
};

typedef NS_ENUM(NSInteger, CHBarCornerStyle) {
    CHBarCornerStyleSquare,         // Square corners
    CHBarCornerStyleRounded,        // Rounded corners
    CHBarCornerStyleRoundedTop      // Only top corners rounded
};

@interface CHBarChartRenderer : CHChartRenderer

// Style
@property (nonatomic) CHBarChartStyle barStyle;
@property (nonatomic) CHBarChartOrientation orientation;
@property (nonatomic) CHBarCornerStyle cornerStyle;
@property (nonatomic) CGFloat cornerRadius;

// Layout
@property (nonatomic) CGFloat barWidthRatio;        // Ratio of bar width to available space (0.0-1.0)
@property (nonatomic) CGFloat groupSpacingRatio;    // Space between groups as ratio of bar width
@property (nonatomic) CGFloat barSpacingRatio;      // Space between bars in a group

// Appearance
@property (nonatomic) BOOL showBarLabels;           // Show value labels on bars
@property (nonatomic) BOOL showBarOutline;          // Draw outline around bars
@property (nonatomic) CGFloat barOutlineWidth;
@property (nonatomic, strong) NSColor *barOutlineColor;

// Gradient
@property (nonatomic) BOOL useGradient;
@property (nonatomic) CGFloat gradientAngle;        // 0 = horizontal, 90 = vertical
@property (nonatomic) CGFloat gradientIntensity;    // 0.0-1.0

// Shadow
@property (nonatomic) BOOL drawBarShadow;
@property (nonatomic, strong) NSColor *barShadowColor;
@property (nonatomic) CGSize barShadowOffset;
@property (nonatomic) CGFloat barShadowBlurRadius;

// Animation
@property (nonatomic) BOOL animateFromBaseline;     // Animate bars growing from baseline
@property (nonatomic) BOOL animateSequentially;     // Animate bars one by one

// Histogram specific
@property (nonatomic) NSInteger binCount;           // Number of bins for histogram
@property (nonatomic) BOOL normalizeHistogram;      // Normalize to show frequency density

@end
