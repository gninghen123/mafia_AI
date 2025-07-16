//
//  CHDataPoint.h
//  ChartWidget
//
//  Model class representing a single data point in a chart
//

#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>

@interface CHDataPoint : NSObject <NSCopying>

// Core properties
@property (nonatomic) CGFloat x;
@property (nonatomic) CGFloat y;
@property (nonatomic) NSInteger seriesIndex;
@property (nonatomic) NSInteger pointIndex;

// Display properties
@property (nonatomic, copy) NSString *label;
@property (nonatomic, copy) NSString *tooltip;
@property (nonatomic, strong) NSColor *color;

// State
@property (nonatomic) BOOL isSelected;
@property (nonatomic) BOOL isHighlighted;

// Convenience initializers
+ (instancetype)dataPointWithX:(CGFloat)x y:(CGFloat)y;
+ (instancetype)dataPointWithX:(CGFloat)x y:(CGFloat)y label:(NSString *)label;

- (instancetype)initWithX:(CGFloat)x y:(CGFloat)y;
- (instancetype)initWithX:(CGFloat)x y:(CGFloat)y label:(NSString *)label;

// Utility methods
- (CGPoint)cgPoint;
- (BOOL)isEqualToDataPoint:(CHDataPoint *)dataPoint;

@end
