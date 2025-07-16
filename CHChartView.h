//
//  CHChartView.h
//  ChartWidget
//
//  Main view class for displaying charts
//

#import <Cocoa/Cocoa.h>
#import "CHChartDataSource.h"
#import "CHChartDelegate.h"

@class CHChartConfiguration;
@class CHDataPoint;
@class CHChartRenderer;

@interface CHChartView : NSView

// Data and Delegate
@property (nonatomic, weak) id<CHChartDataSource> dataSource;
@property (nonatomic, weak) id<CHChartDelegate> delegate;

// Configuration
@property (nonatomic, strong) CHChartConfiguration *configuration;

// State
@property (nonatomic, readonly) BOOL isAnimating;
@property (nonatomic, readonly) CHDataPoint *selectedDataPoint;
@property (nonatomic, readonly) CHDataPoint *hoveredDataPoint;

// Renderer
@property (nonatomic, strong, readonly) CHChartRenderer *renderer;

// Data Management
- (void)reloadData;
- (void)reloadDataAnimated:(BOOL)animated;
- (void)reloadDataForSeries:(NSInteger)series animated:(BOOL)animated;

// Selection
- (void)selectDataPoint:(CHDataPoint *)dataPoint animated:(BOOL)animated;
- (void)deselectDataPointAnimated:(BOOL)animated;

// Layout
- (void)setNeedsLayout;
- (CGRect)drawingArea; // Area excluding padding
- (CGRect)chartArea;   // Area for actual chart content

// Export
- (NSImage *)chartImage;
- (NSData *)chartImageDataWithType:(NSBitmapImageFileType)fileType;

// Animation
- (void)stopAllAnimations;

@end
